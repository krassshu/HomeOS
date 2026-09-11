# Changelog dokumentacji

Format: `[data] — zakres — opis`

---

## [2026-09-11] — porządki po pierwszym wycinku M9: konfiguracja pnpm

### Zmienione

- Ustawienia pnpm przeniesione z `.npmrc` (którego pnpm 11 nie czyta poza
  rejestrem) do `pnpm-workspace.yaml`: `autoInstallPeers: false`,
  `strictPeerDependencies: true`, `saveExact`, `engineStrict`,
  `verifyStoreIntegrity`. Lockfile zapisuje teraz `autoInstallPeers: false`;
  automatycznie doinstalowane `react`/`react-dom` (peery Prisma Studio)
  zniknęły z grafu i z obrazu runtime (792 MB → 781 MB).
- `peerDependencyRules.ignoreMissing` dla `react`/`react-dom`: jedyne
  brakujące peery pochodzą z Prisma Studio w `prisma` CLI, którego API nie
  używa.

### Doprecyzowane

- Prisma CLI nadal trafia do `node_modules/.pnpm` obrazu jako peer
  `@prisma/client` (bez pliku wykonywalnego i bez linku); oficjalne mechanizmy
  pnpm tego nie zmieniają, więc optymalizacja nie jest uznana za wykonaną.
- Pierwszy wycinek M9 pozostaje zweryfikowany, M9 jako milestone otwarte,
  M10 nierozpoczęte, M4 nadal `draft`.

---

## [2026-09-11] — M9 Engineering Foundation: pierwszy wycinek zweryfikowany

### Dodane

- Lokalny Core PostgreSQL 18 w Dockerze: `infra/dev/compose.yaml` (projekt
  `homeintelcore-local`, port tylko `127.0.0.1:55432`, nazwany wolumen,
  healthcheck), `.env.example` oraz `pnpm dev:setup` tworzący ignorowany `.env`
  z losowym hasłem. Skrypty `db:config/up/ps/logs/sql/stop/down` i jawnie
  potwierdzany, nieodwracalny `db:reset`.
- Prisma 7.9.1 z oficjalnym adapterem `pg` jako zależność `apps/api`:
  `schema.prisma` tylko z generatorem i datasource (zero modeli),
  `prisma.config.ts` działający bez bazy, `PrismaService` z leniwym
  połączeniem i `$disconnect` przy zamknięciu. Prisma importowana wyłącznie w
  `infrastructure/persistence`.
- Core API: typowana walidacja konfiguracji przed startem, logowanie pino JSON
  z redakcją hasła w URL, `x-correlation-id`, filtr wyjątków bez wycieku
  szczegółów, `GET /api/v1/health/ready` (200/503 przez port
  `DATABASE_PROBE`, bez URL, hasła i stack trace), łagodne zamknięcie na
  SIGTERM/SIGINT.
- Testy: 63 jednostkowe i 12 integracyjnych (Testcontainers z prawdziwym
  PostgreSQL 18: readiness, correlation id, uuidv7, shutdown procesu
  `dist/main.js`). `pnpm test` uruchamia oba zestawy.
- `apps/api/Dockerfile` (wieloetapowy, `node:24.18.0-bookworm-slim` z
  digestem, `USER node`, HEALTHCHECK, `exec` CMD), `.dockerignore` jako
  allowlist, `pnpm docker:build` bez publikacji obrazu.
- Polityka zależności: `check:deps` (wersje dokładne), `check:tracked`,
  `check:secrets` (gitleaks w Dockerze), `check:compose` (digesty i porty
  loopback w Compose), `overrides` i `auditConfig` w
  `pnpm-workspace.yaml`, `pnpm sbom:generate` (wbudowane `pnpm sbom`,
  CycloneDX; wynik nie jest commitowany).
- Workflow CI `.github/workflows/ci.yml`: akcje przypięte SHA, pełny łańcuch
  kontroli, testy integracyjne na Dockerze runnera, SBOM jako artefakt z
  retencją 30 dni. Workflow jest zdefiniowany; pierwsze uruchomienie nastąpi
  po pierwszym pushu.
