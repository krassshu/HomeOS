# 03 — Technology Architecture

## Architektura technologiczna lokalnej platformy „domowego segregatora”

**Wersja:** 0.4

**Status:** `accepted z wyjątkami (dokument mieszany)`

**Data weryfikacji:** 2026-07-27

**Zależności:** [`../domain/01-Core-Domain-Model.md`](../domain/01-Core-Domain-Model.md), [`../domain/02-Object-Model.md`](../domain/02-Object-Model.md)

**Zakres:** segregator, obiekty, dokumenty, pliki, wyszukiwanie i przygotowanie pod dalszy rozwój

**Poza zakresem bieżącej implementacji:** Home Assistant, kamery, NVR, energia, lokalizacja i AI

> ## Status dokumentu
>
> | Pole | Wartosc |
> |---|---|
> | **Status** | `accepted z wyjatkami (dokument mieszany)` |
> | **Priorytet w hierarchii zrodel prawdy** | Piaty z 7 |
> | **Obowiazuje w zakresie** | granice wlasnego kodu, monolit modulowy, Next.js/NestJS, rozdzial baz Core i Paperless, Paperless jako bounded context, port `DocumentProvider`, PostgreSQL FTS, model auth MVP, REST + OpenAPI, monorepo, testy, obserwowalnosc, licencje |
> | **Nie obowiazuje w zakresie** | **Broker: wszystkie wystapienia Redis -> Valkey** (R-01). **ADR-007 BullMQ/Redis -> BullMQ/Valkey**. **§13.1 Document Gateway** to alias historyczny portu `DocumentProvider` + `PaperlessAdapter` (R-17). **§13.2** lista 8 stanow niepelna -> 14 stanow z 06 §12 (R-19) |
> | **Ostatni przeglad** | 2026-07-27 (Faza 0 / M0) |
> | **Rejestr rozbieznosci** | [`discrepancy-register.md`](../architecture/discrepancy-register.md) |
>
> Hierarchia zrodel prawdy: **07 dla kolejnosci, 08 dla zakresu, accepted ADR dla decyzji szczegolowych, nastepnie 06 > 05 > 04 > 03 > 02 > 01**.
> Pelne uzasadnienie: [`00-Analiza-i-Mapa-Realizacji.md`](../00-Analiza-i-Mapa-Realizacji.md), sekcja 8.


***

# 1. Cel

Dokument określa stos technologiczny, granice własnego kodu, rolę projektów open source, przepływ dokumentu oraz sposób zachowania możliwości późniejszej wymiany komponentów.

Najważniejsze pytania:

* co piszemy sami,
* czego nie przepisujemy,
* gdzie znajduje się źródło prawdy,
* jak aplikacja rozmawia z Paperless-ngx,
* jak działa upload, OCR, miniatura i podgląd,
* jak łączymy wyniki wyszukiwania,
* czy NestJS jest właściwym backendem,
* jak uniknąć przedwczesnych mikroserwisów,
* jak przygotować projekt do późniejszego zespołu i monetyzacji,
* jakie są ryzyka licencyjne oraz operacyjne.

***

# 2. Decyzja nadrzędna

> Produkt ma być jedną spójną aplikacją wykorzystującą wyspecjalizowane usługi open source, a nie zbiorem obcych paneli ani próbą napisania ich od nowa.

Użytkownik widzi:

* jeden interfejs,
* jedno logowanie,
* jeden dashboard,
* jeden model obiektów,
* jedną wyszukiwarkę,
* jedną historię działań.

Wewnątrz mogą działać niezależne silniki, ale nie są one bezpośrednio dostępne dla klienta.

***

# 3. Zakres własnego kodu

Własna aplikacja odpowiada za:

