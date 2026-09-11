# M9 — runbook wykonawczy CC: PostgreSQL i Prisma Foundation

**Wersja:** 1.0\
**Status:** `accepted for execution`\
**Data:** 2026-09-09\
**Zakres:** pierwszy techniczny wycinek M9 — lokalny PostgreSQL 18, Prisma i
sprawdzenie połączenia z Core API

> **Rozszerzenie zakresu 2026-09-11.** Właściciel jawnie rozszerzył zakres
> zadania ponad §4.2: dodano workflow CI (`.github/workflows/ci.yml`),
> `apps/api/Dockerfile`, izolowany Compose homelab (`infra/homelab`) oraz
> commit i push po zakończeniu. Pozostałe wykluczenia z §4.2 (tabele i migracje
> domenowe, `prisma db push`, auth, Next.js, Paperless, WireGuard, zmiany w
> `lab/`) obowiązują bez zmian. Treść runbooka poniżej nie była przepisywana;
> wymieniony niżej workspace `@homeos/api` to dzisiejsze `@homeintelcore/api`.

Ten dokument jest kompletnym zadaniem wykonawczym dla Claude Code (dalej:
CC). Koordynator Fable może delegować analizę, implementację i niezależny
przegląd wielu agentom oraz sam wybierać, czy dane zadanie powinien wykonać
Fable, czy Opus 5. Delegowanie nie zmienia źródeł prawdy ani zakresu.

---

## 1. Prompt startowy do wklejenia w CC

```text
Pracujesz w repozytorium HomeOS jako koordynator wykonawczy Fable.

Przeczytaj w całości CLAUDE.md oraz
Docs/operations/M9-PostgreSQL-Prisma-CC-Runbook.md. Następnie wykonaj ten
runbook od początku do końca. Nie poprzestawaj na planie ani analizie: możesz
tworzyć i zmieniać pliki, instalować zależności projektu, uruchomić lokalny
kontener PostgreSQL przeznaczony dla HomeOS i wykonywać testy.

Możesz korzystać z wielu agentów. Sam decyduj, czy zadanie przydzielić Fable,
czy Opus 5, zgodnie z zasadami z runbooka. Najpierw deleguj równoległe zadania
tylko do odczytu. Edycje rozdzielaj według wyłącznej własności plików. Jeden
koordynator odpowiada za package.json, pnpm-lock.yaml, końcową integrację i
raport. Nie pozwalaj dwóm agentom jednocześnie modyfikować tych samych plików.

Nie twórz tabel domenowych ani migracji domenowych. Model M4 nadal jest
draftem. Nie używaj prisma db push. Nie instaluj PostgreSQL w macOS i nie
instaluj Prisma globalnie. Nie modyfikuj laboratorium M3, nie uruchamiaj
Paperless i nie zmieniaj decyzji architektonicznych.

Pracuj autonomicznie do osiągnięcia kryteriów akceptacji albo do wystąpienia
rzeczywistego blokera opisanego w runbooku. Nie commituj i nie pushuj zmian.
Na końcu uruchom pełną walidację, wykonaj niezależny review i przedstaw tylko:
1) wynik, 2) zmienione pliki, 3) wykonane testy z rezultatami,
4) pozostałe problemy lub blokery, 5) dokładne polecenia dla użytkownika.
```

---

## 2. Cel zadania

Po zakończeniu świeży developer ma móc:

1. wygenerować bezpieczną lokalną konfigurację bez wpisywania sekretu do Git,
2. uruchomić tylko Core PostgreSQL 18 przez Docker Compose,
3. sprawdzić wersję i gotowość bazy,
4. wygenerować klienta Prisma,
5. uruchomić Core API,
6. otrzymać niezależny wynik liveness i readiness,
7. uruchomić test z prawdziwym PostgreSQL,
8. zatrzymać środowisko bez utraty danych,
9. powtórzyć wszystkie kontrole z instrukcji w głównym `README.md`.