- `infra/homelab`: izolowany Compose `homeintelcore-dev` do testu M9 na VM
  (API tylko `127.0.0.1:3100`, baza bez portu hosta, osobna sieć i wolumen,
  hardening kontenera API), z procedurą w `infra/homelab/README.md`.
- Rejestr rozbieżności: **R-21** — `infra/` zamiast `deploy/` z 03 §23.
- Glossary: hasło **HomeIntelCore** / **HomeOS** (nazwa historyczna).

### Zmienione

- Nazwa produktu: **HomeIntelCore**, nazwa techniczna `homeintelcore` (root
  package, `@homeintelcore/api`, `service: "homeintelcore-api"`). HomeOS
  pozostaje w identyfikatorach laboratorium M3, nazwie repozytorium GitHub i
  wpisach historycznych.
- Główny `README.md` przepisany jako pełna ścieżka świeżego developera
  (każde polecenie istnieje w root `package.json`) z sekcją „Czego tu nie ma”.
- `Docs/README.md` §6: zastąpiono zdanie o braku kodu produkcyjnego opisem
  stanu M9 — fundament inżynieryjny powstał świadomie przed zamknięciem bram
  M3/M4 zgodnie z 07 §14, kod domenowy (M10) nadal czeka na M4–M8.
- Runbook M9: nota „Rozszerzenie zakresu 2026-09-11” (CI, Dockerfile, Compose
  homelab, commit i push) bez zmiany pozostałej treści i statusu.
- Korekta liczby ADR w `Docs/README.md`: indeks obejmuje 20 ADR-ów
  (`ADR-001` … `ADR-020`) — 16 × `accepted`, 3 × `proposed`,
  1 × `deprecated` — zgodnie z `adr/09-Architecture-Decisions-Index.md`.
  Korekta niezależna od M9.

### Doprecyzowane

- M4 (`10-Conceptual-Data-Model.md`) pozostaje `draft`; nie ma tabel, modeli
  ani migracji domenowych (`prisma/migrations` nie istnieje).
- M9 nie jest zamknięty: brakuje branch/release policy poza notą, migracji
  domenowych i pełnego katalogu health z 04 §21. Ten wycinek nie oznacza
  gotowego produktu.
- M3 pozostaje osobnym laboratorium (Gate OS-1 i ADR-015 nadal otwarte);
  Paperless nie jest połączony z Core.
- WireGuard (ADR-020) jest planowany, nie skonfigurowany. M10 nie jest
  rozpoczęte: brak logowania, sesji, ról, CRUD i frontendu.
- Testcontainers i gitleaks to narzędzia developerskie, nie komponenty
  produktu. Wdrożenie homelab jest testem izolowanym, nie produkcją.

---

## [2026-09-09] — runbook PostgreSQL i Prisma dla CC

### Dodane

- Kompletny plan wykonawczy pierwszego wycinka M9 dla koordynatora Fable i
  agentów Fable/Opus 5: lokalny PostgreSQL 18, Prisma 7.9.1, konfiguracja,
  readiness, test z prawdziwą bazą, dokumentacja i niezależny review.
- Jawny podział własności plików i zakaz równoległych zmian lockfile podczas
  pracy wielu agentów.
- Kryteria akceptacji, reguły ochrony sekretów i danych Dockera, warunki
  eskalacji oraz format końcowego raportu opartego na wykonanych testach.

### Doprecyzowane

- Ten techniczny wycinek nie tworzy tabel ani migracji domenowych i nie zamyka
  M4 ani całego M9. Model pojęciowy M4 nadal pozostaje szkicem.

---

## [2026-08-02] — rozpoczęcie M9: Engineering Foundation

### Dodane

- Minimalny monorepo scaffold oparty na pnpm workspaces bez Turborepo i Nx.
- Pierwszy workspace `apps/api` z NestJS, ESM, TypeScript strict i endpointem
  `GET /api/v1/health/live` związanym wyłącznie z `127.0.0.1` domyślnie.
- Wspólną konfigurację ESLint flat config, Prettier, EditorConfig i TypeScript.
- Test jednostkowy health, skrypty lint/typecheck/test/build/format oraz jedno
  polecenie `pnpm check` obejmujące również walidację dokumentacji.
- Przypięto Node.js 24 LTS w `.node-version`, pnpm 11.18.0 w `packageManager`,
  dokładne wersje zależności i jeden `pnpm-lock.yaml`.

