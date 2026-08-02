import { PrismaPg } from "@prisma/adapter-pg";
import type { Candidate, DatabaseEvidence } from "../shared/candidate.ts";
import type {
  AuditDiff,
  DynamicValue,
  ObjectGraphInput,
  ObjectKind,
  ObjectSnapshot,
} from "../shared/domain/model.ts";
import { PrismaClient } from "../node_modules/.generated/prisma/client.ts";
import type { Prisma } from "../node_modules/.generated/prisma/client.ts";

interface SearchRow {
  id: string;
}

interface NameRow {
  name: string;
}

interface NumberRow {
  value: number;
}

export function createPrismaCandidate(databaseUrl: string): Candidate {
  const adapter = new PrismaPg({ connectionString: databaseUrl });
  const prisma = new PrismaClient({ adapter });

  return {
    name: "prisma",

    async resetData() {
      await prisma.$executeRawUnsafe(`
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
      await prisma.$transaction(async (tx) => {
        await tx.homeObject.create({
          data: {
            id: input.id,
            kind: input.kind,
            title: input.title,
          },
        });

        for (const field of input.fields) {
          await tx.fieldDefinition.upsert({
            where: { id: field.definitionId },
            create: {
              id: field.definitionId,
              key: field.key,
              valueType: field.valueType,
            },
            update: {},
          });
          await tx.objectFieldValue.create({
            data: {
              objectId: input.id,
              definitionId: field.definitionId,
              value: field.value as Prisma.InputJsonValue,
            },
          });
        }

        for (const tag of input.tags) {
          await tx.tag.upsert({
            where: { id: tag.id },
            create: tag,
            update: {},
          });
          await tx.objectTag.create({
            data: {
              objectId: input.id,
              tagId: tag.id,
            },
          });
        }

        await tx.auditEntry.create({
          data: {
            objectId: input.id,
            action: "created",
            diff: {
              after: { title: input.title },
            },
          },
        });

        if (failBeforeCommit) {
          throw new Error("E2 forced rollback");
        }
      });
    },

    async getObject(id: string): Promise<ObjectSnapshot | null> {
      const object = await prisma.homeObject.findUnique({
        where: { id },
        include: {
          fieldValues: {
            include: { definition: true },
          },
          objectTags: {
            include: { tag: true },
          },
        },
      });
      if (!object) {
        return null;
      }
      return {
        id: object.id,
        kind: object.kind as ObjectKind,
        title: object.title,
        version: object.version,
        fields: Object.fromEntries(
          object.fieldValues.map((row) => [
            row.definition.key,
            row.value as DynamicValue,
          ]),
        ),
        tags: object.objectTags.map((row) => row.tag.name),
      };
    },

    async updateTitleWithAudit(id: string, title: string, diff: AuditDiff) {
      await prisma.$transaction(async (tx) => {
        await tx.homeObject.update({
          where: { id },
          data: {
            title,
            version: { increment: 1 },
            updatedAt: new Date(),
          },
        });
        await tx.auditEntry.create({
          data: {
            objectId: id,
            action: "title_changed",
            diff: diff as unknown as Prisma.InputJsonValue,
          },
        });
      });
    },

    async countObjects(id?: string) {
      return id
        ? prisma.homeObject.count({ where: { id } })
        : prisma.homeObject.count();
    },

    async countAuditEntries(id: string) {
      return prisma.auditEntry.count({
        where: { objectId: id },
      });
    },

    async refreshSearchVector(id: string) {
      await prisma.$executeRaw`
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
      `;
    },

    async searchExact(query: string) {
      const rows = await prisma.$queryRaw<SearchRow[]>`
        SELECT id
        FROM objects
        WHERE search_vector @@ plainto_tsquery('simple', unaccent(${query}))
        ORDER BY id
      `;
      return rows.map((row) => row.id);
    },

    async searchTypo(query: string) {
      const rows = await prisma.$queryRaw<SearchRow[]>`
        SELECT id
        FROM objects
        WHERE similarity(unaccent(title), unaccent(${query})) >= 0.3
        ORDER BY id
      `;
      return rows.map((row) => row.id);
    },

    async runMigrationCycle() {
      const beforeCount = await this.countObjects();
      await prisma.$executeRawUnsafe(
        "ALTER TABLE objects ADD COLUMN IF NOT EXISTS description text",
      );
      await prisma.$executeRawUnsafe(
        "UPDATE objects SET description = 'migration-probe'",
      );
      const first = await prisma.$queryRawUnsafe<Array<{ description: string }>>(
        "SELECT description FROM objects ORDER BY id LIMIT 1",
      );
      await prisma.$executeRawUnsafe(
        "ALTER TABLE objects DROP COLUMN description",
      );
      await prisma.$executeRawUnsafe(
        "ALTER TABLE objects ADD COLUMN description text",
      );
      const second = await prisma.$queryRawUnsafe<Array<{ description: null }>>(
        "SELECT description FROM objects ORDER BY id LIMIT 1",
      );
      return {
        beforeCount,
        afterCount: await this.countObjects(),
        valueAfterFirstUp: first[0]?.description ?? "",
        valueAfterSecondUp: second[0]?.description ?? null,
      };
    },

    async updateWithVersion(
      id: string,
      expectedVersion: number,
      title: string,
    ) {
      const result = await prisma.homeObject.updateMany({
        where: { id, version: expectedVersion },
        data: {
          title,
          version: { increment: 1 },
          updatedAt: new Date(),
        },
      });
      return result.count === 1;
    },

    async evidence(): Promise<DatabaseEvidence> {
      const extensions = await prisma.$queryRaw<NameRow[]>`
        SELECT extname AS name
        FROM pg_extension
        WHERE extname IN ('pg_trgm', 'unaccent')
        ORDER BY extname
      `;
      const indexes = await prisma.$queryRaw<NameRow[]>`
        SELECT indexname AS name
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND indexname IN (
            'objects_search_vector_gin_idx',
            'objects_title_trgm_idx'
          )
        ORDER BY indexname
      `;
      const migrations = await prisma.$queryRaw<NumberRow[]>`
        SELECT count(*)::int AS value
        FROM _prisma_migrations
        WHERE finished_at IS NOT NULL
      `;
      return {
        extensions: extensions.map((row) => row.name),
        indexes: indexes.map((row) => row.name),
        migrationCount: migrations[0]?.value ?? 0,
        objectCount: await prisma.homeObject.count(),
        auditCount: await prisma.auditEntry.count(),
      };
    },

    async close() {
      await prisma.$disconnect();
    },
  };
}