* Workspace,
* konta i  członkostwa,
* obiekty osób, rzeczy, miejsc i usług,
* dynamiczne pola,
* szablony,
* relacje,
* domenowe tagi,
* prywatność i uprawnienia,
* dashboard i UX,
* przypinanie dokumentów do obiektów,
* terminy oraz przypomnienia,
* audit domenowy,
* globalną wyszukiwarkę,
* synchronizację z usługami,
* obsługę błędów i trybu zdegradowanego,
* import oraz eksport domeny,
* publiczne API,
* późniejsze adaptery Home Assistant, kamer i innych modułów.

Nie piszemy samodzielnie:

* OCR,
* parsera PDF,
* silnika konwersji Office,
* generatora podstawowych miniatur dokumentów,
* indeksu pełnotekstowego OCR,
* dojrzałego DMS,
* antywirusa,
* protokołu VPN,
* silnika Smart Home.

***

# 4. Architektura wysokiego poziomu

```
flowchart LR UI[Next.js / PWA] 
GW[Reverse proxy] 
API[NestJS Core API] 
W[NestJS Worker] 
DB[(PostgreSQL Core)] 
R[(Redis / BullMQ)] 
DG[Document Gateway] 
P[Paperless-ngx] 
PDB[(PostgreSQL Paperless)] 
PM[(Paperless media)] 
G[Gotenberg] 


UI --> GW 
GW --> UI 
GW --> API 
API --> DB 
API --> R 
R --> W 
API --> DG 
W --> DG 
DG --> P 
P --> PDB 
P --> PM 
P --> G
```

Zewnętrznie dostępne są tylko kontrolowane trasy reverse proxy. Paperless, Gotenberg, Redis i bazy pozostają usługami wewnętrznymi.

***

# 5. Styl architektury

## 5.1. Monolit modułowy

Rekomendowany start:

* jeden backend NestJS,
* jeden proces API,
* jeden lub kilka procesów worker,
* jedna domenowa baza PostgreSQL,
* jasno wydzielone moduły,
* osobny bounded context dokumentów realizowany przez Paperless.

Przykładowe moduły:

```
auth 
workspace 
membership 
object 
template 
field 
relation 
tag
asset 
document 
search 
reminder 
audit
integration 
system
```

## 5.2. Dlaczego nie mikroserwisy

Mikroserwisy na tym etapie zwiększyłyby:

* liczbę wdrożeń,
* liczbę punktów awarii,
* koszt monitoringu,
* problem transakcji rozproszonych,
* narzut sieciowy,
* koszt pracy solo developera.

Granice modułów powinny być mocne, ale fizyczne rozdzielenie nastąpi dopiero przy realnej potrzebie.

***

# 6. Frontend — Next.js

Next.js odpowiada za interfejs:

* dashboard,
* listy i widoki obiektów,
* formularze,
* upload,
* podgląd dokumentu,
* wyszukiwarkę,
* onboarding,
* ustawienia,
* PWA.

Rekomendacja:

* TypeScript,
* App Router,
* Server Components dla prostych odczytów,
* Client Components dla formularzy i interakcji,
* lokalne fonty i assety,
* brak zewnętrznych CDN,
* brak bezpośredniej komunikacji z Paperless,
* brak logiki domenowej w Route Handlers.

Next.js nie jest głównym backendem. Route Handlers mogą obsługiwać wyłącznie funkcje specyficzne dla warstwy web.

## 6.1. PWA

PWA jest najlepszym pierwszym krokiem mobilnym:

* jeden kod,
* instalacja na ekranie głównym,
* responsywność,
* prostsze wydanie,
* brak sklepów.

Ograniczenia:

* słabsza praca w tle,
* różnice iOS/Android,
* ograniczenia systemowych powiadomień i integracji.

Natywna aplikacja może powstać później, korzystając z tego samego API.

***

# 7. Backend — NestJS

NestJS jest:

* jedynym publicznym API,
* właścicielem reguł biznesowych,
* bramą uwierzytelniania,
* orkiestratorem integracji,
* producentem zadań,
* źródłem audytu,
* warstwą abstrakcji nad Paperless.

## 7.1. Zalety

