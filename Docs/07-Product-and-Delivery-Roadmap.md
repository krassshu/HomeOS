# 07 — Product and Delivery Roadmap

## Kamienie milowe od dokumentacji do stabilnego domowego segregatora

**Wersja:** 0.7

**Status:** `accepted`

**Data:** 2026-07-28

**Horyzont:** przygotowanie, pionowy prototyp i stabilne MVP

**Poza horyzontem:** Home Assistant, kamery, energia i AI

> ## Status dokumentu
>
> | Pole | Wartosc |
> |---|---|
> | **Status** | `accepted` |
> | **Priorytet w hierarchii zrodel prawdy** | **Najwyzszy dla kolejnosci, milestone'ow i bram** |
> | **Obowiazuje w zakresie** | **wszystko** - kolejnosc prac, milestone'y M0-M22, bramy zamiast dat, granice MVP, lista 18 minimalnych ADR-ow oraz dodatkowe ADR-y odkryte w audytach, kolejnosc dokumentow, Definition of Ready i Done, metryki sukcesu, model wydan, roadmapa po MVP |
> | **Nie obowiazuje w zakresie** | - (brak wyjatkow) |
> | **Ostatni przeglad** | 2026-07-28 (baseline Paperless 3.0.4 i korekta E3A/E3B) |
> | **Rejestr rozbieznosci** | [`discrepancy-register.md`](architecture/discrepancy-register.md) |
>
> Hierarchia zrodel prawdy: **07 dla kolejnosci, 08 dla zakresu, accepted ADR dla decyzji szczegolowych, nastepnie 06 > 05 > 04 > 03 > 02 > 01**.
> Pelne uzasadnienie: [`00-Analiza-i-Mapa-Realizacji.md`](00-Analiza-i-Mapa-Realizacji.md), sekcja 8.


***

# 1. Cel

Roadmapa utrzymuje właściwą kolejność pracy. Nie jest kalendarzem obietnic. Etapy kończą się po spełnieniu kryteriów jakości, nie po upływie czasu.

Zasada nadrzędna:

> Najpierw udowadniamy najtrudniejszy pionowy przepływ, a dopiero potem zwiększamy szerokość produktu.

***

# 2. Definicja pierwszego produktu

Pierwsza wersja jest domowym segregatorem:

* jeden Workspace w UI,
* kilku użytkowników,
* elastyczne obiekty,
* dynamiczne pola,
* miękkie szablony,
* dokumenty,
* relacje,
* tagi,
* podstawowe przypomnienia,
* wyszukiwanie,
* archive i trash,
* lokalne wdrożenie,
* backup i restore.

Nie jest:

* platformą Smart Home,
* systemem kamer,
* ERP,
* pełnym systemem workflow DMS,
* SaaS,
* systemem AI.

***

# 3. Zasady realizacji

## 3.1. Bramy zamiast dat

Każdy milestone ma:

* cel,
* kryteria wejścia,
* rezultaty,
* kryteria wyjścia,
* ryzyka,
* jawne non-goals.

## 3.2. Ścieżka krytyczna

```
dokumentacja 
→ decyzje 
→ spike Paperless 
→ model danych 
→ kontrakty 
→ pionowy upload 
→ search 
→ backup/restore 
→ pilot 
→ stabilizacja
```

## 3.3. Brak technologii na zapas

Komponent lub funkcja wchodzi tylko, gdy:

* ma use case,
* ma właściciela,
* ma test,
* ma wpływ na backup opisany,
* przechodzi ADR.

***

# 4. Stan dokumentacji

## Przygotowane i obowiązujące

* Core Domain Model,
* Object Model,
* Technology Architecture,
* Deployment and Infrastructure,
* Open Source Architecture,
* System Workflows and Processing Pipelines,
* Product and Delivery Roadmap.
* MVP Scope,
* Architecture Decisions Index i ADR-001…ADR-019,
* glossary i rejestr rozbieżności,
* plan E1, E2, E3A i E3B, polityka danych i manifest laboratorium.

