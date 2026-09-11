# HomeIntelCore

Repozytorium dokumentacji, laboratorium i kodu domowego segregatora.
HomeOS to dawna nazwa robocza; identyfikatory laboratorium M3
(`homeos-m3-source`, `/srv/homeos`, katalog `lab/`) i nazwa repozytorium GitHub
pozostają historyczne. Nazwa techniczna to `homeintelcore`.

## Stan

- M0–M2 są zamknięte dokumentacyjnie.
- M3 pozostaje otwarty: Gate OS-1 czeka na rzeczywiste skany, ADR-015 na test
  docelowego storage 4 TB. Laboratorium Paperless w `lab/` jest osobnym,
  historycznym środowiskiem, niepołączonym z Core.
- M4 (`Docs/10-Conceptual-Data-Model.md`) jest nadal `draft`.
- M9 Engineering Foundation: pierwszy wycinek zweryfikowany (2026-09-11) —
  Core API NestJS, lokalny PostgreSQL 18, Prisma bez modeli, health, testy,
  Dockerfile, CI, izolowany Compose homelab. M9 nie jest zamknięty, M10 nie
  jest rozpoczęte. Kodu domenowego nie ma.

Zacznij od [`Docs/README.md`](Docs/README.md). Stan bram: [`Docs/operations/spike-results/10-decisions-and-gates.md`](Docs/operations/spike-results/10-decisions-and-gates.md).

## Wymagania

- Node.js 24 (`.node-version` = 24.18.0), pnpm dokładnie 11.18.0
  (`packageManager`; inna wersja jest odrzucana). Rejestr: tylko npmjs.
- Docker Desktop — wymagany do lokalnej bazy, testów integracyjnych,
  `check:secrets` i `docker:build`.
- Nie używaj `npm install`, Yarn, globalnego Nest CLI ani globalnej Prismy.
  Prisma jest zależnością `apps/api`, więc jej wersja jest przypięta lockfile.
- PostgreSQL działa w Dockerze, nie z Homebrew: przypięty obraz z digestem,
  ta sama wersja co w CI i homelab, dane w nazwanym wolumenie, brak śladów w
  systemie po `db:down`.

```sh
node --version    # v24.x
pnpm --version    # 11.18.0 (brew upgrade pnpm albo corepack install --global pnpm@11.18.0)
docker --version
```

## Ścieżka świeżego developera

```sh
pnpm install --frozen-lockfile   # 1. zależności dokładnie z lockfile
pnpm dev:setup                   # 2. tworzy .env z losowym hasłem (tryb 600, nie nadpisuje, nie wypisuje)
pnpm db:config                   # 3. walidacja Compose
pnpm db:up && pnpm db:ps         # 4. PostgreSQL 18 na 127.0.0.1:55432, czeka na healthcheck
pnpm db:sql                      # 5. SELECT version() i uuid_extract_version(uuidv7()) = 7
pnpm prisma:validate             # 6. schemat bez modeli, działa bez bazy
pnpm prisma:generate             #    klient do src/infrastructure/persistence/generated (ignorowany)
pnpm dev                         # 7. nest start --watch z .env (albo: pnpm build && pnpm start)
```

Sekret jest tylko w `.env` (ignorowany przez Git); śledzony jest `.env.example`
z placeholderami. Zmienne: `HOMEINTELCORE_DB_USER/NAME/PORT/PASSWORD`,
`DATABASE_URL`, `HOST`, `PORT`, `LOG_LEVEL`, `READINESS_TIMEOUT_MS`,
`SHUTDOWN_TIMEOUT_MS`. Dane bazy leżą w wolumenie
`homeintelcore-local-core-db-data`, projekt Compose `homeintelcore-local`
(`infra/dev/compose.yaml`, [`infra/dev/README.md`](infra/dev/README.md)).

### Health

```sh
curl -i http://127.0.0.1:3000/api/v1/health/live
curl -i http://127.0.0.1:3000/api/v1/health/ready
```

- `live` → `200 {"service":"homeintelcore-api","status":"ok"}` — proces żyje,
  bazy nie dotyka.
- `ready` → `200 {"service":"homeintelcore-api","status":"ok","checks":{"database":"up"}}`
  — `SELECT 1` z limitem `READINESS_TIMEOUT_MS`.
- Baza zatrzymana (`pnpm db:stop`, curl `ready`, potem `pnpm db:up`) →
  `503 {"service":"homeintelcore-api","status":"unavailable","checks":{"database":"down"},"correlationId":"..."}`
  bez URL, hasła, hosta i stack trace.

Każda odpowiedź zwraca `x-correlation-id` (przyjęty z żądania, jeśli bezpieczny,
inaczej wygenerowany UUID). API startuje tylko z poprawną konfiguracją:
brak `DATABASE_URL`, zły schemat lub placeholder → exit 1 bez nasłuchu.
SIGTERM/SIGINT → łagodne zamknięcie (limit `SHUTDOWN_TIMEOUT_MS`), exit 0.

### Testy i kontrole

```sh
pnpm test                # 63 jednostkowe + 12 integracyjnych
pnpm test:unit           # config, correlation, logger, readiness, controller, filtr błędów
pnpm test:integration    # Testcontainers: prawdziwy PostgreSQL 18, e2e HTTP i shutdown procesu dist/main.js
pnpm check               # prisma:generate, docs:check, check:deps, check:tracked, lint, typecheck, test, build, format:check
pnpm check:secrets       # gitleaks v8.30.1 w Dockerze: historia Git + drzewo robocze
pnpm sbom:generate       # wbudowane pnpm sbom (CycloneDX) → sbom/homeintelcore.cdx.json (ignorowany)
pnpm docker:build        # obraz homeintelcore-api:dev z apps/api/Dockerfile
```

