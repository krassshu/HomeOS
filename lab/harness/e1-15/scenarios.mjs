// E1-15b — pełny harness scenariuszy BullMQ na Valkey.
//
// Sprawdza dokładnie te własności, na których opiera się projekt Core:
// deduplikację po `jobId`, zachowanie po awarii workera, dostawę co najmniej
// jednokrotną oraz to, że jeden skutek biznesowy zapewnia idempotentny zapis
// i reconciliation, a nie sama kolejka.
//
// Kod jest jednorazowym narzędziem laboratorium. Nie jest kodem produktu.
import { fork } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { Queue, Worker } from "bullmq";
import pg from "pg";

const HERE = path.dirname(fileURLToPath(import.meta.url));

const {
  VALKEY_HOST,
  VALKEY_PORT = "6379",
  DATABASE_URL,
  QUEUE_PREFIX = "homeos-core",
  VARIANT = "shared",
} = process.env;

if (!VALKEY_HOST || !DATABASE_URL) {
  throw new Error("Ustaw VALKEY_HOST i DATABASE_URL.");
}

const connection = {
  host: VALKEY_HOST,
  port: Number(VALKEY_PORT),
  maxRetriesPerRequest: null,
};

const pool = new pg.Pool({ connectionString: DATABASE_URL, max: 4 });
const results = {};
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitFor(predicate, timeoutMs = 30000, stepMs = 200) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await predicate()) return true;
    await sleep(stepMs);
  }
  return false;
}

async function countExecutions(jobId) {
  const { rows } = await pool.query(
    "SELECT count(*)::int AS n FROM e1_15_execution WHERE job_id = $1",
    [jobId],
  );
  return rows[0].n;
}

async function countExecutionsByIntent(intentKey) {
  const { rows } = await pool.query(
    "SELECT count(*)::int AS n FROM e1_15_execution WHERE intent_key = $1",
    [intentKey],
  );
  return rows[0].n;
}

// Tabele laboratoryjne. Fixture E3 (document_link, asset) pozostaje nietknięty.
async function setupSchema() {
  await pool.query(`
    DROP TABLE IF EXISTS e1_15_execution;
    DROP TABLE IF EXISTS e1_15_effect;
    DROP TABLE IF EXISTS e1_15_intent;
    CREATE TABLE e1_15_intent (
      intent_key text PRIMARY KEY,
      status text NOT NULL DEFAULT 'pending',
      created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE e1_15_effect (
      intent_key text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE e1_15_execution (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      job_id text NOT NULL,
      intent_key text,
      attempt int NOT NULL DEFAULT 0,
      executed_at timestamptz NOT NULL DEFAULT now()
    );
  `);
}

async function dropSchema() {
  await pool.query(`
    DROP TABLE IF EXISTS e1_15_execution;
    DROP TABLE IF EXISTS e1_15_effect;
    DROP TABLE IF EXISTS e1_15_intent;
  `);
}

function makeQueue(name) {
  return new Queue(name, { connection, prefix: QUEUE_PREFIX });
}

// Worker w procesie: zapisuje ślad wykonania i opcjonalnie idempotentny skutek.
function makeWorker(name, { holdMs = 200, applyEffect = false } = {}) {
  return new Worker(
    name,
    async (job) => {
      await pool.query(
        "INSERT INTO e1_15_execution (job_id, intent_key, attempt) VALUES ($1, $2, $3)",
        [String(job.id), job.data.intentKey ?? null, job.attemptsMade],
      );
      if (applyEffect && job.data.intentKey) {
        // Jeden skutek biznesowy mimo wielu dostaw.
        await pool.query(
          "INSERT INTO e1_15_effect (intent_key) VALUES ($1) ON CONFLICT DO NOTHING",
          [job.data.intentKey],
        );
        await pool.query(
          "UPDATE e1_15_intent SET status = 'done' WHERE intent_key = $1",
          [job.data.intentKey],
        );
      }
      await sleep(holdMs);
      return { ok: true };
    },
    {
      connection,
      prefix: QUEUE_PREFIX,
      concurrency: 1,
      lockDuration: 10000,
      stalledInterval: 3000,
      maxStalledCount: 3,
    },
  );
}