### Poprawione

- Usunięto błędną regułę `.gitignore` ignorującą wszystkie pliki Markdown.
  Dodano ignorowanie plików IDE, buildów, coverage, cache oraz lokalnych
  artefaktów Node bez wykluczania dokumentacji projektu.

### Zweryfikowane

- `pnpm check`: dokumentacja, lint, TypeScript, test, build i format przeszły.
- Zbudowane API uruchomiono lokalnie; liveness zwrócił
  `{"service":"homeos-api","status":"ok"}`. Proces testowy zatrzymano.

---

## [2026-08-01] — rozpoczęcie M4: model pojęciowy HomeOS

### Dodane

- `10-Conceptual-Data-Model.md` jako szkic roboczy M4 z jawną informacją, że
  M3 pozostaje formalnie otwarte przez odłożone testy rzeczywistych skanów i
  docelowego storage.
- Rejestr pierwszych rozstrzygnięć: aktor `create object`, jedna instalacja i
  jeden Workspace, bootstrap konta i osoby, nieblokujący onboarding z wymaganym
  korzeniem gospodarstwa, rozdzielenie gospodarstwa od fizycznych miejsc, wspólny
  lifecycle obiektów oraz potrójna ochrona trwałego usuwania.
- Checklistę analizy `create object`; punkty 1–3 oznaczono jako zamknięte, a
  następnie zamknięto punkt 4: granicę transakcji zwykłego tworzenia obiektu.
- Zamknięto punkt 6 analizy `create object`: rozdzielono właściwości rdzenia,
  dynamiczne pola, relacje, dokumenty, assety i tagi oraz ograniczono JSONB do
  wersjonowanych danych technicznych, pochodzenia i ładunków integracji.
- Zamknięto punkt 7: utrwalono invariants atomowości, idempotencji, własności,
  duplikatów i jednej instalacji na Workspace oraz domyślną widoczność
  `workspace` z możliwością utworzenia obiektu `private`.
- `ADR-020-self-hosted-wireguard-access.md`: LAN pozostaje pierwszym etapem,
  ale samodzielny WireGuard jest jedynym kontraktem dostępu zdalnego. MVP
  dostarcza ręczny klient/provisioning, a późniejsza aplikacja mobilna osadzi
  ten sam tunel bez Tailscale, control plane i relaya.
- Zamknięto punkt 8 analizy `create object`. Trwały audit zapisuje aktora,
  urządzenie, klienta, transport i strukturę operacji; dokładne zwykłe wartości
  należą do historii obiektu, wartości wrażliwe są redagowane, a permanent
  delete usuwa treść historii.
- Bazowy katalog 16 zdarzeń audytowych uzupełniono o 3 obowiązkowe zdarzenia
  bezpieczeństwa: ujawnienie wartości wrażliwej oraz nadanie i odebranie do
  niej dostępu.
- Rozdzielono źródła prawdy `Account`, `Membership` i `Person Object`.
  Blokada konta nie usuwa osoby; usunięcie dostępu domyślnie ją zachowuje, a
  pełne usunięcie konta, osoby i danych wymaga osobnego manifestu oraz potrójnej
  bramy. Audit pełnego usunięcia zachowuje identyfikator i pseudonim.
- Utrwalono model `Role`, `Permission` i `Membership`: pięć ról MVP,
  pierwszeństwo `deny`, oddzielne lifecycle zaproszenia i członkostwa, wielu
  ownerów z zakazem usunięcia ostatniego oraz brak automatycznego dostępu
  administratora do danych prywatnych i wrażliwych.
- Stan onboardingu nie jest przechowywaną flagą. Core wylicza
  `uninitialized`, `household_required` albo `completed` z istnienia singletonu
  Workspace i `Household Object`; dodano invariants współbieżności,
  rollbacku i idempotencji.
- Rozdzielono stabilny `Household Object`, będący korzeniem HomeOS, od
  fizycznych `Place Object`. Gospodarstwo może mieć wiele aktualnych miejsc
  zamieszkania z dokładnie jednym głównym oraz niezależne relacje własności,
  wynajmu, najmu, użytkowania sezonowego i zarządzania.
