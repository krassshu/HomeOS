import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import type { Candidate } from "./candidate.ts";
import {
  EXACT_SEARCH,
  PRIMARY_OBJECT,
  PRIMARY_OBJECT_ID,
  ROLLBACK_OBJECT,
  ROLLBACK_OBJECT_ID,
  TYPO_SEARCH,
} from "./fixture.ts";
import { createAuditDiff } from "./domain/model.ts";

export interface TrialResult {
  id: `E2-${string}`;
  passed: true;
  evidence: Readonly<Record<string, unknown>>;
}

async function assertPersistentInvariants(
  candidate: Candidate,
): Promise<Awaited<ReturnType<Candidate["evidence"]>>> {
  const object = await candidate.getObject(PRIMARY_OBJECT_ID);
  assert.ok(object);
  assert.equal(object.title, "Pierwszy zapis współbieżny");
  assert.equal(object.version, 3);
  assert.deepEqual(object.fields, {
    amount: 126.49,
    note: "żółta ćma odpoczywa obok źródlanej rzeki",
    paid: false,
  });
  assert.deepEqual([...object.tags].sort(), ["dom", "wydatki"]);
  assert.deepEqual(await candidate.searchExact(EXACT_SEARCH), [
    PRIMARY_OBJECT_ID,
  ]);

  const evidence = await candidate.evidence();
  assert.equal(evidence.objectCount, 1);
  assert.equal(evidence.auditCount, 2);
  assert.ok(evidence.migrationCount >= 1);
  assert.ok(evidence.extensions.includes("pg_trgm"));
  assert.ok(evidence.extensions.includes("unaccent"));
  assert.ok(evidence.indexes.includes("objects_search_vector_gin_idx"));
  assert.ok(evidence.indexes.includes("objects_title_trgm_idx"));
  return evidence;
}

async function assertDomainHasNoOrmImports(): Promise<void> {
  const domainRoot = new URL("./domain/", import.meta.url);
  const files = await readdir(domainRoot);
  for (const file of files.filter((entry) => entry.endsWith(".ts"))) {
    const source = await readFile(join(domainRoot.pathname, file), "utf8");
    assert.doesNotMatch(source, /drizzle|prisma|@prisma/i);
  }
}

export async function runFreshDatabaseTrials(
  candidate: Candidate,
): Promise<readonly TrialResult[]> {
  const results: TrialResult[] = [];
  await candidate.resetData();
  await assertDomainHasNoOrmImports();

  await candidate.createObjectGraph(PRIMARY_OBJECT);
  const initial = await candidate.getObject(PRIMARY_OBJECT_ID);
  assert.ok(initial);
  assert.equal(initial.kind, "document");
  assert.deepEqual(initial.fields, {
    amount: 126.49,
    note: "żółta ćma odpoczywa obok źródlanej rzeki",
    paid: false,
  });
  assert.deepEqual([...initial.tags].sort(), ["dom", "wydatki"]);
  results.push({
    id: "E2-01",
    passed: true,
    evidence: {
      fieldTypes: ["text", "number", "boolean"],
      fieldCount: Object.keys(initial.fields).length,
    },
  });

  await assert.rejects(
    candidate.createObjectGraph(ROLLBACK_OBJECT, true),
    /E2 forced rollback/,
  );
  assert.equal(await candidate.countObjects(ROLLBACK_OBJECT_ID), 0);
  assert.equal(await candidate.countAuditEntries(ROLLBACK_OBJECT_ID), 0);
  results.push({
    id: "E2-02",
    passed: true,
    evidence: { atomicRollback: true },
  });

  const changedTitle = "Zielony kalkulator wydatków domowych";
  const diff = createAuditDiff(
    { title: initial.title },
    { title: changedTitle },
  );
  await candidate.updateTitleWithAudit(PRIMARY_OBJECT_ID, changedTitle, diff);
  const changed = await candidate.getObject(PRIMARY_OBJECT_ID);
  assert.ok(changed);
  assert.equal(changed.title, changedTitle);
  assert.equal(await candidate.countAuditEntries(PRIMARY_OBJECT_ID), 2);
  results.push({
    id: "E2-03",
    passed: true,
    evidence: { auditDiff: diff, auditCount: 2 },
  });

  await candidate.refreshSearchVector(PRIMARY_OBJECT_ID);
  assert.deepEqual(await candidate.searchExact(EXACT_SEARCH), [
    PRIMARY_OBJECT_ID,
  ]);
  assert.deepEqual(await candidate.searchTypo(TYPO_SEARCH), [
    PRIMARY_OBJECT_ID,
  ]);
  const ftsEvidence = await candidate.evidence();
  assert.ok(ftsEvidence.extensions.includes("pg_trgm"));
  assert.ok(ftsEvidence.extensions.includes("unaccent"));
  assert.ok(ftsEvidence.indexes.includes("objects_search_vector_gin_idx"));
  assert.ok(ftsEvidence.indexes.includes("objects_title_trgm_idx"));
  results.push({
    id: "E2-04",
    passed: true,
    evidence: {
      exactSearch: true,
      typoSearch: true,
      indexes: ftsEvidence.indexes,
      extensions: ftsEvidence.extensions,
    },
  });

  const migration = await candidate.runMigrationCycle();
  assert.equal(migration.beforeCount, migration.afterCount);
  assert.equal(migration.valueAfterFirstUp, "migration-probe");
  assert.equal(migration.valueAfterSecondUp, null);
  results.push({
    id: "E2-05",
    passed: true,
    evidence: { ...migration },
  });

  const expectedVersion = changed.version;
  assert.equal(
    await candidate.updateWithVersion(
      PRIMARY_OBJECT_ID,
      expectedVersion,
      "Pierwszy zapis współbieżny",
    ),
    true,
  );
  assert.equal(
    await candidate.updateWithVersion(
      PRIMARY_OBJECT_ID,
      expectedVersion,
      "Spóźniony zapis współbieżny",
    ),
    false,
  );
  results.push({
    id: "E2-07",
    passed: true,
    evidence: { staleWriteRejected: true, expectedVersion },
  });

  await assertPersistentInvariants(candidate);
  return results;
}

export async function verifyRestoredDatabase(
  candidate: Candidate,
): Promise<TrialResult> {
  await assertDomainHasNoOrmImports();
  const evidence = await assertPersistentInvariants(candidate);

  return {
    id: "E2-06",
    passed: true,
    evidence: {
      schemaAndDataRestored: true,
      assertionsRepeated: true,
      migrationCount: evidence.migrationCount,
      objectCount: evidence.objectCount,
      auditCount: evidence.auditCount,
    },
  };
}