## Do przygotowania just-in-time przed właściwą bramą

* Conceptual Data Model,
* Permissions and Privacy Model,
* Document Integration Contract,
* Search Specification,
* API Specification,
* Threat Model,
* Test Strategy,
* UX Information Architecture,
* Backup and Restore Runbook,
* Definition of Done.

Nie należy tworzyć tych dokumentów wszystkich naraz. Każdy powstaje przed bramą wskazaną w §29 i musi zamknąć decyzje, których kod nie powinien zgadywać.

***

# 5. Milestone M0 — Repozytorium dokumentacji

## Cel

Jedno źródło prawdy dla decyzji.

## Struktura

```
/Docs
  /architecture 
  /adr 
  /domain 
  /workflows 
  /operations 
  /security 
  /api 
  /ux
```

## Rezultaty

* indeks dokumentów,
* glossary,
* statusy `draft/proposed/accepted/deprecated`,
* wersjonowanie,
* changelog,
* zasada aktualizacji dokumentacji z kodem.

## Gate

* każdy dokument ma status,
* pojęcia domenowe są spójne,
* znane sprzeczności są zapisane,
* ADR ma ustalony szablon.

***

# 6. Milestone M1 — Zamrożenie MVP Scope

## Wchodzi

* bootstrap pierwszego użytkownika,
* konta i zaproszenia,
* single Workspace UI,
* obiekty,
* dynamiczne pola,
* templates,
* relacje,
* dokumenty,
* Paperless OCR,
* thumbnail i preview,
* search,
* archive,
* trash,
* audit podstawowy,
* reminders podstawowe,
* backup/restore,
* LAN,
* samodzielny WireGuard jako jedyna droga dostępu zdalnego; aktywacja w danej
  instalacji może zostać pominięta.

## Nie wchodzi

* AI,
* Home Assistant,
* kamery,
* energia,
* geolokalizacja,
* publiczna chmura,
* multi-tenant SaaS,
* natywna aplikacja,
* OpenSearch,
* MinIO,
* Keycloak,
* Kubernetes.

## Rezultaty

* `08-MVP-Scope.md`,
* user stories,
* acceptance criteria,
* non-goals,
* deferred list.

## Gate

Nowa funkcja w czasie MVP musi zastąpić inną albo trafić do deferred.

***

# 7. Milestone M2 — ADR Foundation

## Cel

Zamrozić decyzje o wysokim koszcie zmiany.

## Minimalne ADR-y

1. Monolit modułowy.
2. NestJS jako Core API.
3. Next.js jako web/PWA.
4. PostgreSQL Core.
5. Paperless jako Document Bounded Context.
6. Paperless właścicielem binaries na MVP.
7. API-only integration.
8. Valkey + BullMQ.
9. PostgreSQL FTS przed search engine.
10. Caddy jako gateway.
11. WireGuard jako remote access.
12. Model auth MVP.
13. Storage provider.
14. ORM.
15. Narzędzie backupu.
16. Polityka licencyjna.
17. State machines i reconciliation.
18. Audit policy.

## Szablon ADR

* kontekst,
* problem,
* decyzja,
* alternatywy,
* konsekwencje pozytywne,
* konsekwencje negatywne,
* warunki ponownej analizy,
* status i data.

***

# 8. Milestone M3 — Open Source Spike

> **UWAGA WYKONAWCZA.** Open Source Spike ma cztery niezależnie oceniane tory:
> **E1** Paperless / Gotenberg / Valkey · **E2** osobny PoC ORM · **E3A** przenośność exporter/importer · **E3B** disaster recovery baz i plików.
> E1 rozstrzyga Gate OS-1 i topologię ADR-008, E2 rozstrzyga ADR-014, a E3A razem z E3B rozstrzygają ADR-015 i Gate OS-2-LAB. OS-3-LAB domyka ADR-016. ADR-013 i ADR-019 są przyjęte przed eksperymentami.
> Plan wykonawczy: [`operations/spike-plan.md`](operations/spike-plan.md).

