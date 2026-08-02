import { writeFile } from "node:fs/promises";
import {
  runFreshDatabaseTrials,
  verifyRestoredDatabase,
} from "./assertions.ts";
import type { Candidate } from "./candidate.ts";

function requiredEnvironment(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

async function loadCandidate(name: string): Promise<Candidate> {
  if (name === "drizzle") {
    const { createDrizzleCandidate } = await import(
      "../drizzle/candidate.ts"
    );
    return createDrizzleCandidate(requiredEnvironment("DATABASE_URL"));
  }
  if (name === "prisma") {
    const { createPrismaCandidate } = await import("../prisma/candidate.ts");
    return createPrismaCandidate(requiredEnvironment("DATABASE_URL"));
  }
  throw new Error(`Unsupported candidate: ${name}`);
}

const candidateName = process.argv[2];
const mode = process.env.E2_MODE ?? "fresh";
const candidate = await loadCandidate(candidateName ?? "");

try {
  const trials =
    mode === "restore"
      ? [await verifyRestoredDatabase(candidate)]
      : await runFreshDatabaseTrials(candidate);

  const report = {
    candidate: candidate.name,
    mode,
    node: process.version,
    timestamp: new Date().toISOString(),
    passed: true,
    trials,
  };

  const resultPath = process.env.E2_RESULT_PATH;
  if (resultPath) {
    await writeFile(resultPath, `${JSON.stringify(report, null, 2)}\n`, {
      encoding: "utf8",
    });
  }
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
} finally {
  await candidate.close();
}