* wspólny język z frontendem,
* silne typowanie,
* dependency injection,
* modułowość,
* dojrzałe wsparcie kolejek,
* OpenAPI,
* dobra produktywność,
* skalowanie procesów poziomo.

## 7.2. Ograniczenia

* ciężkie CPU nie powinno działać w głównym procesie,
* ekosystem npm wymaga kontroli,
* łatwo stworzyć sprzężony „wielki monolit”,
* duże pliki muszą być streamowane,
* zadania długie muszą trafić do workerów.

## 7.3. Czy NestJS wystarczy w przyszłości

Tak. NestJS może pozostać API Gatewayem i rdzeniem domenowym, podczas gdy ciężkie moduły będą działać obok:

```
NestJS Core 
├── Python AI/OCR service 
├── Home Assistant adapter 
├── camera event service 
├── energy adapter 
└── search service
```

Nie framework jest głównym ograniczeniem, lecz brak granic, kontraktów i testów.

***

# 8. Przenośność i możliwość zmiany języka

Aby kiedyś wydzielić lub przepisać moduł:

* API musi mieć wersjonowany kontrakt OpenAPI,
* zdarzenia muszą mieć stabilne schematy,
* domena nie może zależeć od ORM,
* integracje muszą implementować porty,
* frontend nie może znać szczegółów backendu,
* zachowanie musi być pokryte testami kontraktowymi,
* migracje danych muszą być jawne,
* identyfikatory nie mogą wynikać z konkretnego frameworka.

Przykładowy port:

```json
interface DocumentProvider { 
  ingest(command: IngestDocument): Promise<ExternalDocumentRef>; 
  getMetadata(ref: ExternalDocumentRef): Promise<DocumentMetadata>; 
  getOriginal(ref: ExternalDocumentRef): Promise<Readable>; 
  getPreview(ref: ExternalDocumentRef): Promise<Readable>; 
  search(query: DocumentSearch): Promise<DocumentSearchResult>; 
  remove(ref: ExternalDocumentRef): Promise<void>; 
}
```

Implementacja MVP:

```
PaperlessDocumentProvider
```

***

# 9. PostgreSQL

## 9.1. Core PostgreSQL

Przechowuje:

* Workspace,
* konta,
* członkostwa,
* obiekty,
* pola,
* wartości,
* relacje,
* domenowe tagi,
* przypięcia dokumentów,
* projekcje metadanych,
* przypomnienia,
* audit,
* stan synchronizacji.

## 9.2. PostgreSQL Paperless

Paperless posiada własną bazę.

Zasady bezwzględne:

* Core nie czyta tabel Paperless,
* Core nie modyfikuje bazy Paperless,
* integracja odbywa się przez oficjalne API,
* migracje Paperless należą do Paperless,
* obie bazy mają oddzielne backupy,
* Core zapisuje stabilny zewnętrzny identyfikator.

Wspólna baza stworzyłaby bardzo silne sprzężenie i ryzyko awarii po aktualizacji.

***

# 10. ORM i migracje

Kandydaci:

## Prisma

Plusy:

* bardzo dobry DX,
* generowane typy,
* szybki start.

Minusy:

* czasem ogranicza zaawansowany PostgreSQL,
* wymaga raw SQL dla części indeksów i funkcji.

## Drizzle

Plusy:

* blisko SQL,
* mocne typowanie,
* mniejsza abstrakcja,
* dobre dopasowanie do PostgreSQL.

Minusy:

* mniej gotowych wzorców,
* wymaga większej dyscypliny zespołu.

## MikroORM / TypeORM

Plusy:

* klasyczne encje,
* integracja z NestJS.

Minusy:

* ryzyko niejawnych zapytań,
* łatwo połączyć domenę z ORM.

### Rekomendacja

Przeprowadzić mały proof of concept dla Drizzle i Prisma, obejmujący:

* dynamiczne pola,
* transakcje,
* audit,
* indeksy FTS,
* migrację,
* test restore.

