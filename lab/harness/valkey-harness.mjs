import { Queue, Worker } from "bullmq";

const host = process.env.VALKEY_HOST;
const port = Number(process.env.VALKEY_PORT ?? "6379");
const count = Number(process.env.JOB_COUNT ?? "1000");

if (!host || !Number.isInteger(port) || !Number.isInteger(count) || count < 1) {
  throw new Error("Set VALKEY_HOST, optional VALKEY_PORT, and positive JOB_COUNT.");
}

const connection = { host, port, maxRetriesPerRequest: null };
const queueName = `homeos-lab-${Date.now()}`;
const queue = new Queue(queueName, { connection, prefix: "homeos-lab" });
let completed = 0;

const worker = new Worker(
  queueName,
  async (job) => {
    if (job.data.failOnce && job.attemptsMade === 0) {
      throw new Error("intentional-first-attempt-failure");
    }
    completed += 1;
  },
  {
    connection,
    prefix: "homeos-lab",
    concurrency: 8,
  },
);

try {
  const jobs = Array.from({ length: count }, (_, index) => ({
    name: "measurement",
    data: { index, failOnce: index % 10 === 0 },
    opts: {
      attempts: 2,
      backoff: { type: "fixed", delay: 50 },
      jobId: `measurement-${index}`,
      removeOnComplete: false,
      removeOnFail: false,
    },
  }));

  await queue.addBulk(jobs);

  const deadline = Date.now() + 120_000;
  while (completed < count && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 250));
  }

  const counts = await queue.getJobCounts();
  const result = {
    queueName,
    requested: count,
    completedByWorker: completed,
    counts,
    success: completed === count && counts.failed === 0,
  };

  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (!result.success) process.exitCode = 1;
} finally {
  await worker.close();
  await queue.close();
}

