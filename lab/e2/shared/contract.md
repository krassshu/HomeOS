# Wspólny kontrakt E2

Obie implementacje otrzymują ten sam model, fixture i asercje.

## Model

- `objects`: rdzeń obiektu, tytuł i licznik `version`,
- `field_definitions`: definicje pól dynamicznych,
- `object_field_values`: wartości JSONB zachowujące typ domenowy,
- `tags` i `object_tags`: relacja wiele-do-wielu,
- `audit_entries`: operacja i diff JSONB,
- `search_vector`: wektor PostgreSQL indeksowany przez GIN.

Wartości fixture obejmują tekst, liczbę i boolean. Tekst zawiera polskie
znaki. Wyszukiwanie sprawdza dokładną frazę i osobny przypadek literówki.

## Warunki blokujące

| Próba | Asercja |
|---|---|
| E2-01 | Typy i relacje dynamicznych pól są odczytywane bez utraty danych |
| E2-02 | Wymuszony wyjątek wycofuje obiekt i audit |
| E2-03 | Zmiana tytułu i diff audytu zapisują się w jednej transakcji |
| E2-04 | `unaccent`, `pg_trgm`, GIN, wyszukiwanie dokładne i literówka działają |
| E2-05 | Na zapełnionej bazie przechodzi `add → drop → add` bez utraty obiektów |
| E2-06 | Po `pg_dump`/restore przechodzą te same asercje i istnieje historia migracji |
| E2-07 | Aktualizacja ze starą wartością `version` nie zmienia rekordu |

`shared/domain/` nie może importować żadnego ORM-u. Implementacje dostępu do
danych znajdują się wyłącznie w katalogach `drizzle/` i `prisma/`.