## Cel

Sprawdzić od zera założenia Paperless **3.0.4**, Gotenberg i Valkey bez budowy produktu. Wyniki ani zachowania serii 2.x nie są uznawane za dowód.

## Eksperymenty Paperless

* baseline o strukturze oficjalnego Compose `postgres-tika` z taga `v3.0.4`, z referencjami obrazów przypiętymi tagami i digestami + wersjonowane pliki override i wariantów,
* Paperless `3.0.4` przypięty tagiem i wieloplatformowym digestem z manifestu,
* token API,
* OpenAPI pobrany z uruchomionej instancji 3.0.4 i zachowany z checksum,
* upload przez API,
* task status,
* OCR języka polskiego,
* thumbnail,
* original,
* archive PDF,
* search OCR,
* tag,
* correspondent,
* document type,
* delete,
* przygotowanie interfejsu utrzymaniowego bez pełnego restore.

## Eksperymenty odzyskiwania

* **E3A:** exporter 3.0.4 → backup kandydata → czysty Paperless 3.0.4 z tym samym digestem → importer 3.0.4 → nowy token → sanity checker → walidacja dokumentów i OCR,
* **E3B:** zamrożenie zapisów → dump obu PostgreSQL → media i assety → backup kandydata → czysty cel → restore Paperless 3.0.4 z tym samym digestem → sanity checker → reconciliation → walidacja biznesowa,
* oba tory osobno dla Restic i Borg.

## Eksperymenty formatów

* PDF tekstowy,
* skan PDF,
* JPG/PNG,
* DOCX,
* XLSX,
* wielostronicowy skan,
* duży plik,
* uszkodzony PDF,
* rodzina duplikatu: oryginał, kopia binarnie identyczna i ponowny skan tej samej treści,
* dokument z polskimi znakami.

## Pomiary

* RAM idle i peak,
* CPU OCR,
* czas OCR,
* przyrost dysku,
* rozmiar derivative,
* zachowanie przy restarcie,
* zachowanie przy pełnym brokerze.

## Gate

* siedem blokujących operacji REST działa, a trzy pozostałe mają działanie lub przetestowany fallback,
* E3A: eksport utrzymaniowy został zaimportowany do czystej instancji i przeszedł sanity checker,
* E3B: surowy restore obu baz i plików przeszedł sanity checker, reconciliation i walidację biznesową,
* zasoby są akceptowalne,
* Gate OS-3-LAB: inwentarz licencji laboratorium jest kompletny i zaakceptowany,
* brak krytycznego ograniczenia.

Jeżeli gate nie przechodzi, dopiero wtedy porównujemy alternatywne DMS.

***

# 9. Milestone M4 — Conceptual Data Model

## Encje

* Workspace,
* Account,
* Membership,
* Role/Permission,
* Object,
* ObjectType/Category,
* FieldDefinition,
* FieldValue,
* Template,
* Relation,
* Tag,
* DocumentReference,
* DocumentProjection,
* ObjectDocumentLink,
* Reminder,
* AuditEvent,
* Invitation,
* Integration,
* IntegrationTask,
* TrashRecord.

## Dla każdej encji

* identyfikator,
* właściciel,
* lifecycle,
* visibility,
* timestamps,
* version,
* invariants,
* retencja,
* external references.

## Rezultaty

* ERD koncepcyjny,
* słownik danych,
* invariants,
* przykładowe rekordy,
* polityka JSONB,
* wstępna strategia indeksów.

## Gate

Każdy proces z dokumentu workflows można odwzorować bez specjalnego obejścia.

***

# 10. Milestone M5 — Permissions and Privacy

## Zakres

* owner,
* admin,
* member,
* invite permission,
* access object,
* access document,
* private object,
* inheritance,
* download original,
* permanent delete,
* audit access.

## Trudne przypadki