Ten wycinek przygotowuje mechanizm persistence, ale **nie implementuje modelu
domenowego**. Nie zamyka M4 ani całego M9.

---

## 3. Obowiązujące decyzje i kolejność czytania

Przed edycją koordynator i każdy agent wykonujący pracę architektoniczną ma
przeczytać co najmniej:

1. `CLAUDE.md`,
2. `Docs/07-Product-and-Delivery-Roadmap.md` §3, §9 i §14,
3. `Docs/08-MVP-Scope.md` §2.1, §2.2 i §2.6,
4. `Docs/10-Conceptual-Data-Model.md` §1, §2 i §4,
5. `Docs/adr/ADR-001-monolit-modularny.md`,
6. `Docs/adr/ADR-002-nestjs-core-api.md`,
7. `Docs/adr/ADR-004-postgresql-core.md`,
8. `Docs/adr/ADR-009-postgresql-fts.md`,
9. `Docs/adr/ADR-014-orm.md`,
10. główny `README.md`, `.npmrc`, `package.json`, `pnpm-workspace.yaml` oraz
    bieżące `apps/api`.

W razie rozbieżności obowiązuje hierarchia z `CLAUDE.md`. Agent nie rozstrzyga
milcząco sprzeczności przez kod. Odwracalny szczegół techniczny wybiera
minimalnie, opisuje w raporcie i testuje. Zmiana zaakceptowanego ADR wymaga
zatrzymania pracy i zgłoszenia blokera.

### Wiążące ustalenia dla tego zadania

- Core używa osobnego PostgreSQL; nie łączy się z bazą Paperless.
- ORM to Prisma; Drizzle, TypeORM i MikroORM nie są alternatywami w tym zadaniu.
- Prisma pozostaje w adapterze infrastruktury. Kod domenowy nie importuje
  klienta Prisma ani typów wygenerowanych przez Prisma.
- Raw SQL jest dozwolony, gdy wymaga go PostgreSQL, ale w tym wycinku służy
  wyłącznie do kontroli połączenia i UUIDv7.
- Identyfikatory encji w przyszłości będą UUIDv7 generowanymi przez PostgreSQL
  18. Nie oznacza to zgody na utworzenie obecnie encji domenowych.
- Node.js pozostaje w linii 24, pnpm ma dokładnie wersję zapisaną w głównym
  `package.json`, a wszystkie zależności mają wersje dokładne.
- Jedynym rejestrem npm jest `https://registry.npmjs.org/`.
- Lokalna baza nasłuchuje wyłącznie na `127.0.0.1`.

---

## 4. Granica zakresu

### 4.1. Wchodzi

- dedykowany Compose dla lokalnej bazy Core,
- PostgreSQL 18 z przypiętym tagiem i digestem,
- jednoznaczny nazwany wolumen danych,
- healthcheck PostgreSQL,
- bezpieczny przykład konfiguracji oraz idempotentne utworzenie lokalnego
  pliku środowiskowego,
- Prisma CLI i Prisma Client jako lokalne zależności `apps/api`,
- oficjalny adapter PostgreSQL wymagany przez używaną wersję Prisma,
- minimalny pusty `schema.prisma`, konfiguracja Prisma i generowanie klienta,
- infrastrukturalny adapter/serwis połączenia w NestJS,
- readiness zależne od bazy i liveness niezależne od bazy,
- testy jednostkowe i integracyjne z prawdziwym PostgreSQL 18,
- skrypty uruchomienia, zatrzymania, statusu, logów i walidacji,
- aktualizacja README, dokumentacji i changelogu,
- kontrola sekretów, śmieci, zależności i pełny test końcowy.

### 4.2. Nie wchodzi

- jakakolwiek tabela domenowa, w tym `Workspace`, `Account`, `Membership`,
  `Object`, `AuditEvent` lub ich uproszczone odpowiedniki,
