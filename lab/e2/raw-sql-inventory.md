# Inwentarz raw SQL i obejść

**Status:** `accepted — potwierdzony przez E2 na VM 2026-07-30`

Nie liczymy każdego polecenia w wersjonowanym pliku migracji jako osobnego
obejścia. Liczymy miejsce, w którym kandydat wymaga jawnego mechanizmu SQL
poza podstawowym API modelu lub zapytań.

| Obszar | Drizzle | Prisma | Powód |
|---|---|---|---|
| Rozszerzenia PostgreSQL | custom SQL w migracji | custom SQL w migracji | `pg_trgm` i `unaccent` |
| `tsvector` i indeksy GIN/trigram | deklaracja schematu Drizzle | custom SQL w migracji oraz `Unsupported("tsvector")` | funkcje właściwe dla PostgreSQL |
| Aktualizacja `search_vector` | raw SQL | raw SQL | agregacja wartości JSONB i `unaccent` |
| Zapytanie FTS | raw SQL | raw SQL | operator `@@` |
| Zapytanie tolerujące literówkę | raw SQL | raw SQL | funkcja `similarity` |
| Próba `up → down → up` | raw DDL przez połączenie Drizzle | raw DDL przez Prisma Client | identyczna odwracalna zmiana testowa |
| Optimistic concurrency | API Drizzle | `updateMany` Prisma | brak obejścia |

Po uruchomieniu należy ocenić nie tylko liczbę miejsc, lecz również:

- bezpieczeństwo parametrów,
- czytelność wygenerowanego SQL,
- diagnostykę błędów,
- zgodność deklaracji ORM ze schematem po migracji i restore.
