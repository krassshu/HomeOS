import { and, count, eq, sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import type { Candidate, DatabaseEvidence } from "../shared/candidate.ts";
import type {
  AuditDiff,
  DynamicValue,
  ObjectGraphInput,
  ObjectKind,
  ObjectSnapshot,
} from "../shared/domain/model.ts";
import {
  auditEntries,
  fieldDefinitions,
  objectFieldValues,
  objects,
  objectTags,
  tags,
} from "./schema.ts";

interface SearchRow extends Record<string, unknown> {
  id: string;
}

interface NameRow extends Record<string, unknown> {
  name: string;
}

interface NumberRow extends Record<string, unknown> {
  value: number | string;
}

export function createDrizzleCandidate(databaseUrl: string): Candidate {
  const pool = new Pool({ connectionString: databaseUrl });
  const db = drizzle(pool);

  return {
    name: "drizzle",

    async resetData() {
      await db.execute(sql`
        TRUNCATE TABLE
          audit_entries,
          object_tags,
          object_field_values,
          tags,
          field_definitions,
          objects
        RESTART IDENTITY CASCADE
      `);
    },

    async createObjectGraph(
      input: ObjectGraphInput,
      failBeforeCommit = false,
    ) {
      await db.transaction(async (tx) => {
        await tx.insert(objects).values({
          id: input.id,
          kind: input.kind,
          title: input.title,
        });

        for (const field of input.fields) {
          await tx
            .insert(fieldDefinitions)
            .values({
              id: field.definitionId,
              key: field.key,
              valueType: field.valueType,
            })
            .onConflictDoNothing();
          await tx.insert(objectFieldValues).values({
            objectId: input.id,
            definitionId: field.definitionId,
            value: field.value,
          });
        }

        for (const tag of input.tags) {
          await tx.insert(tags).values(tag).onConflictDoNothing();
          await tx.insert(objectTags).values({
            objectId: input.id,
            tagId: tag.id,
          });
        }

        await tx.insert(auditEntries).values({
          objectId: input.id,
          action: "created",
          diff: { after: { title: input.title } },
        });

        if (failBeforeCommit) {
          throw new Error("E2 forced rollback");
        }
      });
    },

    async getObject(id: string): Promise<ObjectSnapshot | null> {
      const [object] = await db
        .select()
        .from(objects)
        .where(eq(objects.id, id))
        .limit(1);
      if (!object) {
        return null;
      }

      const fieldRows = await db
        .select({
          key: fieldDefinitions.key,
          value: objectFieldValues.value,
        })
        .from(objectFieldValues)
        .innerJoin(
          fieldDefinitions,
          eq(objectFieldValues.definitionId, fieldDefinitions.id),
        )
        .where(eq(objectFieldValues.objectId, id));

      const tagRows = await db
        .select({ name: tags.name })
        .from(objectTags)
        .innerJoin(tags, eq(objectTags.tagId, tags.id))
        .where(eq(objectTags.objectId, id));

      return {
        id: object.id,
        kind: object.kind as ObjectKind,
        title: object.title,
        version: object.version,
        fields: Object.fromEntries(
          fieldRows.map((row) => [row.key, row.value as DynamicValue]),
        ),
        tags: tagRows.map((row) => row.name),
      };
    },

    async updateTitleWithAudit(id: string, title: string, diff: AuditDiff) {
      await db.transaction(async (tx) => {
        const updated = await tx
          .update(objects)
          .set({
            title,
            version: sql`${objects.version} + 1`,
            updatedAt: new Date(),
          })
          .where(eq(objects.id, id))
          .returning({ id: objects.id });
        if (updated.length !== 1) {
          throw new Error(`Object not found: ${id}`);
        }
        await tx.insert(auditEntries).values({
          objectId: id,
          action: "title_changed",
          diff,
        });
      });
    },

    async countObjects(id?: string) {
      const query = db.select({ value: count() }).from(objects);
      const [row] = id
        ? await query.where(eq(objects.id, id))
        : await query;
      return row?.value ?? 0;
    },

    async countAuditEntries(id: string) {
      const [row] = await db
        .select({ value: count() })
        .from(auditEntries)
        .where(eq(auditEntries.objectId, id));
      return row?.value ?? 0;
    },

    async refreshSearchVector(id: string) {
      await db.execute(sql`
        UPDATE objects AS o
        SET search_vector = to_tsvector(
          'simple',
          unaccent(
            o.title || ' ' ||
            COALESCE((
              SELECT string_agg(v.value #>> '{}', ' ')
              FROM object_field_values AS v
              WHERE v.object_id = o.id
            ), '')
          )
        )
        WHERE o.id = ${id}
      `);
    },

    async searchExact(query: string) {
      const result = await db.execute<SearchRow>(sql`
        SELECT id
        FROM objects
        WHERE search_vector @@ plainto_tsquery('simple', unaccent(${query}))
        ORDER BY id
      `);
      return result.rows.map((row) => row.id);
    },

    async searchTypo(query: string) {
      const result = await db.execute<SearchRow>(sql`
        SELECT id
        FROM objects
        WHERE similarity(unaccent(title), unaccent(${query})) >= 0.3
        ORDER BY id
      `);
      return result.rows.map((row) => row.id);
    },

    async runMigrationCycle() {
      const beforeCount = await this.countObjects();
      await db.execute(sql.raw(
        "ALTER TABLE objects ADD COLUMN IF NOT EXISTS description text",
      ));
      await db.execute(sql`
        UPDATE objects
        SET description = 'migration-probe'
      `);
      const first = await db.execute<{ description: string }>(
        sql.raw("SELECT description FROM objects ORDER BY id LIMIT 1"),
      );
      await db.execute(
        sql.raw("ALTER TABLE objects DROP COLUMN description"),
      );
      await db.execute(
        sql.raw("ALTER TABLE objects ADD COLUMN description text"),
      );
      const second = await db.execute<{ description: null }>(
        sql.raw("SELECT description FROM objects ORDER BY id LIMIT 1"),
      );
      return {
        beforeCount,
        afterCount: await this.countObjects(),
        valueAfterFirstUp: first.rows[0]?.description ?? "",
        valueAfterSecondUp: second.rows[0]?.description ?? null,
      };
    },

    async updateWithVersion(
      id: string,
      expectedVersion: number,
      title: string,
    ) {
      const updated = await db
        .update(objects)
        .set({
          title,
          version: sql`${objects.version} + 1`,
          updatedAt: new Date(),
        })
        .where(
          and(eq(objects.id, id), eq(objects.version, expectedVersion)),
        )
        .returning({ id: objects.id });
      return updated.length === 1;
    },

    async evidence(): Promise<DatabaseEvidence> {
      const extensions = await db.execute<NameRow>(sql`
        SELECT extname AS name
        FROM pg_extension
        WHERE extname IN ('pg_trgm', 'unaccent')
        ORDER BY extname
      `);
      const indexes = await db.execute<NameRow>(sql`
        SELECT indexname AS name
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND indexname IN (
            'objects_search_vector_gin_idx',
            'objects_title_trgm_idx'
          )
        ORDER BY indexname
      `);
      const migrations = await db.execute<NumberRow>(sql`
        SELECT count(*)::int AS value
        FROM drizzle.__drizzle_migrations
      `);
      const objectCount = await this.countObjects();
      const audit = await db
        .select({ value: count() })
        .from(auditEntries);
      return {
        extensions: extensions.rows.map((row) => row.name),
        indexes: indexes.rows.map((row) => row.name),
        migrationCount: Number(migrations.rows[0]?.value ?? 0),
        objectCount,
        auditCount: audit[0]?.value ?? 0,
      };
    },

    async close() {
      await pool.end();
    },
  };
}
