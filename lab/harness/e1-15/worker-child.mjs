// Worker uruchamiany jako osobny proces, żeby dało się go zabić sygnałem KILL
// w trakcie aktywnego zadania. Nie zamyka połączeń przy zabiciu — to jest sedno
// próby E1-15b-C i E1-15b-D.
import { Worker } from "bullmq";
import pg from "pg";

const {
  VALKEY_HOST,
  VALKEY_PORT = "6379",
  QUEUE_NAME,
  QUEUE_PREFIX,
  HOLD_MS = "60000",
  DATABASE_URL,
  MARK_FILE,
} = process.env;

const connection = {
  host: VALKEY_HOST,
  port: Number(VALKEY_PORT),
  maxRetriesPerRequest: null,
};

const pool = DATABASE_URL ? new pg.Pool({ connectionString: DATABASE_URL, max: 2 }) : null;

const worker = new Worker(
  QUEUE_NAME,
  async (job) => {
    // Ślad wykonania jest trwały: przeżywa zabicie procesu i pozwala policzyć
    // rzeczywistą liczbę dostaw tego samego zadania.
    if (pool) {
      await pool.query(
        "INSERT INTO e1_15_execution (job_id, intent_key, attempt) VALUES ($1, $2, $3)",
        [String(job.id), job.data.intentKey ?? null, job.attemptsMade],
      );
    }
    if (MARK_FILE) {
      const { appendFileSync } = await import("node:fs");
      appendFileSync(MARK_FILE, `${job.id}\n`);
    }
    process.send?.({ type: "started", jobId: job.id });
    await new Promise((resolve) => setTimeout(resolve, Number(HOLD_MS)));
    return { done: true };
  },
  {
    connection,
    prefix: QUEUE_PREFIX,
    concurrency: 1,
    lockDuration: Number(process.env.LOCK_DURATION ?? "10000"),
    stalledInterval: Number(process.env.STALLED_INTERVAL ?? "5000"),
    maxStalledCount: Number(process.env.MAX_STALLED_COUNT ?? "2"),
  },
);

worker.on("ready", () => process.send?.({ type: "ready" }));
worker.on("active", (job) => process.send?.({ type: "active", jobId: job.id }));