- Ustalono fizyczną reprezentację autoryzacji: systemowe `Role` i
  `Permission`, pakiety `RolePermission`, wyjątki członkostwa oraz oddzielne
  granty obiektów i wrażliwych wartości. Model nie używa JSONB ani
  polimorficznego identyfikatora zasobu; wszystkie zmiany są audytowane.
- Rozstrzygnięto G3-01: MVP używa nieprzezroczystych sesji server-side z
  hashem tokenu i stanem w PostgreSQL. Web korzysta z bezpiecznego cookie i
  ochrony CSRF, klient natywny z Keychain/Keystore, a Valkey pozostaje
  opcjonalnym cache. JWT i refresh tokeny odrzucono.
- Przyjęto UUIDv7 generowany przez PostgreSQL 18 jako standard identyfikatorów
  trwałych encji Core. Klucze katalogowe, zewnętrzne ID Paperless, tokeny,
  klucze idempotencji i czyste tabele łącznikowe mają jawnie rozdzielone role.
- Zdefiniowano minimalny singleton `Workspace`: techniczny rekord bez nazwy,
  ownera i statusu onboardingu, z `household_object_id`, domyślną strefą i
  locale, wersją oraz bazowym ograniczeniem `UNIQUE + CHECK` chroniącym przed
  drugim Workspace.
- Zdefiniowano minimalny `Account`: wyłącznie znormalizowany e-mail logowania,
  hash Argon2id, stan bezpieczeństwa i timestamps. Dane osoby i role pozostają
  poza kontem, a stan `deleted` zachowuje tylko bezosobowy tombstone bez
  e-maila i credentialu.
- Zdefiniowano `PersonProfile` jako opcjonalne rozszerzenie 1:1 obiektu osoby
  ze strukturalnym imieniem i nazwiskiem. Pozostałe dane są chronionymi
  `FieldValue`, a adresy historycznymi relacjami do współdzielonych
  `Place Object`, bez kopiowania tekstu adresu.

### Doprecyzowane

- Ograniczony domownik nie ma domyślnie `object.create`; uprawnienie nadaje
  administrator Workspace.
- Wariant firmowy wymaga niezależnej instalacji i pozostaje poza HomeOS MVP.
- Jedna instalacja i baza mają dokładnie jeden Workspace. Usunięto pojęcie
  „bieżącego Workspace” oraz filtrację tenantów z autoryzacji; `workspace_id`
  pozostaje wyłącznie relacją strukturalną nadawaną przez serwer.
- Archiwizacja zachowuje dane historyczne. Usuwanie dokumentów współdzielonych
  nie może być automatycznym skutkiem usunięcia obiektu.
- Zwykłe `create object` tworzy atomowo `Object`, `AuditEvent` oraz opcjonalne
  wartości i tagi. Relacje i upload dokumentów pozostają osobnymi operacjami;
  ich niepowodzenie nie usuwa poprawnie utworzonego obiektu.
- `08-MVP-Scope.md` podniesiono do wersji 1.3. S-04 odrzuca ten sam silny
  identyfikator i zatrzymuje identyczną nazwę bez wiarygodnego rozróżnienia;
  różne egzemplarze o tej samej nazwie nadal są dozwolone.
- S-06 otrzymało lokalne, deterministyczne sugestie kategorii, typu, szablonu
  i wartości, zawsze zatwierdzane przez użytkownika. AI pozostaje poza MVP,
  kategoria nie narzuca pól, a tag nie powiela automatycznie kategorii.
- S-05 określa pola dynamiczne jako opcjonalne. Kontrolki relacji i pliku
  zapisują wyspecjalizowane encje, zamiast ukrywać powiązania w `FieldValue`.
- `sensitive` przeniesiono z globalnej definicji na konkretny `FieldValue`.
  Wrażliwa wartość ma osobne granty, jest maskowana i nie daje automatycznego
  dostępu administratorowi ani osobie pozostającej w relacji rodzinnej.
- `ADR-011` oznaczono jako `deprecated`; jego opcjonalność zastępuje ADR-020.
  Opcjonalna pozostaje aktywacja zdalnego dostępu w konkretnej instalacji, nie
  technologia ani publiczna alternatywa.
