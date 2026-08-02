# Rejestr rozbieżności

**Status:** `accepted` · **Milestone:** M0 · **Data:** 2026-07-27

> Trwały zapis 20 rozbieżności wykrytych między dokumentami 01–04 a 05–07 oraz ich rozstrzygnięć.
>
> **Zasada:** nie tworzymy kompromisów. Wskazujemy decyzję obowiązującą i oznaczamy poprzednią jako zastąpioną.
>
> Ten dokument istnieje po to, żeby rozstrzygnięty spór **nie wracał jako pytanie w trakcie implementacji**. Jeżeli w kodzie pojawia się wątpliwość dotycząca którejkolwiek z poniższych pozycji, odpowiedź jest tutaj — nie w dyskusji.

---

## 1. Hierarchia rozstrzygania

```
07  >  06  >  05  >  04  >  03  >  02  >  01
```

Dokumenty **05–07** są nadrzędne w zakresie: stosu technologicznego, komponentów OSS, architektury technicznej, integracji, workflow, kolejek, przetwarzania dokumentów, deploymentu, kolejności wdrażania, faz realizacji i granic MVP.

Dokumenty **01–04** pozostają źródłem prawdy w zakresie: wizji produktu, celów użytkownika, modelu domenowego, relacji, potrzeb gospodarstwa domowego, filozofii produktu, przypadków użycia — oraz (dla 04) całej warstwy operacyjnej.

---

## 2. Rejestr