- migracja domenowa albo tymczasowa tabela `probe`,
- `prisma db push`, seed domenowy i Prisma Studio,
- zamykanie M4 lub M9,
- implementacja bootstrapu, auth, sesji, uprawnień i CRUD,
- Next.js, worker, BullMQ, Valkey, Caddy, WireGuard i Paperless,
- CI, produkcyjny Compose, deployment lub instalator serwera,
- instalowanie PostgreSQL przez Homebrew,
- globalna instalacja Prisma, Nest CLI lub pnpm,
- aktualizowanie istniejących zależności bez potrzeby tego zadania,
- zmiana plików `lab/` i artefaktów M3,
- commit, tag, push lub pull request.

Jeżeli agent uważa, że element spoza zakresu jest konieczny, ma najpierw
udowodnić brak prostszego rozwiązania. Bez zgody właściciela pozostawia go jako
jasno opisany kolejny krok.

---

## 5. Zasady orkiestracji wielu agentów

### 5.1. Rola koordynatora Fable

Koordynator:

- utrzymuje plan i kolejność bramek w kontekście zadania, bez tworzenia w repo
  plików typu `notes`, `todo`, transkryptów lub raportów tymczasowych,
- sprawdza stan Git przed rozpoczęciem i nie nadpisuje zmian użytkownika,
- przydziela wyłączną własność plików agentom edytującym,
- jako jedyny modyfikuje `package.json` i `pnpm-lock.yaml`,
- integruje wyniki, rozwiązuje konflikty i usuwa artefakty tymczasowe,
- uruchamia końcową walidację na połączonym stanie repo,
- nie przyjmuje raportu agenta jako dowodu bez sprawdzenia komend i plików.

### 5.2. Dobór Fable albo Opus 5

Fable sam wybiera model. Zalecany podział:

- **Opus 5:** granice architektury, integracja Prisma 7 z NestJS/ESM, lifecycle
  połączenia, obsługa błędów readiness, bezpieczeństwo konfiguracji i końcowy
  review całego diffu.
- **Fable:** inwentaryzacja repo, analiza Compose, mechaniczne skrypty,
  aktualizacja README, uruchamianie walidatorów i zebranie wyników.

Jeżeli Fable potrafi bezpiecznie wykonać zadanie, nie deleguje go tylko po to,
by zwiększyć liczbę agentów. Opus 5 nie jest potrzebny do formatowania lub
odczytu listy plików.

### 5.3. Bezpieczny plan delegacji

Etap rozpoznania może odbyć się równolegle:

| Agent | Tryb | Zadanie | Wynik |
|---|---|---|---|
| A | tylko odczyt | zgodność dokumentacji, ADR i granic M9 | lista wymagań i sprzeczności |
| B | tylko odczyt | bieżący Node/pnpm/Docker, package i lockfile | raport preflight |
| C | tylko odczyt | oficjalne wymagania wybranej wersji Prisma i PostgreSQL | wersje, adapter, ryzyka |

Po rozpoznaniu edycje są rozdzielone:

| Agent | Wyłączna własność | Zakres |
|---|---|---|
| infrastruktura | `infra/dev/**`, skrypt konfiguracji środowiska | Compose i local env |
| API/persistence | `apps/api/**` z wyjątkiem `package.json` | Prisma, readiness, testy |
| dokumentacja | `README.md`, wskazane pliki w `Docs/` | instrukcja i changelog |

`package.json`, `pnpm-lock.yaml`, wspólne konfiguracje, `.gitignore` i końcowe
łączenie należą wyłącznie do koordynatora. Reviewer po implementacji pracuje
tylko do odczytu i szuka regresji, ujawnionych sekretów, naruszeń granic i
nieudowodnionych deklaracji.

Nie wolno uruchamiać równolegle dwóch `pnpm add`, dwóch formatterów zapisujących
całe repo ani dwóch migracji. Jeżeli CC używa osobnych worktree, tylko
koordynator przenosi zaakceptowane zmiany; nie merge'uje automatycznie
sprzecznych lockfile.

