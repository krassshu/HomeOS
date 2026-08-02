export type ObjectKind = "document" | "asset" | "note";

export type DynamicValue = string | number | boolean;

export interface DynamicFieldInput {
  definitionId: string;
  key: string;
  valueType: "text" | "number" | "boolean";
  value: DynamicValue;
}

export interface ObjectGraphInput {
  id: string;
  kind: ObjectKind;
  title: string;
  fields: readonly DynamicFieldInput[];
  tags: readonly {
    id: string;
    name: string;
  }[];
}

export interface ObjectSnapshot {
  id: string;
  kind: ObjectKind;
  title: string;
  version: number;
  fields: Readonly<Record<string, DynamicValue>>;
  tags: readonly string[];
}

export interface AuditDiff {
  before: Readonly<Record<string, unknown>>;
  after: Readonly<Record<string, unknown>>;
}

export function createAuditDiff(
  before: Readonly<Record<string, unknown>>,
  after: Readonly<Record<string, unknown>>,
): AuditDiff {
  return { before, after };
}
