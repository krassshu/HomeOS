import type {
  AuditDiff,
  ObjectGraphInput,
  ObjectSnapshot,
} from "./domain/model.ts";

export interface MigrationCycleResult {
  beforeCount: number;
  afterCount: number;
  valueAfterFirstUp: string;
  valueAfterSecondUp: null;
}

export interface DatabaseEvidence {
  extensions: readonly string[];
  indexes: readonly string[];
  migrationCount: number;
  objectCount: number;
  auditCount: number;
}

export interface Candidate {
  readonly name: "drizzle" | "prisma";
  resetData(): Promise<void>;
  createObjectGraph(
    input: ObjectGraphInput,
    failBeforeCommit?: boolean,
  ): Promise<void>;
  getObject(id: string): Promise<ObjectSnapshot | null>;
  updateTitleWithAudit(
    id: string,
    title: string,
    diff: AuditDiff,
  ): Promise<void>;
  countObjects(id?: string): Promise<number>;
  countAuditEntries(id: string): Promise<number>;
  refreshSearchVector(id: string): Promise<void>;
  searchExact(query: string): Promise<readonly string[]>;
  searchTypo(query: string): Promise<readonly string[]>;
  runMigrationCycle(): Promise<MigrationCycleResult>;
  updateWithVersion(
    id: string,
    expectedVersion: number,
    title: string,
  ): Promise<boolean>;
  evidence(): Promise<DatabaseEvidence>;
  close(): Promise<void>;
}