* dokument powiązany z obiektem publicznym i prywatnym,
* użytkownik zna ID,
* search bez permission,
* prywatny duplikat,
* usunięty członek,
* utrata konta ownera,
* dokument medyczny członka rodziny.

## Rezultaty

* macierz ról,
* macierz zasób × akcja,
* reguły dziedziczenia,
* deny rules,
* test matrix.

## Gate

Żaden endpoint dokumentowy nie opiera bezpieczeństwa wyłącznie na frontendzie.

***

# 11. Milestone M6 — Document Integration Contract

## Cel

Zdefiniować `DocumentProvider` przed adapterem.

## Operacje

* ingest,
* task status,
* metadata,
* original stream,
* preview stream,
* thumbnail,
* search,
* update mapped metadata,
* trash/delete,
* health.

Eksport/import jest kontraktem utrzymaniowym z ADR-019 i nie należy do `DocumentProvider`.

## Wymagania

* timeout,
* retry classification,
* idempotency,
* error mapping,
* correlation,
* contract tests,
* mock provider,
* compatibility matrix wersji.

## Gate

Pozostałe moduły nie znają endpointów ani typów Paperless.

***

# 12. Milestone M7 — Search Specification

## Zakres

* PostgreSQL FTS,
* `pg_trgm`,
* `unaccent`,
* Paperless search,
* agregacja,
* ranking,
* permissions,
* partial results,
* filtry,
* pagination,
* highlighting,
* polskie znaki.

## Scenariusze

* „ubezpieczenie auta”,
* nazwa lekarza,
* fragment treści faktury,
* numer VIN,
* chip psa,
* instrukcja routera,
* literówka w nazwie.

## Gate

Specyfikacja wyjaśnia, jak wynik z dwóch silników staje się jednym bez ujawniania prywatnych danych.

***

# 13. Milestone M8 — API Contract

## Zakres

* auth,
* bootstrap,
* invitations,
* objects,
* fields,
* templates,
* relations,
* tags,
* documents,
* upload,
* preview,
* search,
* reminders,
* audit,
* health.

## Standardy

* REST `/api/v1`,
* OpenAPI,
* pagination,
* error catalog,
* idempotency,
* ETag/version,
* async operation resource,
* streaming,
* correlation ID.

## Gate

Frontend można zaprojektować bez wiedzy o DB i Paperless.

***

# 14. Milestone M9 — Engineering Foundation

## Rezultaty

* monorepo,
* pnpm workspaces,
* TypeScript strict,
* lint i format,
* CI,
* test containers,
* local Compose,
* config validation,
* structured logging,
* health endpoints,
* migrations,
* dependency policy,
* SBOM,
* branch/release policy.

## Gate

Nowy developer lub świeży host uruchamia projekt z README i uzyskuje zielone testy.

***

# 15. Milestone M10 — Core Skeleton

## Funkcje

* bootstrap,
* auth,
* Workspace,
* Membership,
* invitation link,
* Object CRUD,
* dynamic fields,
* templates,
* audit,
* health.

## Wymagania

* migracje,
* integration tests,
* permission tests,
* E2E bootstrap,
* Core DB backup,
* Core DB restore.

Nie budujemy jeszcze pełnego design systemu.

***

# 16. Milestone M11 — Adapter Paperless

## Rezultaty

* port `DocumentProvider`,
* Paperless adapter,
* token jako secret,
* contract test suite,
* error mapping,
* circuit breaker,
* retry policy,
* fake provider,
* compatibility report.

## Gate

Żaden moduł poza adapterem nie importuje typów Paperless ani nie zna jego URL-i.

***

# 17. Milestone M12 — Vertical Slice: Upload

## Flow

```
login 
→ create object 
→ upload PDF 
→ processing 
→ ready 
→ thumbnail 
→ preview
```

## Wymagania

* streaming,
* kwarantanna,
* checksum,
* idempotency,
* BullMQ,
* Valkey,
* worker,
* retry,
* status UI,
* audit,
* failure UI.

## Gate