---

## 6. Procedura wykonawcza krok po kroku

### Krok 0 — preflight bez zmian

1. Sprawdź bieżący katalog i root repo.
2. Zapisz w raporcie aktualny commit i wynik `git status --short`.
3. Jeżeli są zmiany użytkownika, określ ich pliki i pracuj wokół nich. Nie
   cofaj, nie stashuj i nie formatuj ich bez potrzeby.
4. Sprawdź wersje Node i pnpm względem `.node-version` i `package.json`.
5. Sprawdź `docker context show`, `docker info` i `docker compose version`.
6. Uruchom aktualne `pnpm install --frozen-lockfile` oraz `pnpm check`, zanim
   zmienisz zależności. Zapisz stan bazowy.
7. Sprawdź, czy port planowany dla bazy jest wolny.
8. Sprawdź istniejące projekty Compose, kontenery i wolumeny o nazwie HomeOS.
   Nie przejmuj ani nie usuwaj obiektu, którego pochodzenie jest niepewne.

Jeżeli Docker Desktop nie działa, spróbuj jedynie zwykłego uruchomienia aplikacji
Docker Desktop i ponów `docker info`. Nie zmieniaj uprawnień socketu, grup
systemowych ani ustawień bezpieczeństwa hosta.

### Krok 1 — ustalenie i przypięcie wersji

1. PostgreSQL ma pozostać w majorze 18.
2. Punktem odniesienia jest zweryfikowany obraz M3:

   `docker.io/library/postgres:18@sha256:3a82e1f56c8f0f5616a11103ac3d47e632c3938698946a7ad26da0df1334744a`

3. Przed użyciem sprawdź, czy digest jest manifestem obsługującym architekturę
   bieżącego Maca. Nie usuwaj digestu, by obejść błąd architektury.
4. Prisma E2 została zweryfikowana w wersji `7.9.1`. Użyj dokładnie tej samej
   wersji dla `prisma` i `@prisma/client`, chyba że oficjalne źródło dowodzi
   blokującej niezgodności z bieżącym Node/PostgreSQL. Taka niezgodność jest
   blokerem do decyzji właściciela, a nie zgodą na cichy upgrade.
5. Użyj oficjalnego adaptera PostgreSQL dla tej wersji Prisma oraz `pg`.
   Wszystkie pakiety przypnij dokładnie. Zgodność peer dependencies musi być
   zielona przy istniejącym `strict-peer-dependencies=true` i
   `auto-install-peers=false`.
6. Nie korzystaj z blogów jako źródła API. Pierwszeństwo mają oficjalne docs
   Prisma, oficjalny changelog/registry pakietów i oficjalny obraz PostgreSQL.

W raporcie końcowym zapisz nazwy i dokładne wersje nowych pakietów oraz pełną
referencję obrazu.

### Krok 2 — lokalny Compose Core PostgreSQL

Utwórz mały, samodzielny plik `infra/dev/compose.yaml`.

Wymagania:

- dokładnie jedna usługa Core PostgreSQL; żadnego Paperless ani dodatkowego
  brokera,
- przypięty tag i digest, bez `latest`,
- jednoznaczny projekt/usługa i nazwany wolumen Core,
- brak `container_name`, żeby nie tworzyć globalnych konfliktów,
- publikacja portu tylko jako `127.0.0.1:<port>:5432`,
- domyślny port hosta inny niż standardowe `5432`, preferowany `55432`,
- baza i użytkownik o jednoznacznych nazwach związanych z HomeOS,
- hasło wyłącznie ze zmiennej wymaganej przez Compose,
- healthcheck oparty na `pg_isready`, z rozsądnym interval, timeout, retries i
  start period,
- trwały wolumen montowany w ścieżce właściwej dla oficjalnego obrazu
  PostgreSQL 18,