// --- A: ten sam jobId, gdy poprzedni job nadal istnieje -------------------
async function scenarioSameIdWhileExists() {
  const name = `e1-15-a-${VARIANT}`;
  const queue = makeQueue(name);
  await queue.drain(true);

  const first = await queue.add("intent", { intentKey: "A-1" }, { jobId: "A-1" });
  const second = await queue.add("intent", { intentKey: "A-1" }, { jobId: "A-1" });
  const waiting = await queue.getWaitingCount();

  const worker = makeWorker(name);
  await waitFor(async () => (await queue.getCompletedCount()) >= 1, 20000);
  await worker.close();

  const executions = await countExecutions("A-1");
  results.A_same_job_id_while_exists = {
    opis: "ten sam jobId, gdy pierwszy job nadal istnieje",
    id_pierwszego: first.id,
    id_drugiego: second.id,
    ten_sam_identyfikator: first.id === second.id,
    oczekujących_po_dwóch_add: waiting,
    wykonań: executions,
    // Drugi add nie tworzy nowego joba, więc wykonanie jest dokładnie jedno.
    pass: first.id === second.id && waiting === 1 && executions === 1,
  };
  await queue.obliterate({ force: true });
  await queue.close();
}

// --- B: ten sam jobId po removeOnComplete ---------------------------------
async function scenarioSameIdAfterRemove() {
  const name = `e1-15-b-${VARIANT}`;
  const queue = makeQueue(name);
  await queue.drain(true);

  const worker = makeWorker(name);
  await queue.add("intent", { intentKey: "B-1" }, { jobId: "B-1", removeOnComplete: true });
  await waitFor(async () => (await countExecutions("B-1")) >= 1, 20000);
  await waitFor(async () => (await queue.getJob("B-1")) === undefined, 10000);
  const goneAfterComplete = (await queue.getJob("B-1")) === undefined;

  const reused = await queue.add(
    "intent",
    { intentKey: "B-1" },
    { jobId: "B-1", removeOnComplete: true },
  );
  await waitFor(async () => (await countExecutions("B-1")) >= 2, 20000);
  await worker.close();

  const executions = await countExecutions("B-1");
  results.B_same_job_id_after_remove = {
    opis: "ten sam jobId po removeOnComplete",
    job_usunięty_po_zakończeniu: goneAfterComplete,
    identyfikator_przyjęty_ponownie: reused.id === "B-1",
    wykonań: executions,
    // Po usunięciu joba identyfikator przestaje deduplikować.
    pass: goneAfterComplete && reused.id === "B-1" && executions === 2,
  };
  await queue.obliterate({ force: true });
  await queue.close();
}

// --- C: zabicie workera w trakcie aktywnego zadania ------------------------
async function scenarioWorkerKill() {
  const name = `e1-15-c-${VARIANT}`;
  const queue = makeQueue(name);
  await queue.drain(true);

  await queue.add("intent", { intentKey: "C-1" }, { jobId: "C-1", attempts: 5 });

  const child = fork(path.join(HERE, "worker-child.mjs"), {
    env: {
      ...process.env,
      QUEUE_NAME: name,
      QUEUE_PREFIX,
      HOLD_MS: "60000",
      LOCK_DURATION: "8000",
      STALLED_INTERVAL: "3000",
    },
    stdio: ["ignore", "ignore", "ignore", "ipc"],
  });

  // Czekamy na `started`, a nie na `active`: dopiero ten komunikat oznacza, że
  // procesor zdążył zapisać ślad pierwszej dostawy. Zabicie na `active` ubiłoby
  // workera przed zapisem i pierwsza dostawa nie byłaby policzona.
  const becameActive = await new Promise((resolve) => {
    const timer = setTimeout(() => resolve(false), 30000);
    child.on("message", (msg) => {
      if (msg?.type === "started") {
        clearTimeout(timer);
        resolve(true);
      }
    });
  });

  const executionsBeforeKill = await countExecutions("C-1");
  // Niegrzeczne zabicie: brak szansy na zwolnienie blokady i zamknięcie kolejki.
  child.kill("SIGKILL");
  await new Promise((resolve) => child.on("exit", resolve));

  const worker = makeWorker(name, { holdMs: 200 });
  let stalledSeen = 0;
  worker.on("stalled", () => { stalledSeen += 1; });
  const reprocessed = await waitFor(async () => (await countExecutions("C-1")) >= 2, 90000);
  await worker.close();

  const executions = await countExecutions("C-1");
  results.C_worker_kill_during_active = {
    opis: "restart/kill workera w trakcie aktywnego zadania",
    zadanie_było_aktywne: becameActive,
    wykonań_przed_zabiciem: executionsBeforeKill,
    zadanie_wykonane_ponownie: reprocessed,
    zdarzeń_stalled: stalledSeen,
    wykonań_łącznie: executions,
    pass: becameActive && executions >= 2,
  };
  await queue.obliterate({ force: true });
  await queue.close();
}