Preferowany kierunek: **Drizzle lub Prisma z jawnie dopuszczonym raw SQL**.

***

# 11. Dynamiczne pola

Rekomendowany model hybrydowy:

* rdzeń obiektu w normalnych kolumnach,
* definicje pól w tabelach,
* wartości typowane albo JSONB,
* ważne pola indeksowane,
* walidacja w domenie i bazie.

Nie tworzymy kolumny dla każdego pola użytkownika.

Nie przechowujemy całej domeny w jednym bezkształtnym JSONB, ponieważ utrudnia to:

* relacje,
* indeksowanie,
* historię,
* migracje,
* raporty,
* walidację.

***

# 12. Paperless-ngx jako Document Bounded Context

Paperless odpowiada za:

* binarny oryginał dokumentu,
* archiwalną kopię PDF,
* OCR,
* ekstrakcję tekstu,
* miniatury,
* techniczne metadane,
* indeks dokumentów,
* wykrywanie identycznych plików.

Core odpowiada za:

* relacje dokument–obiekt,
* prywatność w aplikacji,
* znaczenie dokumentu,
* właścicieli,
* terminy,
* audit,
* projekcję danych,
* synchronizację.

## 12.1. Decyzja o pliku źródłowym

Rekomendacja MVP:

> Paperless jest właścicielem plików dokumentowych, a Core właścicielem ich kontekstu.

Zalety:

* brak podwójnego storage,
* wykorzystanie pełnego pipeline’u,
* szybsze MVP,
* mniej własnego kodu.

Wady:

* krytyczna zależność,
* migracja wymaga eksportu,
* backup musi obejmować dwa systemy,
* Core musi obsługiwać niedostępność Paperless.

Alternatywa „Core przechowuje oryginał, Paperless kopię” daje większą niezależność, ale powoduje duplikację i trudną synchronizację. Nie jest rekomendowana na start.

***

# 13. Integracja z Paperless

Wyłącznie przez oficjalne REST API.

Zakazane:

* bezpośrednie zapytania do jego DB,
* ręczna modyfikacja katalogów,
* token w frontendzie,
* publiczne wystawienie Paperless,
* zależność od nieudokumentowanych endpointów.

## 13.1. Document Gateway

> **NAZWA HISTORYCZNA** - ta sama odpowiedzialnosc wystepuje w 05, 06 i 07 jako port **`DocumentProvider`**
> z implementacja **`PaperlessAdapter`** (R-17). Nie jest to osobny komponent do zbudowania.
> Obowiazujaca terminologia: `glossary.md`.

Odpowiada za:

* upload,
* odczyt statusu,
* pobranie metadanych,
* pobranie oryginału,
* pobranie miniatury,
* pobranie archiwalnego PDF,
* wyszukiwanie,
* mapowanie błędów,
* retry,
* circuit breaker,
* metryki,
* ukrycie API Paperless.

## 13.2. Stany

> **SUPERSEDED BY 06 §12** - ponizsza lista 8 stanow jest niepelna (R-19).
> Obowiazuje **14-stanowa** state machine: dodane `uploading`, `validating`, `quarantined_security`, `queued`, `trashed`;
> `failed` rozbite na `failed_retryable` i `failed_permanent`.

```
pending_upload 
uploaded 
processing 
ready 
failed 
missing_external 
delete_pending 
deleted
```

## 13.3. Przepływ uploadu

```
sequenceDiagram 
participant UI 
participant API 
participant DB 
participant Q as BullMQ 
participant W as Worker 
participant P as Paperless 


UI->>API: plik + objectId 
API->>DB: record pending_upload 
API->>Q: enqueue 
API-->>UI: 202 + status 
URL W->>P: upload 
P-->>W: task reference 
W->>DB: processing 
W->>P: poll result 
P-->>W: documentId + metadata 
W->>DB: ready + projection
```

## 13.4. Reconciliation

Okresowe zadanie:

* wykrywa zbyt długie `processing`,
* sprawdza brakujące dokumenty,
* aktualizuje projekcję,
* wykrywa usunięcia poza aplikacją,
* raportuje rozjazdy,
* ponawia zadania bezpiecznie.

***

# 14. Tagi i korespondenci

Core posiada tagi domenowe.

Paperless posiada tagi dokumentowe.

Nie należy bezpośrednio utożsamiać obu systemów.

Możliwe mapowanie:

```json
Core: samochód 
Paperless: ctx:vehicle
```

Podobnie:

* Paperless correspondent „PZU” może być mapowany do obiektu organizacji „PZU”,
* document type „Polisa” może być projekcją, nie głównym typem obiektu,
* mapping przechowuje external ID.

***

# 15. PDF, miniatury i podgląd

Paperless już realizuje część pipeline’u:

* miniaturę,
* OCR,
* archiwalny PDF,
* parsery.

Dlatego na początku:

* nie uruchamiamy własnego generatora miniaturek,
* miniatura jest derivative dokumentu, nie zdjęciem w galerii,
* oryginał i kopia archiwalna są rozróżniane,
* frontend pobiera je przez autoryzowany endpoint Core.

Podgląd:

* PDF.js,
* strumieniowanie,
* obsługa HTTP Range, jeśli konieczna,
* brak bezpośredniego URL do Paperless,
* ostrożne cache dla danych medycznych i prywatnych.

***

# 16. Gotenberg

Gotenberg dostarcza kontenerowe API do:

* konwersji Office do PDF,
* HTML do PDF,
* PDF/A,
* łączenia i dzielenia PDF,
* operacji narzędziami PDF.

Zalety:

* nie trzeba sterować LibreOffice z NestJS,
* izolacja,
* proste API,
* gotowy kontener.

Wady:

* zużycie CPU i RAM,
* ograniczenia współbieżności LibreOffice,
* możliwe różnice renderowania,
* konieczne limity i timeouty,
* nie może być publiczny.

Rekomendacja:

* używać w sposób wspierany przez Paperless,
* nie tworzyć drugiego, równoległego pipeline’u bez konkretnej potrzeby.

***

# 17. Tika, Poppler, ImageMagick i ClamAV

## Apache Tika

Przydatna do metadanych i tekstu z wielu formatów. W MVP może działać jako zależność wspieranego procesu Paperless. Nie dodajemy osobnej instancji Core.

## Poppler

Przydatny do renderowania i inspekcji PDF. Dodajemy dopiero, gdy Paperless nie dostarcza wymaganego derivative.

## ImageMagick

Nie jest obowiązkowy. Jego szerokie możliwości zwiększają powierzchnię konfiguracji i bezpieczeństwa.

## ClamAV

Może skanować uploady.

Plusy:

* lokalny,
* dodatkowa warstwa ochrony.

Minusy:

* RAM,
* aktualizacje sygnatur,
* opóźnienie,
* nie zastępuje sandboxingu.

Decyzja:

* opcjonalny etap po MVP,
* pipeline od początku posiada kwarantannę i punkt integracyjny.

***

# 18. Redis i BullMQ

> **SUPERSEDED BY 05 §7-§8 - obowiazuje Valkey, nie Redis** (R-01).
> Tresc sekcji pozostaje merytorycznie aktualna; nalezy czytac Redis jako Valkey.
> Uzasadnienie: Valkey jest BSD-licensed i zgodny z protokolem Redis (05 §7).

Zastosowania:

* ingestion,
* status OCR,
* retry,
* reconciliation,
* eksporty,
* powiadomienia,
* przyszłe zadania integracyjne.

Zasady:

* Redis nie jest źródłem prawdy,
* payload nie zawiera całych plików,
* zadania są idempotentne,
* retry ma exponential backoff,
* istnieje failed queue,
* zadanie ma timeout,
* istnieje limit współbieżności,
* API nie czeka na OCR,
* po awarii możliwe jest ponowne zlecenie z DB.