* restart workera nie tworzy duplikatu,
* Paperless down daje czytelny stan,
* plik nie ginie,
* E2E przechodzi,
* kwarantanna jest czyszczona.

***

# 18. Milestone M13 — Vertical Slice: Search

## Zakres

* Core FTS,
* Paperless search,
* agregacja,
* permission filtering,
* partial response,
* highlighting,
* podstawowe filtry.

## Testy

* polskie znaki,
* literówka,
* prywatny dokument,
* Paperless down,
* duży wynik,
* pusty query,
* filtr po obiekcie.

## Gate

Użytkownik potrafi odnaleźć reprezentatywne dokumenty po nazwie obiektu i treści OCR.

***

# 19. Milestone M14 — Organizacja dokumentów

## Zakres

* wiele powiązań,
* tagi,
* correspondent mapping,
* document type projection,
* nieprzypisane,
* bulk link,
* archive,
* trash,
* restore,
* permanent delete,
* duplicate handling.

## Scenariusze akceptacyjne

* samochód i polisa,
* lekarz i wyniki,
* pies i szczepienia,
* dom i faktury,
* urządzenie i gwarancja.

## Gate

Scenariusze działają bez osobnego hardkodowanego modułu dla auta, psa czy lekarza.

***

# 20. Milestone M15 — UX Information Architecture

## Widoki

* Home,
* Search,
* Objects,
* Object Detail,
* Documents,
* Upload,
* Processing,
* Unassigned,
* Trash,
* Members,
* Settings,
* System Health.

## Zasady UX

* proste słownictwo,
* widoczne statusy,
* brak nazw Paperless/Gotenberg dla użytkownika,
* mobile-first upload,
* accessibility,
* obsługa klawiatury,
* dobre empty states,
* recovery actions,
* brak ślepych toastów jako jedynej informacji.

## Rezultaty

* sitemap,
* wireframes,
* formularze,
* error states,
* responsive rules,
* accessibility checklist.

***

# 21. Milestone M16 — Reminders MVP

## Zakres

* termin obiektu,
* termin dokumentu,
* reminder jednokrotny,
* snooze,
* complete,
* in-app notification,
* Europe/Warsaw i DST.

## Non-goals

* Google Calendar,
* Apple Calendar,
* CalDAV,
* natywny push,
* złożone reguły.

## Gate

Polisa, przegląd auta i szczepienie mogą mieć poprawne terminy.

***

# 22. Milestone M17 — Backup and Restore Production

## Zakres

* wybór Restic/Borg,
* dump Core DB,
* dump Paperless DB,
* media,
* konfiguracja,
* recovery secrets,
* szyfrowanie,
* retencja,
* off-host,
* alert,
* pełny restore.

## Gate bezwzględny

Na czystej maszynie:

* odtworzono stack,
* zalogowano się,
* otwarto dokumenty,
* wykonano OCR search,
* sprawdzono relacje,
* zweryfikowano checksum.

Bez tego nie ma produkcyjnego MVP.

***

# 23. Milestone M18 — Threat Model i Hardening

## Zakres

* TLS,
* WireGuard,
* firewall,
* secrets,
* rate limits,
* headers,
* upload limits,
* container hardening,
* dependency scan,
* session revocation,
* owner recovery,
* opcjonalny ClamAV.

## Threat actors

* zgubiony telefon,
* złośliwy plik,
* podatny parser,
* członek bez uprawnień,
* zainfekowany komputer LAN,
* błędna aktualizacja,
* ransomware,
* kradzież backupu.

## Gate

Brak niezaakceptowanych ryzyk krytycznych i wysokich.

***

# 24. Milestone M19 — Operations

## Zakres

* health dashboard,
* disk alert,
* stale backup alert,
* queue alert,
* degraded Paperless,
* log rotation,
* runbooks,
* version manifest,
* controlled update,
* staging.

## Gate

Operator potrafi:

* zdiagnozować awarię,
* przywrócić backup,
* zaktualizować,
* wykonać rollback,
* rotować sekret,
* odłączyć zgubiony telefon.