| # | Obszar | Starsza decyzja | Nowsza decyzja | Źródło prawdy | Rozstrzygnięcie | ADR |
|---|---|---|---|---|---|---|
| **R-01** | Broker kolejki | **Redis** — 03 §18, §27, §31, §34; 04 §4, §6, §8, §9, §22, §24, §39, §41, §45, §47 | **Valkey** — 05 §3, §4, §7, §8, §30; 06 §2; 07 §7 | **05, 06, 07** | **Obowiązuje Valkey.** Wszystkie wystąpienia „Redis" w 03 i 04 czytać jako „Valkey". Uzasadnienie: BSD-licensed, zgodny z protokołem Redis, preferowany przy założeniu pełnego open source i potencjalnej dystrybucji. Wymaga korekty Compose, diagramów topologii i nazw wolumenów (`data/valkey/`) | ADR-008 |
| **R-02** | Zarządzanie dokumentami | **Własne** — 01 §30 (`FS[(Magazyn plików)]`), §16, §28 | **Paperless-ngx jako bounded context i właściciel binariów** — 03 §12; 05 §5.1, §28; 07 §7 | **05, 07** | **Obowiązuje Paperless.** Core **nie przechowuje** binariów dokumentów. `ObjectStorageProvider` + filesystem obsługuje **wyłącznie assety Core**. Alternatywa „Core przechowuje oryginał, Paperless kopię" jest jawnie odrzucona (03 §12.1) | ADR-005, ADR-006 |
| **R-03** | OCR | **Własny / AI, w fazie 5** — 01 §22, §26, §30, §32 | **OCR Paperless, w MVP** — 03 §3, §12; 05 §2.3, §5.1; 06 §11.5; 07 §6, §8 | **05, 06, 07** | **Obowiązuje OCR Paperless w MVP.** Własny OCR jest komponentem odłożonym wymagającym nowego ADR. AI w 5.x dotyczy semantic search, summaries i enrichment — **nie OCR** | ADR-005 |
| **R-04** | Konwersja dokumentów | **Osobne narzędzia** — 03 §17 (Tika, Poppler, ImageMagick), §16 (LibreOffice CLI) | **Gotenberg w pipeline Paperless** — 03 §27; 05 §2.3, §9; 06 §14 | **05, 06** | **Obowiązuje Gotenberg**, używany w sposób wspierany przez Paperless. **Nie budujemy drugiego, równoległego pipeline'u konwersji.** Tika działa jako zależność wspieranego procesu Paperless — bez osobnej instancji Core | — |
| **R-05** | Backend aplikacji | Niejawna możliwość Next.js Route Handlers jako backendu | **NestJS jedynym publicznym API** — 03 §6, §7; 05 §13, §14; 07 §7 | **05, 07** | **Obowiązuje NestJS jako Core API.** Next.js odpowiada wyłącznie za UI i PWA: brak domeny w Route Handlers, brak dostępu do DB, brak sekretów, brak wywołań Paperless. Test architektury w CI wykrywa naruszenia | ADR-002, ADR-003 |
| **R-06** | Styl architektury | Mikroserwisy jako kierunek docelowy — 03 §7.3 | **Monolit modułowy** — 01 §30, §33.15; 03 §5.1–§5.2; 05 §14; 07 §7, §36 | **07** | **Obowiązuje monolit modułowy.** Schemat z 03 §7.3 opisuje odległą przyszłość, nie plan MVP. „Zbyt wczesne mikroserwisy" są jawnie ryzykiem (01 §34) i rzeczą zakazaną (07 §36) | ADR-001 |
| **R-07** | Dostęp sieciowy | Nieokreślony / możliwy publiczny — 01 §27 | **LAN + opcjonalny WireGuard, brak publicznego endpointu** — 04 §3, §13, §15, §43; 05 §21; 07 §6, §7 | **04, 05, 07** | **Obowiązuje LAN jako podstawa, WireGuard jako opcja.** Zakazane: port forwarding do aplikacji, UPnP dla serwera, publiczne wystawienie Paperless/PostgreSQL/Valkey/Gotenberg | ADR-011 |
| **R-08** | Wyszukiwanie | **Osobny silnik** — 01 §30 (`S[Wyszukiwarka]`), §22 | **PostgreSQL FTS (Core) + Paperless search (dokumenty)** — 03 §19, §27; 05 §2.3, §19; 06 §21; 07 §7, §12 | **05, 06, 07** | **Obowiązuje PostgreSQL FTS + `pg_trgm` + `unaccent` + GIN dla Core oraz Paperless search dla treści.** Meilisearch i OpenSearch odłożone — wymagają **mierzalnego** problemu | ADR-009 |
| **R-09** | Storage obiektowy | **MinIO** rozważany — 03 §20, §27 | **Lokalny filesystem za portem `ObjectStorageProvider`** — 03 §20; 05 §4, §18; 07 §6, §7 | **05, 07** | **Obowiązuje lokalny filesystem.** MinIO dodaje usługę, backup i aktualizacje. Port istnieje od początku, więc migracja jest możliwa bez przebudowy domeny. Dotyczy **wyłącznie assetów Core** | ADR-013 |
| **R-10** | Zarządzanie tożsamością | **Rozbudowany IdP** rozważany — 03 §21, §27 | **Własny auth NestJS + port `IdentityProvider`** — 03 §21; 05 §20; 07 §6, §7 | **05, 07** | **Obowiązuje własny auth.** Argon2id, HttpOnly Secure SameSite, rate limiting, audit logowania, przygotowanie do MFA. MFA/passkeys → wydanie 1.1 | ADR-012 |
| **R-11** | Model wielodostępu | **Uniwersalność wielo-Workspace / mała firma** — 01 §6, §9.2, §33.12 | **Jedna instalacja i baza = jeden Workspace; brak SaaS i multi-tenancy** — 07 §2, §6, §25; 10 §M4-D02 | **07, 10** | **Obowiązuje singleton Workspace.** `workspace_id` jest relacją strukturalną nadawaną przez serwer, a nie wybieranym kontekstem lub predykatem autoryzacji. Nie ma przełączania, filtracji tenantów ani dostępu między Workspace w jednej bazie. Wiele profili klienta łączy się z osobnymi instalacjami | — |
| **R-12** | Narzędzie backupu | **Restic, Borg, Kopia** — 04 §28 | **Restic lub Borg** — 05 §16; 07 §22, §36 | **05, 07** | **Kopia wypada z krótkiej listy.** Decyzję Restic/Borg rozstrzygają wykonane E3A (przenośność) i E3B (disaster recovery), nie porównanie funkcji | ADR-015 |
| **R-13** | Roadmap produktu | **Fazy 0–5** z 01 §32 | **Milestone'y M0–M22** z 07 + roadmapa po MVP | **07** | **Obowiązuje roadmapa z 07.** Roadmap z 01 §32 zastąpiony w całości. Różnice: OCR wchodzi do MVP; backup jest bramą MVP; synchronizacja kalendarzy wychodzi do wydania 1.2 | — |
| **R-14** | Lista dokumentów | **15 dokumentów** z 01 §36 | **13 dokumentów** z 07 §29 z zasadą just-in-time | **07** | **Obowiązuje lista z 07 §29.** Dokumenty szczegółowe powstają **just-in-time przed odpowiadającym milestone**, nie wszystkie naraz bez kontaktu z prototypem | — |
| **R-15** | Przypomnienia | **Pełny model** — 01 §19, 02 §21 (cykliczne, wielokrotne, kanały, kalendarze) | **MVP: jednokrotne, snooze, complete, in-app** — 06 §25; 07 §21 | **06, 07** | **Obowiązuje wąski zakres MVP.** Model danych z 02 §21 pozostaje projektowo aktualny jako struktura, ale funkcje cykliczne, wielokanałowe i kalendarzowe **nie są implementowane w MVP**. Kalendarz → wydanie 1.2 | — |
| **R-16** | Import danych | **Import CSV w MVP** — 02 §32 | **Import masowy poza MVP** — 07 §6, §28 | **07** | **Import CSV i masowy nie wchodzą do MVP.** Kontrakt zachowania z 06 §26 pozostaje aktualny jako specyfikacja do implementacji w wydaniu 1.1. W MVP działa wyłącznie upload pojedynczych plików | — |
| **R-17** | Nazewnictwo warstwy integracji | **„Document Gateway"** jako komponent — 03 §4, §13.1 | **Port `DocumentProvider` + `PaperlessAdapter`** — 03 §8; 05 §2.4, §5.4; 06 §11.5; 07 §11, §16 | **05, 06, 07** | **Obowiązuje terminologia `DocumentProvider` / `PaperlessAdapter`.** „Document Gateway" to wcześniejsza nazwa **tej samej odpowiedzialności**, nie osobny komponent. Oznaczone jako alias historyczny w `glossary.md` | ADR-007 |
| **R-18** | Zakres monitoringu | **Rozbudowany etap 1 i 2** — 04 §31 | **Etap 1 wystarcza dla MVP** — 05 §4, §17; 07 §24 | **05, 07** | **W MVP: health endpoint, structured logs, alert miejsca, alert backupu, stan kolejki.** Pełny stack metryk po wejściu realnych danych. Ryzyko „zbyt ciężkiego monitoringu" jest jawne | — |
| **R-19** | Statusy dokumentu | **8 stanów** — 03 §13.2 | **14 stanów** — 06 §12 | **06** | **Obowiązuje 14-stanowa state machine z 06 §12.** Dodane: `uploading`, `validating`, `quarantined_security`, `queued`, `trashed`; `failed` rozbite na `failed_retryable` i `failed_permanent`. Każda zmiana stanu walidowana przez state machine, nie przez zapis pola | ADR-017 |
| **R-20** | Odczyt statusu przetwarzania | „Polling na start, później SSE" — 03 §22 | „Polling lub SSE" — 06 §11.7 | **06** (zgodne z 03) | **Brak realnej sprzeczności.** Obowiązuje **polling w MVP**, SSE jako ulepszenie, WebSocket wyłącznie po udowodnionej potrzebie. Do zapisania w `14-API-Specification.md` (M8) | — |

---

## 3. Rozbieżności pozorne — rozstrzygnięte w glossary

Cztery kolizje wymagały ujednolicenia terminologii, nie decyzji merytorycznej. Rozstrzygnięcia znajdują się w [`../glossary.md`](../glossary.md) §1:

- `DocumentRecord` vs `DocumentReference` / `DocumentProjection` / `ObjectDocumentLink`
- `Asset` vs `plik` vs `dokument`
- tagi Core vs tagi Paperless
- „Faza" z 01 §32 vs „Milestone" z 07

---

## 4. Zasada zgłaszania nowych rozbieżności

1. Rozbieżność wykryta w trakcie implementacji **trafia tutaj**, nie jest rozstrzygana milcząco w kodzie.
2. Rozstrzygnięcie następuje przez wskazanie dokumentu wyższego w hierarchii. Jeżeli oba dokumenty są na tym samym poziomie lub żaden nie rozstrzyga — powstaje **nowy ADR**.
3. Decyzja zastąpiona otrzymuje w dokumencie źródłowym oznaczenie **SUPERSEDED BY** z numerem dokumentu następcy i numerem pozycji w tym rejestrze.
4. **Nie tworzymy sztucznych kompromisów** między sprzecznymi decyzjami technologicznymi.
