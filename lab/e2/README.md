# E2 — porównanie Drizzle i Prisma

Izolowany PoC rozstrzygający ADR-014. Nie łączy się z Paperless i nie jest
zalążkiem kodu produktu.

## Środowisko

- Node.js: `24.18.0`, npm `11.16.0`
- obraz: `node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d`
- PostgreSQL: `18.4` z działającej usługi `core_fixture_db`
- Drizzle ORM: `0.45.2`, Drizzle Kit: `0.31.10`
- Prisma CLI i Client: `7.9.1`

PostgreSQL jest wspólnym serwerem, ale dane są rozdzielone na cztery bazy:

- `homeos_e2_drizzle`,
- `homeos_e2_drizzle_restore`,
- `homeos_e2_prisma`,
- `homeos_e2_prisma_restore`.

Fixture `core_fixture` i bazy Paperless nie są modyfikowane.

## Uruchomienie

Wymagane są działające usługi `source/shared` oraz prywatny
`lab/.env.source` z hasłem `CORE_FIXTURE_DB_PASSWORD`.

```sh
cd /srv/homeos/lab/e2
./e2-lab.sh prepare
./e2-lab.sh config
./e2-lab.sh run
```

`run` wykonuje kolejno:

1. kontrolę typów obu implementacji,
2. odtworzenie pustych baz E2,
3. migracje kandydata,
4. E2-01…E2-05 i E2-07 na bazie z danymi,
5. `pg_dump` i restore do osobnej bazy,
6. ponowienie wspólnych asercji jako E2-06.

Polecenie usuwa i tworzy ponownie wyłącznie bazy o nazwach
`homeos_e2_*`. Nie zatrzymuje ani nie restartuje Paperless.

Ostatni skrót można wyświetlić ponownie:

```sh
./e2-lab.sh results
```

Pełne raporty JSON i dumpy są zapisywane w ignorowanym przez Git
`lab-data/e2/`. Po wykonaniu trzeba przenieść zanonimizowane wyniki do
`Docs/operations/spike-results/06-orm-decision-report.md`.
Zależności npm znajdują się w nazwanym wolumenie
`homeos-m3-e2-node-modules`, a nie w katalogu projektu.

`npm audit --omit=dev` nie zgłasza podatności zależności uruchamianych przez
PoC. Pełny audit zgłasza umiarkowane ostrzeżenie w historycznym łańcuchu
`drizzle-kit → @esbuild-kit → esbuild`. Laboratorium nie uruchamia serwera
deweloperskiego esbuild, którego dotyczy ostrzeżenie, a Drizzle Kit służy
wyłącznie do jawnie przypiętych migracji. Ostrzeżenie trzeba uwzględnić w
ocenie utrzymania narzędzia; nie wolno stosować sugerowanego przez npm
downgrade'u z pominięciem PoC.

## Granice wyniku

Automat sprawdza warunki blokujące. Punktacja jakości migracji, obejść i
diagnostyki wymaga przeglądu zapisanych wyników. ADR-014 można zmienić na
`accepted` dopiero po przejściu obu kandydatów albo jednoznacznym odpadnięciu
jednego z nich.