- Zachowano furtkę dla wariantu hostowanego po publicznym wydaniu. Nie jest to
  fallback obecnej instalacji: wymaga nowego ADR, threat modelu, modelu tenantów
  i ponownej decyzji o izolacji wszystkich klas danych.

## [2026-07-31] — domknięcie technicznej części M3: E1-13/14/15, E3A, E3B i OS-3-LAB

### Rozstrzygnięte

- **Topologia Valkey (uzupełnienie ADR-008): dwie osobne instancje.** Sześć
  scenariuszy BullMQ dało identyczny wynik przy wspólnym i osobnym brokerze,
  a różnica pamięci to ~6 MiB. Decyduje granica bounded context, izolacja
  awarii przy `maxmemory` i możliwość niezależnego restartu, nie zużycie RAM.
- **ADR-016 przeniesiony do `accepted`.** Gate OS-3-LAB przeszedł: inwentarz
  14 komponentów z wersją, digestem, architekturą i licencją jest kompletny,
  NOTICE Apache Tika zachowany, brak licencji nieakceptowalnej dla prywatnego
  laboratorium. OS-3-RELEASE pozostaje bramą M22.
- **E3A i E3B wykonane do końca dla Restic i Borg**, każdorazowo na czystym
  projekcie restore. Audyt otworzył E3A-01 z powodu braku wymuszonego punktu
  spójności, więc **E3A powtórzono w całości dla obu kandydatów** — oba PASS,
  `46/46` kontroli OK.
- **Gate OS-2-LAB zamknięty w zakresie laboratoryjnym.** Punkt spójności jest
  udowodniony: źródłowy `webserver` w stanie `exited` przez całe okno eksportu,
  eksporter w jednorazowym kontenerze Compose bez publikowanych portów, `0`
  pozostawionych kontenerów, dokumenty `9 → 9`, okno `40 s`, źródło z powrotem
  `healthy`. Storage nadal symulowany, więc gate potwierdza poprawność procedur,
  nie gotowość produkcyjną.

### Wynik negatywny

- **E1-13 — FAIL.** Odtworzenie `webserver` w trakcie OCR gubi dokument:
  zadanie zostaje w stanie `started` bez końca, plik znika ze scratch i consume,
  rekord dokumentu nie powstaje. Powtórzone dwukrotnie. Nie ma duplikatu ani
  utraty istniejących dokumentów. Wynik przekłada się na wymagania M4/M6:
  własny timeout zadania, tymczasowy staging do potwierdzenia i reconciliation
  po stronie Core. Wynik pozostaje FAIL testu odporności, ale zgodnie z definicją
  z 08 §G1-02 nie jest krytycznym ograniczeniem Paperless; Gate OS-1 pozostaje
  otwarty z powodu braku potwierdzenia OCR na rzeczywistych skanach. Limity i
  retencję kwarantanny rozstrzygnie osobny ADR G4-06 przed M12.

### Dodane

- `spike-results/07-e1-15-valkey-topology.md`, `08-e3-backup-report.md`,
  `09-os3-lab-inventory.md`, `10-decisions-and-gates.md`,
  `11-reproduction-config.md`, `12-user-checklist.md`.
- Skrypty domykające artefakt trwały nr 4: `lab/harness/preflight.sh`,
  `lab/harness/e1/{ocr-restart-test,valkey-memory-test,gen-ocr-fixture}`,
  `lab/harness/e1-15/`, `lab/harness/e3/`.
- Fixture Core: `9` powiązań `document_link` i `3` assety z checksumami oraz
  manifest źródłowy z własną sumą kontrolną.

### Zmienione

- Audyt raportu końcowego skorygował statusy bram: E1-13 pozostaje FAIL testu,
  ale nie jest krytycznym ograniczeniem według 08 §G1-02; Gate OS-1 czeka na
  rzeczywisty OCR. Gate OS-2-LAB otwarto ponownie, ponieważ pierwszy E3A nie
  wymuszał zatrzymania przyjmowania zapisów z E3A-01; harness poprawiono,
  przebieg powtórzono i gate zamknięto na podstawie nowego wyniku.