- `restart` adekwatny dla lokalnego developmentu; baza nie może uruchamiać się
  samoczynnie po każdym starcie laptopa bez jawnej decyzji,
- krótki komentarz tylko przy nieoczywistym ograniczeniu.

Dodaj polecenia projektu dla:

- walidacji rozwiniętego Compose,
- uruchomienia bazy w tle,
- oczekiwania na zdrowie,
- pokazania statusu,
- logów,
- zatrzymania bez usuwania wolumenu,
- wyświetlenia wersji serwera i wyniku funkcji UUIDv7.

Nie dodawaj zwykłego `db:reset`, który bez ostrzeżenia usuwa wolumen. Jeśli
powstaje reset, musi wymagać jawnej frazy potwierdzającej, sprawdzić dokładną
nazwę projektu i opisać nieodwracalny skutek. Reset nie jest wymagany do
zaliczenia tego zadania.

### Krok 3 — jedna lokalna konfiguracja i sekrety

1. Dodaj do Git wyłącznie bezpieczny plik przykładowy. Preferuj jeden root
   `.env.example`, jeżeli nie powoduje to duplikowania już istniejącego źródła.
2. Właściwa lokalna konfiguracja ma być jednym plikiem ignorowanym przez Git.
   Compose, Prisma CLI, test manualny i API nie mogą wymagać ręcznego
   przepisywania tego samego hasła do kilku plików.
3. Przygotuj idempotentne polecenie `dev:setup`, które:
   - tworzy plik tylko wtedy, gdy nie istnieje,
   - generuje kryptograficznie losowe hasło bez wyświetlania go,
   - używa znaków bezpiecznych w URL albo poprawnie koduje komponent URL,
   - buduje poprawny `DATABASE_URL`,
   - ustawia uprawnienia `0600`, gdy system to wspiera,
   - nie nadpisuje istniejącej konfiguracji,
   - nie dopisuje sekretu do logów, historii polecenia ani raportu.
4. Walidacja konfiguracji ma zakończyć proces czytelnym błędem, gdy brakuje
   wartości, pozostał placeholder, URL ma zły protokół albo port jest błędny.
5. `.gitignore` ma ignorować rzeczywisty plik, ale nadal śledzić przykład.

Nie używaj produkcyjnie brzmiących przykładowych sekretów. Przykład może
zawierać jawny placeholder, jeżeli `dev:setup` zastępuje go przed startem.

### Krok 4 — lokalne zależności Prisma

Dodaj zależności wyłącznie do workspace `@homeos/api` przy pomocy pnpm:

- runtime: `@prisma/client`, oficjalny adapter PostgreSQL, `pg`,
- development: `prisma`, typy `pg` i mała zależność do wczytania env tylko
  wtedy, gdy jest rzeczywiście potrzebna.

Koordynator:

1. używa `pnpm --filter @homeos/api add ...`,
2. podaje dokładne wersje,
3. sprawdza diff `apps/api/package.json` i `pnpm-lock.yaml`,
4. nie aktualizuje przy okazji NestJS, TypeScript, ESLint ani innych pakietów,
5. uruchamia `pnpm install --frozen-lockfile` po zapisaniu lockfile.

Nie instaluj nic globalnie. Nie używaj `npm install`, `npx`, Yarn ani Bun.

### Krok 5 — minimalna konfiguracja Prisma bez modelu domenowego

Dodaj w `apps/api`:

- `prisma/schema.prisma`,
- konfigurację Prisma zgodną z wybraną wersją,
- jawny, ignorowany katalog wygenerowanego klienta, jeżeli generator tego
  wymaga.

Schema zawiera tylko generator i datasource. Nie zawiera modeli zastępczych,
`Workspace`, tabel testowych ani komentarza obiecującego niezatwierdzony
schemat. URL bazy nie jest wpisany na stałe i pochodzi z lokalnej konfiguracji.

Uruchom i udowodnij:

- walidację schema,
- generowanie klienta,
- brak wygenerowanych śmieci w `git status`,
- działanie konfiguracji przy uruchomieniu z root repo, nie tylko z katalogu
  `apps/api`.

Nie twórz pustej migracji tylko po to, by pojawił się katalog migrations.
Mechanizm migracji domenowych zostanie wdrożony po zatwierdzeniu odpowiedniej
części M4. W dokumentacji trzeba to nazwać wprost, bez oznaczania rezultatu
„migrations” M9 jako zakończonego.

### Krok 6 — adapter persistence i readiness

Dodaj minimalną infrastrukturę połączenia do `apps/api`.

Wymagania architektoniczne:

- kod trafia do jawnego katalogu infrastruktury/persistence,
- konfiguracja tworzy Prisma Client z oficjalnym adapterem PostgreSQL,
- poza adapterem infrastruktury nie wolno importować Prisma Client ani typów
  wygenerowanych przez Prisma,
- hasło, pełny `DATABASE_URL` i surowy błąd sterownika nie trafiają do logów ani
  odpowiedzi HTTP,
- zamykanie aplikacji zwalnia klienta,
- awaria bazy nie zmienia liveness w readiness,
- `GET /api/v1/health/live` nadal odpowiada, gdy sam proces działa,
- `GET /api/v1/health/ready` wykonuje tani odczyt `SELECT 1`, zwraca sukces przy
  dostępnej bazie i HTTP 503 przy braku połączenia,
- readiness ma krótki, ograniczony czas oczekiwania; nie może wisieć bez końca,
- publiczna odpowiedź jest mała, stabilna i nie ujawnia topologii ani sekretów.

Nie twórz teraz repozytoriów domenowych, Unit of Work, bazowej klasy encji,
generycznego CRUD ani warstwy abstrakcji „na przyszłość”.

### Krok 7 — testy

Dodaj testy proporcjonalne do wycinka:

1. liveness pozostaje zielone i nie wymaga bazy,
2. readiness zwraca sukces dla działającego kontrolowanego adaptera,
3. readiness mapuje awarię adaptera na 503 bez treści błędu i URL,
4. walidator konfiguracji odrzuca brak URL, zły protokół i placeholder,
5. test integracyjny uruchamia prawdziwy PostgreSQL 18 w odizolowanym
   kontenerze albo korzysta z jawnie uruchomionego Compose,
6. test integracyjny potwierdza połączenie i:

   ```sql
   SELECT uuid_extract_version(uuidv7()) = 7;
   ```

7. test integracyjny nie zależy od bazy Paperless, danych M3 ani ręcznie
   istniejącego rekordu,
8. kontener testowy jest usuwany po teście także po błędzie,
9. test nie drukuje hasła ani pełnego URL.

Preferuj Testcontainers, ponieważ należy do rezultatów M9. Jeżeli bieżąca
platforma uniemożliwia wiarygodny test Testcontainers, nie zastępuj go mockiem
i nie deklaruj sukcesu. Udokumentuj bloker oraz oddziel wynik testów
jednostkowych od niewykonanego testu integracyjnego.

### Krok 8 — dokumentacja użytkownika

Zaktualizuj główny `README.md`, tak aby osoba bez wiedzy z tej rozmowy mogła
wykonać kolejno:

1. sprawdzenie Node, pnpm i Docker,
2. instalację zależności z lockfile,
3. utworzenie lokalnej konfiguracji,
4. statyczną walidację Compose,
5. uruchomienie i sprawdzenie PostgreSQL,
6. walidację i generowanie Prisma,
7. uruchomienie API,
8. sprawdzenie liveness i readiness,
9. uruchomienie wszystkich testów,
10. zatrzymanie bazy bez usuwania danych.

Każde polecenie w README musi istnieć i zostać wykonane. Wyjaśnij krótko:

- dlaczego PostgreSQL działa w Dockerze, a nie jako instalacja macOS,
- dlaczego Prisma nie jest globalna,
- gdzie są lokalne dane,
- który plik zawiera sekret i dlaczego nie trafia do Git,
- różnicę między `live` i `ready`,
- że brak modeli i migracji domenowych jest świadomą granicą, nie pomyłką.

Zaktualizuj `Docs/README.md` i `Docs/CHANGELOG.md`. Nie oznaczaj M4, M9 ani
bram M3 jako zamkniętych. Nie dodawaj kopii tego runbooka ani osobnego raportu,
jeżeli changelog i raport końcowy wystarczają.

### Krok 9 — statyczna i dynamiczna walidacja

Minimalna macierz końcowa:

| Kontrola | Oczekiwany wynik |
|---|---|
| `docker compose ... config` | exit 0, brak sekretu w repo |
| rozwinięte `ports` | tylko `127.0.0.1` |
| obraz PostgreSQL | tag 18 i pełny digest |
| healthcheck bazy | healthy |
| wersja SQL | PostgreSQL 18.x |
| UUID | `uuid_extract_version(uuidv7()) = 7` |
| Prisma validate | exit 0 |
| Prisma generate | exit 0 |
| liveness z bazą | HTTP 200 |
| readiness z bazą | HTTP 200 |
| readiness bez bazy | HTTP 503 w ograniczonym czasie |
| liveness bez bazy | HTTP 200 |
| test jednostkowy | wszystkie zielone |
| test integracyjny | wszystkie zielone |
| lint/typecheck/build/format | wszystkie zielone |
| docs checker | wszystkie linki poprawne |
| audit produkcyjny | brak niezaakceptowanej podatności |
| `git status` | tylko oczekiwane pliki źródłowe |

Sekwencja testu awarii bazy nie może niszczyć wolumenu. Zatrzymaj usługę,
sprawdź oba endpointy, uruchom ją ponownie, zaczekaj na `healthy` i ponownie
sprawdź readiness. Na końcu pozostaw lokalną bazę zatrzymaną, chyba że
użytkownik jawnie poprosi o pozostawienie jej uruchomionej.

### Krok 10 — niezależny review

Przed raportem agent review-only sprawdza pełny diff i odpowiada co najmniej na
te pytania:

1. Czy jakikolwiek sekret, token, e-mail użytkownika albo dane M3 weszły do
   śledzonych plików?
2. Czy port PostgreSQL jest osiągalny spoza localhost?
3. Czy wszystkie obrazy i nowe pakiety są przypięte?
4. Czy Prisma wyciekła poza adapter infrastruktury?
5. Czy powstał niezatwierdzony model lub migracja domenowa?
6. Czy liveness przypadkiem zależy od bazy?
7. Czy awaria readiness jest ograniczona czasowo i nie ujawnia błędu?
8. Czy skrypty resetujące lub Docker mogą usunąć cudze dane?
9. Czy główny README działa krok po kroku na świeżym środowisku?
10. Czy dokumentacja nie ogłasza zamknięcia niewykonanych bram?

Koordynator poprawia znaleziska o priorytecie blokującym i ponawia pełną
walidację. Nie kończy zadania z nierozwiązanym błędem bezpieczeństwa,
integralności danych lub powtarzalności instalacji.

---

## 7. Reguły bezpieczeństwa i higieny repo

- Nie wykonuj `git reset --hard`, `git clean -fdx`, `docker system prune`,
  globalnego usuwania obrazów ani wolumenów.
- Nie używaj `sudo` do naprawiania Dockera lub zależności projektu.
- Nie zmieniaj konfiguracji sieci Maca, DNS, VPN, SSH ani Proxmox.
- Nie wyświetlaj zawartości lokalnego env w raporcie.
- Przed usunięciem kontenera lub wolumenu rozwiąż jego dokładną nazwę i
  potwierdź, że został utworzony przez ten projekt.
- Nie zapisuj outputów testów, logów kontenerów, raportów audytu npm ani
  wygenerowanego Prisma Client w Git, chyba że istnieje jawne wymaganie
  projektu dla konkretnego artefaktu.