RabbitMQ nie jest potrzebny na start. Może pojawić się przy wielu niezależnych usługach i wymaganiach routingu wiadomości.

***

# 19. Wyszukiwanie

> **AKTUALNE** - PostgreSQL FTS dla Core + Paperless search dla dokumentow, potwierdzone przez 05 §19 i ADR-009.

Wyniki pochodzą z dwóch źródeł:

## Core

* nazwy,
* opisy,
* typy,
* kategorie,
* tagi,
* własne pola,
* notatki,
* relacje.

Technologie:

* PostgreSQL Full Text Search,
* GIN,
* `pg_trgm`,
* `unaccent`.

## Paperless

* treść OCR,
* tytuł dokumentu,
* korespondent,
* typ,
* tagi dokumentowe.

## Agregacja

NestJS:

* odpytuje oba źródła,
* normalizuje wynik,
* stosuje uprawnienia,
* scala ranking,
* zwraca jeden format.

Nie dodajemy OpenSearch ani Meilisearch na początku.

Dodanie zewnętrznej wyszukiwarki wymaga mierzalnej potrzeby:

* problemy wydajnościowe,
* duże facety,
* setki tysięcy rekordów,
* wymagany wspólny indeks,
* tolerancja literówek niewystarczająca w PostgreSQL.

***

# 20. Storage assetów Core

> **AKTUALNE** - `ObjectStorageProvider` + lokalny filesystem; MinIO odlozone (05 §18, R-09).
> Dotyczy **wylacznie assetow Core** (avatary, zdjecia obiektow, ikony, eksporty). Dokumenty naleza do Paperless.

Dokumenty są przechowywane przez Paperless.

Core może potrzebować:

* avatarów,
* zdjęć obiektów,
* ikon,
* eksportów.

Rekomendacja:

* `StoragePort`,
* implementacja lokalnego filesystemu w MVP,
* możliwość późniejszej implementacji S3/MinIO.

MinIO nie jest potrzebne bez konkretnej potrzeby. Dodaje kolejną krytyczną usługę, backup i aktualizacje.

***

# 21. Uwierzytelnianie

## Własny auth w NestJS

Zalety:

* mniej usług,
* prostszy onboarding,
* kontrola UX.

Wady:

* odpowiedzialność za bezpieczeństwo,
* sesje,
* reset,
* MFA,
* passkeys.

## Authentik / Keycloak

Zalety:

* SSO,
* MFA,
* dojrzałe zarządzanie sesjami.

Wady:

* znacząca złożoność,
* kolejny punkt awarii,
* przerost dla domu.

### Rekomendacja MVP

* NestJS auth,
* Argon2id,
* server-side sessions lub krótki access token + rotowany refresh,
* HttpOnly Secure SameSite cookies,
* rate limiting,
* audit logowania,
* przygotowanie do MFA,
* możliwość przyszłego adaptera IdP.

***

# 22. API

Rekomendacja:

* REST,
* `/api/v1`,
* OpenAPI generowane w buildzie,
* jawne błędy,
* idempotency key dla uploadu i ważnych operacji,
* optimistic concurrency,
* pagination,
* correlation ID.

Status przetwarzania:

* polling na start,
* później Server-Sent Events,
* WebSocket dopiero przy realnej potrzebie.

***

# 23. Monorepo

```
home-platform/ 
├── apps/ 
│ ├── web/ 
│ ├── api/ 
│ └── worker/ 
├── packages/ 
│ ├── contracts/ 
│ ├── domain/ 
│ ├── ui/ 
│ ├── config/ 
│ ├── observability/ 
│ └── test-utils/ 
├── deploy/ 
├── docs/ 
│ ├── architecture/ 
│ ├── adr/ 
│ ├── operations/ 
│ └── api/ 
└── tools/
```

Rekomendacja:

* pnpm workspaces,
* Turborepo opcjonalnie,
* Nx dopiero przy realnej wartości.