- Poprawiono wywołanie eksportera w `e3a.sh`. Obraz Paperless 3.0.4 startuje
  przez s6-overlay, więc przekazanie `document_exporter` jako CMD do
  `docker compose run` uruchamiało cały stack usług — z workerem Celery i
  consumerem — zamiast eksportera, czyli drugiego pisarza na danych źródła.
  Harness woła teraz polecenie administracyjne wprost
  (`--entrypoint /command/s6-setuidgid` → `manage.py document_exporter
  --skip-checks`) i weryfikuje stan zatrzymania źródła oraz brak pozostawionego
  kontenera. Późniejsza korekta zaostrzyła asercję do dokładnego stanu `exited`
  i ograniczyła wyszukiwanie kontenerów jednorazowych do projektu source.
  Powrót do `docker exec` na działającym webserverze pozostaje
  odrzucony, bo łamie E3A-01.
- Doprecyzowano granicę ADR-006: staging uploadu jest tymczasową kwarantanną,
  nie drugim trwałym właścicielem binariów. Parametry zachowania przy długiej
  awarii pozostają decyzją G4-06 przed M12.
- Doprecyzowano bezpieczeństwo E3B: zredagowana konfiguracja nie zawiera
  jawnych sekretów, ale dump bazy jest wrażliwy, a pakiet sekretów aplikacyjnych
  i test jego odzyskania należą do bramy M17.
- Zaostrzono reconciliation external ID/checksum, zabezpieczono rekurencyjne
  czyszczenie katalogów E3 do potomków `E3_ROOT` i poprawiono kontrolę portów
  preflight tak, aby nie używała nieobsługiwanego wyrażenia regularnego.
- ADR-015 pozostaje `proposed`. Oba kandydaty przeszły E3A i E3B w całości, więc
  warunek wejścia do punktacji jest spełniony.
  Rekomendacja wstępna to **Restic** (1 krok manualny wobec 3 w Borgu), ale
  kryterium dopasowania do docelowego storage 4 TB nie zostało ocenione, bo
  storage był symulowany na dysku hosta.
- `05-compatibility-matrix.md` uzupełniona o negocjację `Accept` endpointów
  binarnych, restart w trakcie OCR, limit pamięci brokera, kolejkę BullMQ,
  exporter obejmujący kosz oraz pełny tor disaster recovery.
- Harness E1: `/download/`, `/preview/` i `/thumb/` sprawdzają wariant docelowy
  i sprawdzony fallback; generator fixture odmawia nadpisania w obu warstwach;
  walidator wyników rozpoznaje świadomie zachowany dowód stanu nieterminalnego.

## [2026-07-30] — zakończenie E2 i wybór ORM

### Rozstrzygnięte

- Drizzle i Prisma wykonano na VM w identycznym zakresie E2-01…E2-07;
  oba przeszły transakcje, audit, FTS, migracje, optimistic concurrency oraz
  `pg_dump`/restore.
- Drizzle uzyskał 87,5%, a Prisma 81,0% w punktacji technicznej. Ponieważ
  oba rozwiązania zaliczyły wszystkie bramy, ADR-014 przyjęto z wyborem
  Prisma od M9 na podstawie jawnego LTS i priorytetu wieloletniego wsparcia.
- Zapisano ostrzeżenie OpenSSL Prisma w obrazie slim oraz deweloperskie
  ostrzeżenie `esbuild` w Drizzle Kit; żadne nie wpłynęło na wynik prób.

## [2026-07-28] — konfiguracja laboratorium M3 dla Paperless-ngx 3.0.4

### Dodane

- Osobne warianty Compose dla środowiska źródłowego E1 i czystego celu restore E3.
- Wariant wspólnego Valkey dla Paperless/BullMQ oraz wariant z osobnym `core_broker`.
- Bezpieczny przykładowy env celu restore i skrypt obsługi walidacji, uruchomienia, zatrzymania, resetu, exporter/importer, sanity checkera oraz przygotowania restore.

### Zmienione