- Nie dodawaj katalogów bez zawartości, `.gitkeep`, alternatywnych lockfile,
  lokalnych ustawień IDE ani plików z planem agenta.
- Nie formatuj całego repo, jeżeli spowodowałoby to niezwiązany diff.
- Nowy pakiet musi mieć uzasadnione użycie w tym wycinku. Preferuj standardowe
  API Node i istniejące zależności, gdy rozwiązują problem czytelnie.

---

## 8. Warunki zatrzymania i eskalacji

CC zatrzymuje implementację i prosi właściciela o decyzję tylko wtedy, gdy:

- repo ma nakładające się zmiany użytkownika, których nie można zachować,
- przypięty obraz nie obsługuje architektury hosta i brak zgodnego oficjalnego
  digestu dla PostgreSQL 18,
- Prisma 7.9.1 ma potwierdzoną niezgodność blokującą z Node 24 albo
  PostgreSQL 18,
- rozwiązanie wymaga zmiany accepted ADR,
- wymagany jest wybór elementu modelu domenowego,
- Docker nie może zostać uruchomiony zwykłym sposobem,
- wykryto podatność bez dostępnej zgodnej poprawki i ma znaczenie dla tego
  sposobu użycia,
- wykonanie wymaga usunięcia istniejących danych o niepewnym pochodzeniu.

Brak wygody, ostrzeżenie nieblokujące lub możliwość późniejszej optymalizacji
nie są blokerem. Agent wybiera najmniejsze odwracalne rozwiązanie, testuje je i
opisuje.

---

## 9. Kryteria akceptacji

Zadanie jest zakończone wyłącznie, gdy:

1. żaden Postgres ani Prisma nie został zainstalowany globalnie,
2. Core PostgreSQL 18 uruchamia się z przypiętego obrazu i jest dostępny tylko
   na localhost,
3. lokalny sekret powstaje poza Git i nie jest wypisywany,
4. Compose przechodzi walidację,
5. Prisma 7.9.1 przechodzi validate/generate i łączy się przez oficjalny
   adapter PostgreSQL,
6. schema nie zawiera modeli domenowych,
7. liveness i readiness mają poprawnie rozdzielone znaczenie,
8. prawdziwy PostgreSQL potwierdza działanie `uuidv7()`,
9. testy jednostkowe oraz integracyjne są zielone,
10. pełne `pnpm check` jest zielone,
11. README umożliwia powtórzenie procesu bez wiedzy z rozmowy,
12. niezależny reviewer nie znalazł problemu blokującego,
13. `git diff --check` przechodzi,
14. `git status` nie zawiera sekretów, wyników, cache ani innych śmieci,
15. baza jest na końcu zatrzymana bez usunięcia wolumenu,
16. koordynator nie wykonał commita ani pushu.

Jeżeli test integracyjny jest niemożliwy z powodu rzeczywistego blokera
środowiska, zadanie pozostaje częściowo wykonane. Raport nie może używać słowa
„gotowe” bez jawnego wskazania brakującego kryterium.

---

## 10. Format raportu końcowego CC

Raport ma być krótki i dowodowy:

```text
Wynik: GOTOWE / CZĘŚCIOWO GOTOWE / ZABLOKOWANE

Zmienione pliki:
- ...

Walidacja:
- polecenie — PASS/FAIL — kluczowy wynik

Przypięte komponenty:
- pakiet/obraz — wersja/digest — zastosowanie

Bezpieczeństwo i dane:
- ekspozycja portu
- stan sekretów w Git
- stan wolumenu po zakończeniu

Pozostałe problemy:
- brak albo konkretna lista

Następne polecenia użytkownika:
1. ...
2. ...
```

Raport nie zawiera tokenów, haseł, pełnego `DATABASE_URL`, wielostronicowych
logów ani deklaracji niewspartych testem.