***

# 24. Testy i jakość

Minimum:

* TypeScript strict,
* lint,
* format,
* unit tests,
* integration tests z prawdziwym PostgreSQL,
* contract tests Paperless,
* E2E upload → OCR → podgląd → wyszukiwanie,
* test migracji,
* test awarii Paperless,
* test retry,
* test uprawnień,
* test eksportu,
* test restore.

***

# 25. Obserwowalność

Od początku:

* logi JSON,
* request ID,
* correlation ID,
* job ID,
* health endpoints,
* stan kolejek,
* czas Paperless API,
* liczba failed jobs,
* dokumenty długo przetwarzane,
* stan backupu,
* miejsce na dysku.

Start:

* Pino,
* Docker logs,
* prosty panel health.

Później:

* Prometheus,
* Grafana,
* Loki,
* Alertmanager.

***

# 26. Licencje

Każda zależność ma rejestr:

* nazwa,
* wersja,
* licencja,
* źródło,
* digest,
* modyfikacje,
* wymagane notices.

Paperless-ngx jest GPLv3. Prywatne lokalne użycie jest prostsze, ale dystrybucja, modyfikacje i monetyzacja wymagają formalnego przeglądu.

Zasady:

* integracja przez API,
* nie kopiować kodu Paperless do zamkniętego modułu,
* zachować informacje licencyjne,
* prowadzić `THIRD_PARTY_NOTICES.md`,
* generować SBOM,
* przed komercjalizacją wykonać przegląd prawny.

Dokument nie jest poradą prawną.

***

# 27. Macierz decyzji

> **CZESCIOWO SUPERSEDED** - wiersz Kolejka: BullMQ + Redis -> **BullMQ + Valkey** (R-01). Pozostale wiersze aktualne.

|               |                    |                            |                    |
| ------------- | ------------------ | -------------------------- | ------------------ |
| Web           | Next.js            | React SPA                  | Next.js            |
| API           | NestJS             | Spring / ASP.NET / FastAPI | NestJS             |
| Core DB       | PostgreSQL         | —                          | PostgreSQL         |
| DMS/OCR       | Paperless-ngx      | Mayan / własny pipeline    | Paperless          |
| Konwersja     | Gotenberg          | LibreOffice CLI            | Gotenberg          |
| Kolejka       | BullMQ + Redis     | RabbitMQ                   | BullMQ             |
| Search Core   | PostgreSQL FTS     | Meilisearch                | PostgreSQL         |
| OCR Search    | Paperless          | OpenSearch                 | Paperless          |
| PDF viewer    | PDF.js             | browser viewer             | PDF.js             |
| Asset storage | filesystem adapter | MinIO                      | filesystem         |
| Auth          | NestJS             | Authentik                  | NestJS             |
| Antivirus     | później ClamAV     | brak                       | punkt integracyjny |
| Orkiestracja  | Docker Compose     | Kubernetes                 | Compose            |

***

# 28. Świadomie odkładane technologie

* Kubernetes,
* Kafka,
* OpenSearch,
* MinIO,
* Keycloak,
* pełne mikroserwisy,
* GraphQL,
* event sourcing,
* service mesh,
* własny OCR,
* AI,
* natywna aplikacja mobilna,
* obowiązkowa chmura.

***

# 29. Ryzyka i ograniczenia

## Uzależnienie od Paperless

Ograniczenie:

* port `DocumentProvider`,
* API-only,
* operacyjny eksport/import poza Core (ADR-019),
* projekcja,
* testy kontraktowe,
* pinowanie wersji.

## Rozjazd Core i Paperless

Ograniczenie:

* statusy,
* idempotencja,
* reconciliation,
* retry,
* raport administracyjny.

## Zmiana API Paperless

Ograniczenie:

* staging,
* contract tests,
* adapter,
* aktualizacja kontrolowana.

## Awaria Redis

Ograniczenie:

* DB jako źródło prawdy,
* możliwość odbudowy kolejki,
* brak dużych payloadów.

## Rozrost monolitu

Ograniczenie:

* granice modułów,
* testy architektury,
* porty,
* zakaz importów do internals innych modułów.

***

# 30. Pionowy prototyp

Przed budową pełnego UI:

1. Utwórz obiekt.
2. Wyślij PDF.
3. API zapisuje rekord.
4. BullMQ tworzy zadanie.
5. Worker wysyła dokument do Paperless.
6. Paperless wykonuje OCR.
7. Worker pobiera stan i metadane.
8. UI pokazuje miniaturę.
9. PDF.js pokazuje dokument.
10. Wyszukiwanie znajduje obiekt po nazwie.
11. Wyszukiwanie znajduje dokument po OCR.
12. Wyłącz Paperless i sprawdź degradację.
13. Przywróć i wykonaj reconciliation.
14. Wykonaj backup oraz restore.

***

# 31. ADR-y przed implementacją

> **SUPERSEDED BY 07 §7** - obowiazuje lista 18 minimalnych ADR-ow z roadmapy oraz dodatkowe ADR-y odkryte w audytach, zaimplementowane w `adr/`.
> W szczegolnosci ADR-007 BullMQ/Redis odpowiada **ADR-008 Valkey + BullMQ**.

* ADR-001 Monolit modułowy.
* ADR-002 NestJS jako Core API.
* ADR-003 Paperless jako bounded context.
* ADR-004 API-only integration.
* ADR-005 Właściciel pliku dokumentowego.
* ADR-006 PostgreSQL FTS.
* ADR-007 BullMQ/Redis.
* ADR-008 Auth.
* ADR-009 Storage Core.
* ADR-010 Pinowanie wersji.
* ADR-011 Licencje.
* ADR-012 Strategia degradacji.

***

# 32. Kryteria zatwierdzenia

Architektura jest gotowa do MVP, gdy:

* Core i Paperless mają jasne odpowiedzialności,
* wiadomo, gdzie znajduje się oryginał,
* upload jest asynchroniczny,
* frontend nie zna Paperless,
* Paperless nie jest publiczny,
* wyszukiwanie ma strategię,
* działa reconciliation,
* backup obejmuje wszystkie źródła prawdy,
* licencje są zarejestrowane,
* pionowy prototyp przechodzi test restore.

***

# 33. Źródła

Oficjalne materiały zweryfikowane 2026-07-27:

* https://docs.paperless-ngx.com/
* https://docs.paperless-ngx.com/api/
* https://docs.paperless-ngx.com/setup/
* https://docs.paperless-ngx.com/configuration/
* https://docs.paperless-ngx.com/development/
* https://github.com/paperless-ngx/paperless-ngx/blob/dev/LICENSE
* https://docs.nestjs.com/techniques/queues
* https://docs.nestjs.com/techniques/task-scheduling
* https://nextjs.org/docs/app
* https://www.postgresql.org/docs/current/textsearch.html
* https://www.postgresql.org/docs/current/pgtrgm.html
* https://www.postgresql.org/docs/current/unaccent.html
* https://gotenberg.dev/docs/getting-started/introduction
* https://gotenberg.dev/docs/convert-with-libreoffice/convert-to-pdf
* https://docs.docker.com/get-started/docker-overview/

Numery wersji powinny znajdować się w manifestach deploymentu, lockfile i ADR-ach wydania, nie w długowiecznym opisie architektury.

***

# 34. Rekomendowany rdzeń

```
Next.js ↓ NestJS Core API 
├── PostgreSQL Core 
├── Redis / BullMQ 
├── NestJS Worker 
└── DocumentProvider ↓ Paperless-ngx 
├── PostgreSQL Paperless 
├── media storage 
└── Gotenberg
```

To rozwiązanie jest wykonalne dla jednej osoby, nie tworzy koła od nowa i zachowuje drogę do późniejszego zespołu oraz większej platformy.