***

# 25. Milestone M20 — Household Pilot

## Zakres

* jedna rodzina,
* 100–500 dokumentów,
* rzeczywiste obiekty,
* prawdziwe terminy,
* telefon i desktop.

## Obserwacje

* czas dodania,
* skuteczność OCR,
* trafność search,
* liczba nieprzypisanych,
* błędy użytkownika,
* brakujące pola,
* problemy prywatności,
* czas backupu,
* zużycie dysku,
* liczba ręcznych interwencji.

## Zasada

Nie przebudowujemy architektury po pojedynczej opinii. Szukamy powtarzalnego problemu.

***

# 26. Milestone M21 — Stabilizacja

## Priorytety błędów

1. utrata danych,
2. bezpieczeństwo,
3. błędne uprawnienia,
4. search,
5. upload,
6. niezrozumiały UX,
7. wydajność,
8. kosmetyka.

## Release criteria

* zero znanych data-loss bugs,
* pełny restore test,
* krytyczne E2E,
* dokumentacja operatora,
* release notes,
* SBOM,
* notices,
* rollback plan.

***

# 27. Milestone M22 — MVP 1.0

## Zawartość

* lokalny segregator,
* obiekty,
* dokumenty,
* OCR,
* wyszukiwanie,
* relacje,
* dynamiczne pola,
* reminders,
* użytkownicy,
* backup,
* prywatny remote access,
* audit podstawowy.

## Po wydaniu

Okres bez nowych dużych modułów:

* monitoring,
* poprawki,
* aktualizacje zależności,
* regularne restore tests,
* ergonomia.

***

# 28. Roadmapa po MVP

## 1.1

* lepszy bulk import,
* ulepszone templates,
* saved searches,
* lepszy audit,
* MFA/passkeys,
* rozszerzone powiadomienia.

## 1.2 — Calendar Foundation

* własny widok terminów,
* iCal export,
* później CalDAV/Google/Apple.

## 2.x — Home Assistant

* adapter,
* mapowanie Object → Device → Entity,
* sterowanie,
* bez zastępowania HA.

## 3.x — Cameras

* osobny bounded context,
* integracja NVR,
* retencja,
* prywatność.

## 4.x — Energy

* falowniki,
* liczniki,
* telemetry,
* automatyzacje.

## 5.x — AI

Dopiero po dojrzałych danych, uprawnieniach i audycie:

* semantic search,
* summaries,
* suggestions,
* enrichment,
* AI nigdy nie jest source of truth.

***

# 29. Kolejność dokumentów do napisania teraz

1. `08-MVP-Scope.md`
2. `09-Architecture-Decisions-Index.md`
3. kluczowe ADR-y
4. `10-Conceptual-Data-Model.md`
5. `11-Permissions-and-Privacy.md`
6. `12-Document-Integration-Contract.md`
7. `13-Search-Specification.md`
8. `14-API-Specification.md`
9. `15-Threat-Model.md`
10. `16-Test-Strategy.md`
11. `17-UX-Information-Architecture.md`
12. `18-Backup-and-Restore-Runbook.md`
13. `19-Definition-of-Done.md`

Dokumenty szczegółowe powstają just-in-time przed odpowiadającym milestone, a nie wszystkie naraz bez kontaktu z prototypem.

***

# 30. Priorytet bezwzględny

```
Paperless API spike 
→ DocumentProvider 
→ upload 
→ OCR 
→ preview 
→ search 
→ backup 
→ restore
```

Dopiero później szeroki interfejs i dodatkowe funkcje.

***

# 31. Definition of Ready

Zadanie może wejść do developmentu, gdy:

* ma cel użytkownika,
* ma acceptance criteria,
* ma właściciela danych,
* ma uprawnienia,
* ma stan błędu,
* ma test,
* ma wpływ na backup opisany,
* nie przeczy ADR,
* znajduje się w zakresie.

***

# 32. Definition of Done