- Baseline i override laboratorium przebudowano na strukturę oficjalnego Compose Paperless-ngx `v3.0.4`.
- Paperless, PostgreSQL 18, Valkey 9-alpine, Gotenberg 8.34 i Tika 3.3.1.0 przypięto jednocześnie tagami i digestami.
- Porty hosta ograniczono do `127.0.0.1`, a dane source/restore rozdzielono jednoznacznymi nazwami wolumenów i katalogów.
- Cztery kombinacje source/restore × shared/split przeszły statyczną walidację Compose; eksperymentów ani usług nie uruchamiano.
- Walidacja lokalnego env rozpoznaje placeholdery wyłącznie w wartościach zmiennych i nie traktuje komentarza instruktażowego jako błędu.
- Po pierwszym starcie 3.0.4 usunięto wymuszenie `PAPERLESS_SEARCH_LANGUAGE=pl`: upstream przedwcześnie importuje moduł wyszukiwania i zatrzymuje migracje błędem `AppRegistryNotReady`. Polski OCR pozostaje `pol`, a wyszukiwanie jest ponownie oceniane w E1.

## [2026-07-28] — korekta procedur M3 po audycie

### Poprawione

- Rozdzielono E3 na **E3A przenośność exporter/importer** i **E3B disaster recovery z dumpów baz oraz plików**; oba tory są wymagane dla Gate OS-2-LAB.
- Odchudzono start M3: jedna stała VM wystarcza dla E1/E2, a tymczasowy czysty cel, Restic/Borg i dwie kopie klucza blokują dopiero E3.
- Baseline wersji rozstrzygnięto na Paperless-ngx `3.0.4`; zapisano wieloplatformowy digest obrazu i digesty zależności z oficjalnego Compose v3.0.4.
- Cały M3 wymaga ponownej walidacji Compose, `.env`, OpenAPI, REST, OCR, duplikatów, exporter/importer, sanity checkera oraz E3A/E3B; wyniki i zachowania 2.x nie są dziedziczone.
- Rodzinę duplikatu rozbito na oryginał, kopię binarnie identyczną i ponowny skan tej samej treści.
- Harness BullMQ obejmuje zachowanie `jobId` przed i po usunięciu joba, restart, `stalled`, idempotentny skutek Core i reconciliation.
- Test `pg_dump`/restore w E2 sprawdza zgodność schematu i migracji po odtworzeniu PostgreSQL, a nie jakość ORM jako narzędzia backupowego.
- Porównanie Restic/Borg obejmuje pełną integralność, przerwanie, retencję/prune, drugą kopię klucza, pojedynczy plik, docelowy storage i kompletne E3A/E3B.

## [2026-07-28] — audyt gotowości M3

### Poprawione

- Ujednolicono pojedynczy status dokumentów 01–07 i naprawiono zależności wskazujące stare nazwy plików.
- Ujednolicono hierarchię źródeł prawdy: 07 dla kolejności, 08 dla zakresu, zaakceptowane ADR-y dla decyzji szczegółowych, następnie 06–01.
- Przyjęto standard katalogu `Docs/` z jednoznaczną wielkością liter.
- `DocumentProvider` ograniczono do 10 operacji REST; eksport/import wydzielono jako interfejs utrzymaniowy.
- Dodano ADR-019 opisujący granicę między REST Core a oficjalnymi narzędziami `document_exporter`/`document_importer`.
- ADR-013 przeniesiono do `accepted`; wybór lokalnego filesystemu dla assetów Core nie zależy od E1.
- Gate OS-1 rozdzielono na 7 operacji blokujących i 3 operacje z obowiązkowym fallbackiem.
- E3 otrzymał jawny, nieprodukcyjny fixture Core DB i assetów; brama M3 nazywa się Gate OS-2-LAB, a pełny restore produktu pozostaje bramą M17.
- Test topologii Valkey wymaga osobnego harnessu BullMQ; pomiar samego Paperless nie wystarcza.
- Dodano politykę ochrony dokumentów testowych, surowych odpowiedzi, sekretów i kluczy backupu.
- Dodano manifest przypiętych wersji i digestów obrazów laboratorium.
- Dodano `.gitignore` chroniący dane laboratoryjne, eksporty, repozytoria backupu i sekrety.
- Rozdzielono Gate OS-3-LAB (M3) od Gate OS-3-RELEASE (M22) i usunięto błędne wymaganie gotowego SBOM przed powstaniem produktu.
- E2 otrzymał warunki pass/fail, ważoną punktację i regułę remisu; ADR-014 wskazuje wybór w M3 i użycie od M9.
- E3 korzysta z jednego zamrożonego zestawu odzyskiwania, oficjalnego exporter/importer Paperless oraz każdorazowo czystego celu dla Restic i Borg.
- Doprecyzowano, że dostarczony harness BullMQ nie dowodzi jeszcze deduplikacji ani odporności na restart.