// --- D: scenariusz stalled i ponowne wykonanie ----------------------------
async function scenarioStalled() {
  const name = `e1-15-d-${VARIANT}`;
  const queue = makeQueue(name);
  await queue.drain(true);

  await queue.add("intent", { intentKey: "D-1" }, { jobId: "D-1", attempts: 5 });

  const child = fork(path.join(HERE, "worker-child.mjs"), {
    env: {
      ...process.env,
      QUEUE_NAME: name,
      QUEUE_PREFIX,
      HOLD_MS: "60000",
      LOCK_DURATION: "5000",
      STALLED_INTERVAL: "2000",
    },
    stdio: ["ignore", "ignore", "ignore", "ipc"],
  });
  await new Promise((resolve) => {
    const timer = setTimeout(resolve, 30000);
    child.on("message", (msg) => {
      if (msg?.type === "started") { clearTimeout(timer); resolve(); }
    });
  });
  const executionsBeforeKill = await countExecutions("D-1");
  child.kill("SIGKILL");
  await new Promise((resolve) => child.on("exit", resolve));

  // Wykrycie `stalled` wymaga działającego workera — dopiero on sprząta po zmarłym.
  const worker = makeWorker(name, { holdMs: 200 });
  const stalledEvents = [];
  worker.on("stalled", (jobId) => stalledEvents.push(jobId));
  const reprocessed = await waitFor(async () => (await countExecutions("D-1")) >= 2, 90000);
  await worker.close();

  const executions = await countExecutions("D-1");
  results.D_stalled_and_reexecution = {
    opis: "wymuszony scenariusz stalled i ponowne wykonanie",
    wykonań_przed_zabiciem: executionsBeforeKill,
    zdarzeń_stalled: stalledEvents.length,
    wykonań: executions,
    ponownie_wykonane: reprocessed,
    // Dowód dostawy co najmniej jednokrotnej: pierwsza dostawa zapisała ślad,
    // proces zginął bez potwierdzenia, a zadanie zostało dostarczone ponownie.
    pass: reprocessed && executions >= 2 && stalledEvents.length >= 1,
  };
  await queue.obliterate({ force: true });
  await queue.close();
}

