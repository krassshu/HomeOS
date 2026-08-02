import {
  check,
  customType,
  index,
  integer,
  jsonb,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uniqueIndex,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

const tsVector = customType<{ data: string }>({
  dataType() {
    return "tsvector";
  },
});

export const objects = pgTable("objects", {
  id: text("id").primaryKey(),
  kind: text("kind").notNull(),
  title: text("title").notNull(),
  version: integer("version").notNull().default(1),
  searchVector: tsVector("search_vector"),
  createdAt: timestamp("created_at", {
    withTimezone: true,
    mode: "date",
  })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", {
    withTimezone: true,
    mode: "date",
  })
    .notNull()
    .defaultNow(),
}, (table) => [
  index("objects_search_vector_gin_idx").using("gin", table.searchVector),
  index("objects_title_trgm_idx").using(
    "gin",
    table.title.asc().op("gin_trgm_ops"),
  ),
]);

export const fieldDefinitions = pgTable(
  "field_definitions",
  {
    id: text("id").primaryKey(),
    key: text("key").notNull(),
    valueType: text("value_type").notNull(),
  },
  (table) => [
    uniqueIndex("field_definitions_key_idx").on(table.key),
    check(
      "field_definitions_value_type_check",
      sql`${table.valueType} IN ('text', 'number', 'boolean')`,
    ),
  ],
);

export const objectFieldValues = pgTable(
  "object_field_values",
  {
    objectId: text("object_id")
      .notNull()
      .references(() => objects.id, { onDelete: "cascade" }),
    definitionId: text("definition_id")
      .notNull()
      .references(() => fieldDefinitions.id, { onDelete: "restrict" }),
    value: jsonb("value").notNull(),
  },
  (table) => [
    primaryKey({
      name: "object_field_values_pk",
      columns: [table.objectId, table.definitionId],
    }),
  ],
);

export const tags = pgTable(
  "tags",
  {
    id: text("id").primaryKey(),
    name: text("name").notNull(),
  },
  (table) => [uniqueIndex("tags_name_idx").on(table.name)],
);

export const objectTags = pgTable(
  "object_tags",
  {
    objectId: text("object_id")
      .notNull()
      .references(() => objects.id, { onDelete: "cascade" }),
    tagId: text("tag_id")
      .notNull()
      .references(() => tags.id, { onDelete: "cascade" }),
  },
  (table) => [
    primaryKey({
      name: "object_tags_pk",
      columns: [table.objectId, table.tagId],
    }),
  ],
);

export const auditEntries = pgTable("audit_entries", {
  id: integer("id").primaryKey().generatedAlwaysAsIdentity(),
  objectId: text("object_id")
    .notNull()
    .references(() => objects.id, { onDelete: "cascade" }),
  action: text("action").notNull(),
  diff: jsonb("diff").notNull(),
  createdAt: timestamp("created_at", {
    withTimezone: true,
    mode: "date",
  })
    .notNull()
    .defaultNow(),
});