### Stan ADR

- `accepted`: 14
- `proposed`: 5
- razem: 19

---

## [2026-07-27] — Faza 0 / M0–M2 — zamknięcie milestone'ów dokumentacyjnych

### Dodane

- Struktura `Docs/` zgodna z 07 §5: `architecture/`, `adr/`, `domain/`, `workflows/`, `operations/`, `security/`, `api/`, `ux/`.
- `README.md` — indeks dokumentów, hierarchia źródeł prawdy, statusy, zasada aktualizacji.
- `glossary.md` — słownik pojęć domenowych rozstrzygający kolizje terminologiczne.
- `architecture/discrepancy-register.md` — rejestr 20 rozbieżności R-01…R-20 z rozstrzygnięciami.
- `08-MVP-Scope.md` — zamrożony zakres MVP, non-goals, deferred list, decyzje G1, kryteria akceptacji spike'a.
- `adr/09-Architecture-Decisions-Index.md` — indeks 18 ADR-ów.
- `adr/ADR-TEMPLATE.md` — obowiązujący szablon.
- `adr/ADR-001` … `adr/ADR-018` — 12 w statusie `accepted`, 6 w statusie `proposed`.
- `operations/spike-plan.md` — plan wykonawczy trzech eksperymentów E1, E2, E3.
- `security/README.md`, `api/README.md`, `ux/README.md` — zakres i moment powstania dokumentów.

### Zmienione

- Dokumenty 01–07 przeniesione do struktury katalogów i przemianowane na nazwy ASCII-safe (stabilne ścieżki, bez myślników typograficznych).
- Każdy dokument 01–07 otrzymał blok **Status dokumentu** określający zakres obowiązywania i zakres zastąpienia.
- `domain/01-Core-Domain-Model.md` — §30, §32 i §36 oznaczone jako SUPERSEDED.
- `domain/02-Object-Model.md` — §32 (import CSV) oznaczony jako poza zakresem MVP.
- `architecture/03-Technology-Architecture.md` — §18, §27, §31 oznaczone jako SUPERSEDED w zakresie brokera; §13.1 oznaczone jako nazwa historyczna; §13.2 jako niepełna lista stanów.
- `operations/04-Deployment-and-Infrastructure.md` — §4, §8, §22, §28, §31, §45, §47 oznaczone jako SUPERSEDED w odpowiednich zakresach.
- `07-Product-and-Delivery-Roadmap.md` — §8 (M3) uzupełniony o uwagę wykonawczą: spike to trzy odrębne eksperymenty.

### Rozstrzygnięte

- **R-01** Redis → **Valkey** (05 §7, ADR-008).
- **R-02** własny magazyn plików → **Paperless właścicielem binariów** (ADR-005, ADR-006).
- **R-03** OCR w fazie 5 → **OCR Paperless w MVP** (ADR-005).
- **R-08** osobny silnik search → **PostgreSQL FTS + Paperless search** (ADR-009).
- **R-12** Restic/Borg/Kopia → **Restic lub Borg**, rozstrzygane testem pełnego restore (ADR-015).
- Pozostałe 15 rozbieżności — patrz `architecture/discrepancy-register.md`.

### Nierozstrzygnięte świadomie

- **ADR-013** (storage), **ADR-014** (ORM), **ADR-015** (backup) — status `proposed`, rozstrzygane w Fazie 1 przez **trzy różne eksperymenty**.
- **ADR-016**, **ADR-017**, **ADR-018** — status `proposed`, domykane w Fazach 2–3.
- Decyzje G2–G6 — przypisane do bram M9, M10, M12, M13/M14 i M17.

---

## [2026-07-27] — analiza wstępna

- `00-Analiza-i-Mapa-Realizacji.md` v1.0 → v1.2 — rekonstrukcja obrazu projektu na podstawie siedmiu dokumentów; podział na fazy 0–8 zsynchronizowany z milestone'ami; rozdzielenie pierwszego kroku projektu od pierwszego kodu; przypisanie decyzji blokujących do bram G1–G6; rozbicie Fazy 1 na trzy eksperymenty.