// --- E: dostawa co najmniej jednokrotna i idempotentny skutek -------------
async function scenarioIdempotentEffect() {
  const name = `e1-15-e-${VARIANT}`;
  const queue = makeQueue(name);
  await queue.drain(true);
  await pool.query(
    "INSERT INTO e1_15_intent (intent_key) VALUES ($1) ON CONFLICT DO NOTHING",
    ["E-1"],
  );

  const worker = makeWorker(name, { applyEffect: true });
  // Dwie osobne dostawy tej samej intencji: różne jobId, ten sam klucz intencji.
  await queue.add("intent", { intentKey: "E-1" }, { jobId: "E-1-first", removeOnComplete: true });
  await waitFor(async () => (await countExecutionsByIntent("E-1")) >= 1, 20000);
  await queue.add("intent", { intentKey: "E-1" }, { jobId: "E-1-second", removeOnComplete: true });
  await waitFor(async () => (await countExecutionsByIntent("E-1")) >= 2, 20000);
  await worker.close();

  const executions = await countExecutionsByIntent("E-1");
  const { rows } = await pool.query(
    "SELECT count(*)::int AS n FROM e1_15_effect WHERE intent_key = $1",
    ["E-1"],
  );
  results.E_at_least_once_and_idempotent_effect = {
    opis: "dwa wykonania tej samej intencji przy idempotentnym zapisie",
    wykonań: executions,
    skutków_biznesowych: rows[0].n,
    pass: executions >= 2 && rows[0].n === 1,
  };
  await queue.obliterate({ force: true });
  await queue.close();
}

// --- F: usunięcie joba, trwała intencja i reconciliation ------------------
async function scenarioReconciliation() {
  const name = `e1-15-f-${VARIANT}`;
  const queue = makeQueue(name);
  await queue.drain(true);
  await pool.query(
    "INSERT INTO e1_15_intent (intent_key, status) VALUES ($1, 'pending') ON CONFLICT (intent_key) DO UPDATE SET status = 'pending'",
    ["F-1"],
  );

  await queue.add("intent", { intentKey: "F-1" }, { jobId: "F-1" });
  const job = await queue.getJob("F-1");
  await job.remove();
  const jobGone = (await queue.getJob("F-1")) === undefined;

  const { rows: intentRows } = await pool.query(
    "SELECT status FROM e1_15_intent WHERE intent_key = $1",
    ["F-1"],
  );
  const intentSurvived = intentRows.length === 1 && intentRows[0].status === "pending";

  // Reconciliation: trwała intencja bez joba jest odbudowywana.
  const { rows: pending } = await pool.query(
    "SELECT intent_key FROM e1_15_intent WHERE status = 'pending'",
  );
  let rebuilt = 0;
  for (const row of pending) {
    if ((await queue.getJob(row.intent_key)) === undefined) {
      await queue.add("intent", { intentKey: row.intent_key }, { jobId: row.intent_key });
      rebuilt += 1;
    }
  }
  const jobRebuilt = (await queue.getJob("F-1")) !== undefined;

  const worker = makeWorker(name, { applyEffect: true });
  const settled = await waitFor(async () => {
    const { rows } = await pool.query(
      "SELECT status FROM e1_15_intent WHERE intent_key = $1",
      ["F-1"],
    );
    return rows[0]?.status === "done";
  }, 20000);
  await worker.close();

  results.F_job_removal_and_reconciliation = {
    opis: "usunięcie joba przy trwałej intencji, następnie reconciliation",
    job_usunięty: jobGone,
    intencja_przetrwała: intentSurvived,
    odbudowanych_jobów: rebuilt,
    job_odbudowany: jobRebuilt,
    intencja_zamknięta: settled,
    pass: jobGone && intentSurvived && jobRebuilt && settled,
  };
  await queue.obliterate({ force: true });
  await queue.close();
}

async function main() {
  await setupSchema();
  const started = Date.now();
  try {
    await scenarioSameIdWhileExists();
    await scenarioSameIdAfterRemove();
    await scenarioWorkerKill();
    await scenarioStalled();
    await scenarioIdempotentEffect();
    await scenarioReconciliation();
  } finally {
    await dropSchema();
    await pool.end();
  }

  const failed = Object.entries(results).filter(([, v]) => !v.pass).map(([k]) => k);
  const output = {
    wariant: VARIANT,
    prefiks: QUEUE_PREFIX,
    broker: `${VALKEY_HOST}:${VALKEY_PORT}`,
    czas_s: Math.round((Date.now() - started) / 1000),
    scenariusze: results,
    nieudane: failed,
    pass: failed.length === 0,
  };
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
  if (failed.length) process.exitCode = 4;
}

await main();