Testy integracyjne uruchamiają własny kontener PostgreSQL (Ryuk go sprząta) i
nie dotykają bazy z `db:up`. Testcontainers i gitleaks to narzędzia
developerskie, nie komponenty produktu. `sbom:generate` ma sufiks, bo
`pnpm sbom` bez sufiksu to komenda wbudowana pnpm.

### Zatrzymanie i reset

```sh
pnpm db:stop                                  # zatrzymuje kontener, dane zostają
pnpm db:down                                  # usuwa kontener, wolumen zostaje
pnpm db:reset --confirm homeintelcore-local   # USUWA WOLUMEN — nieodwracalne
```

`db:reset` sprawdza etykietę wolumenu przed usunięciem. Nie używaj
`docker compose down -v` ani `docker volume prune`.

### Wdrożenie testowe homelab

Procedura i granice: [`infra/homelab/README.md`](infra/homelab/README.md).
Stack `homeintelcore-dev` (baza bez portu hosta + API z obrazu budowanego na
VM) jest publikowany wyłącznie na `127.0.0.1:3100` serwera i dostępny z Maca
przez tunel SSH. To izolowany test M9, nie produkcja: brak Caddy, WireGuard,
systemd, autostartu i firewalla; nie dotyka laboratorium M3 na tej samej VM.

## Struktura `apps/api/src`

- `config/` — typowana walidacja env przed startem; komunikaty nie cytują wartości.
- `common/logging` — pino JSON (service, environment, time UTC, correlationId), redakcja hasła w URL.
- `common/correlation` — nagłówek `x-correlation-id` w AsyncLocalStorage.
- `common/http` — filtr wyjątków: nieznany błąd → anonimowe 500, szczegóły tylko w logu.
- `common/ports` — port `DATABASE_PROBE`.
- `health/` — liveness i readiness (przez port, nie przez Prismę).
- `infrastructure/persistence/` — `PrismaService` z adapterem `pg`, leniwe połączenie, `$disconnect` przy zamknięciu.
- `main.ts` — walidacja konfiguracji, prefix `api/v1`, sygnały i łagodne zamknięcie.

Zasada: Prisma jest importowana wyłącznie w `infrastructure/persistence`.
`apps/api/prisma/schema.prisma` zawiera tylko generator i datasource — zero
modeli. Katalog `prisma/migrations` nie istnieje; migracje domenowe powstaną
po domknięciu M4. To świadoma granica, nie brak.

## Polityka zależności i CI

- Wersje dokładne (`check:deps`), jeden `pnpm-lock.yaml`, `allowBuilds` tylko
  dla Prismy, `overrides` dla podatnych zależności przechodnich
  (`pnpm-workspace.yaml`). `check:compose` sprawdza, że oba pliki Compose mają
  obrazy z digestem i porty tylko na `127.0.0.1`.
- `pnpm audit --prod --audit-level=high` przechodzi. Ignorowany
  `GHSA-ggr8-5vv4-36mx` (deepmerge-ts w Prisma CLI): CLI to devDependency,
  ale trafia do `node_modules/.pnpm` obrazu jako peer `@prisma/client`; nie jest
  linkowane do `apps/api/node_modules` ani ładowane przez API. Ryzyko przyjęte
  do czasu usunięcia CLI z obrazu; poprawka pakietu wymaga wersji major.
- SBOM CycloneDX generuje wbudowane `pnpm sbom` (pnpm 11.18.0 z
  `packageManager`, bez dodatkowych narzędzi); w CI jako artefakt z retencją
  30 dni, lokalnie na żądanie; nie jest commitowany.
- Dockerfile: wieloetapowy, `node:24.18.0-bookworm-slim` z digestem,
  `USER node`, runtime bez pnpm i CLI, HEALTHCHECK na `/health/live`, `exec`
  CMD (SIGTERM trafia do node), `.dockerignore` jako allowlist. Znany
  kompromis: `pnpm install --prod` kopiuje do `node_modules/.pnpm` także
  nieużywany pakiet `prisma` CLI (peer w lockfile), więc obraz jest większy.
- CI (`.github/workflows/ci.yml`): push na `main` i PR, `contents: read`,
  akcje przypięte pełnym SHA; kroki: install, prisma validate/generate,
  check:deps, check:tracked, check:secrets, docs:check, lint, typecheck,
  format:check, build, test:unit, test:integration, audit, docker:build
  (bez publikacji), sbom:generate + artefakt. Workflow jest zdefiniowany; pierwsze
  uruchomienie nastąpi po pierwszym pushu.

## Czego tu nie ma

- modeli, tabel i migracji domenowych (M4 `draft`),
- logowania, sesji, ról, CRUD, frontendu (M10 nierozpoczęte),
- integracji z Paperless — laboratorium M3 nie jest połączone z Core,
- WireGuard (planowany, ADR-020), Caddy, Valkey, workera,
- publikacji obrazu do registry, branch/release policy poza notą w 07,
- pełnego katalogu health z 04 §21.

## Dodawanie zależności

```sh
pnpm --filter @homeintelcore/api add nazwa-pakietu
pnpm --filter @homeintelcore/api add --save-dev nazwa-narzędzia
pnpm add --workspace-root --save-dev nazwa-narzędzia   # narzędzie wspólne dla repo
```

Każda zmiana zależności musi zachować `pnpm-lock.yaml` i przejść `pnpm check`.
`node_modules`, buildy, coverage, `.env`, `sbom/`, wygenerowany klient Prisma,
dane laboratorium, sekrety i pliki IDE są ignorowane i nie mogą trafić do Git
(`check:tracked` to sprawdza).

Walidacja dokumentacji: `pnpm docs:check`.
