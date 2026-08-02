import type { ObjectGraphInput } from "./domain/model.ts";

export const PRIMARY_OBJECT_ID = "00000000-0000-4000-8000-000000000001";
export const ROLLBACK_OBJECT_ID = "00000000-0000-4000-8000-000000000099";

export const PRIMARY_OBJECT: ObjectGraphInput = {
  id: PRIMARY_OBJECT_ID,
  kind: "document",
  title: "Zielony kalkulator domowych wydatków",
  fields: [
    {
      definitionId: "00000000-0000-4000-8000-000000000101",
      key: "amount",
      valueType: "number",
      value: 126.49,
    },
    {
      definitionId: "00000000-0000-4000-8000-000000000102",
      key: "paid",
      valueType: "boolean",
      value: false,
    },
    {
      definitionId: "00000000-0000-4000-8000-000000000103",
      key: "note",
      valueType: "text",
      value: "żółta ćma odpoczywa obok źródlanej rzeki",
    },
  ],
  tags: [
    {
      id: "00000000-0000-4000-8000-000000000201",
      name: "wydatki",
    },
    {
      id: "00000000-0000-4000-8000-000000000202",
      name: "dom",
    },
  ],
};

export const ROLLBACK_OBJECT: ObjectGraphInput = {
  id: ROLLBACK_OBJECT_ID,
  kind: "note",
  title: "Ten rekord musi zostać wycofany",
  fields: [],
  tags: [],
};

export const EXACT_SEARCH = "zielony kalkulator";
export const TYPO_SEARCH = "zielnoy kalkulator";