Funkcja jest ukończona, gdy:

* kod działa,
* testy przechodzą,
* błędy są obsłużone,
* logi nie zawierają sekretów,
* audit istnieje, jeśli potrzebny,
* dokumentacja jest zaktualizowana,
* migracja i rollback są opisane,
* funkcja działa po restarcie,
* nie łamie backupu,
* przeszła podstawową dostępność,
* działa na telefonie,
* zależności i licencje są zarejestrowane.

***

# 33. Metryki sukcesu MVP

## Użytkowe

* dokument można dodać w kilku prostych krokach,
* większość dokumentów można znaleźć przez search,
* status przetwarzania jest zrozumiały,
* nie trzeba otwierać Paperless UI,
* użytkownik rozumie powiązanie dokumentu z obiektem.

## Techniczne

* brak utraty po restartach,
* retry nie duplikuje,
* restore działa,
* backup jest świeży,
* awaria Paperless nie wyłącza Core,
* krytyczne E2E są stabilne.

## Operacyjne

* aktualizacja ma runbook,
* brak miejsca generuje alert,
* operator zna stan systemu,
* sekrety można rotować.

***

# 34. Ryzyka roadmapy

## Zbyt długa dokumentacja

Ograniczenie: dokumentować decyzje i niejasności, a zachowanie weryfikować prototypem.

## Scope creep

Ograniczenie: deferred list i MVP gate.

## Zachwyt technologią

Ograniczenie: komponent musi mieć use case, właściciela i koszt.

## Brak realnych danych

Ograniczenie: reprezentatywne dokumenty i pilot.

## Brak restore

Ograniczenie: restore jest gate, nie opcją.

## Lock-in Paperless

Ograniczenie: adapter, eksport, contract tests i reconciliation.

***

# 35. Model wydań

```
0.1 engineering foundation 
0.2 Core objects 
0.3 Paperless integration 
0.4 upload and preview 
0.5 search 
0.6 organization and trash 
0.7 reminders 
0.8 backup and security 
0.9 household pilot 
1.0 stable home archive
```

Numery oznaczają zakres, nie termin.

***

# 36. Najbliższe działania

1. Potwierdzić przygotowany rebaseline Compose v3.0.4 na docelowej Linux VM, zapisać digesty właściwe dla jej architektury oraz przygotować bezpieczny `.env` i chronione próbki. Czysty cel, Restic/Borg i dwie kopie klucza są wymagane dopiero przed E3.
2. Wykonać **E1**: test Paperless REST, Gotenberg i porównanie topologii Valkey z pełnym zestawem scenariuszy BullMQ.
3. Traktować **E2 jako zakończony**: obaj kandydaci przeszli bramy, a
   ADR-014 przyjął Prisma ze względu na długoterminowe utrzymanie. Kod
   produktu korzystający z ORM powstaje dopiero w M9.
4. Utworzyć tymczasowy czysty cel i wykonać **E3A** oraz **E3B** osobno dla Restic i Borg.
5. Zapisać siedem trwałych artefaktów i formalnie ocenić Gate OS-1, OS-2-LAB oraz OS-3-LAB.
6. Dopiero po przejściu M3 rozpocząć `10-Conceptual-Data-Model.md` przed bramą M4.
7. Następnie przygotowywać kontrakty w kolejności M4 → M5 → M6 → M7 → M8.

Czego jeszcze nie robić:

* pełnego design systemu,
* aplikacji natywnej,
* Home Assistant,
* kamer,
* AI,
* mikroserwisów,
* Kubernetes,
* publicznego hostingu.

***

# 37. Decyzja końcowa

Pierwszy kod ma odpowiedzieć na jedno pytanie:

> Czy potrafimy bezpiecznie dodać rzeczywisty dokument do obiektu, przetworzyć go lokalnie przez Paperless, zobaczyć podgląd, odnaleźć go po treści i odtworzyć cały system z backupu?

Dopiero pozytywna odpowiedź uzasadnia rozszerzanie produktu.
