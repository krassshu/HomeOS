# 05 — Open Source Architecture

## Katalog, ocena i zasady wykorzystania komponentów zewnętrznych

**Wersja:** 0.5

**Status:** `accepted`

**Data weryfikacji:** 2026-07-27

**Zakres:** pierwsza wersja domowego segregatora

**Zależności:** Core Domain Model, Object Model, Technology Architecture, Deployment and Infrastructure

> ## Status dokumentu
>
> | Pole | Wartosc |
> |---|---|
> | **Status** | `accepted` |
> | **Priorytet w hierarchii zrodel prawdy** | **Trzeci z 7 - nadrzedny** |
> | **Obowiazuje w zakresie** | **wszystko** - stos technologiczny, komponenty open source, tiering, wlasciciele danych, porty integracyjne, licencje, proces przyjecia komponentu, bramy Gate OS-1..OS-4 |
> | **Nie obowiazuje w zakresie** | - (brak wyjatkow) |
> | **Ostatni przeglad** | 2026-07-27 (Faza 0 / M0) |
> | **Rejestr rozbieznosci** | [`discrepancy-register.md`](../architecture/discrepancy-register.md) |
>
> Hierarchia zrodel prawdy: **07 dla kolejnosci, 08 dla zakresu, accepted ADR dla decyzji szczegolowych, nastepnie 06 > 05 > 04 > 03 > 02 > 01**.
> Pelne uzasadnienie: [`00-Analiza-i-Mapa-Realizacji.md`](../00-Analiza-i-Mapa-Realizacji.md), sekcja 8.


***

# 1. Cel dokumentu

Dokument definiuje, które projekty open source stają się elementami rozwiązania, za co odpowiadają, gdzie kończy się ich odpowiedzialność oraz jak zachować możliwość późniejszej wymiany komponentu.

Ma zapobiec dwóm błędom:

1. przepisywaniu dojrzałych funkcji,
2. zbudowaniu produktu jako zbioru cudzych paneli.

Użytkownik korzysta z jednej aplikacji. Komponenty zewnętrzne są silnikami ukrytymi za adapterami Core.

***

# 2. Zasady nadrzędne

## 2.1. Open source nie oznacza „bez kosztu”

Każdy komponent kosztuje czas wdrożenia, zasoby serwera, aktualizacje, backup, monitoring, analizę podatności, testy regresji i wiedzę operacyjną. Dodajemy go tylko wtedy, gdy oszczędza więcej pracy, niż generuje.

## 2.2. Kryteria przyjęcia

Komponent musi być:

* faktycznie open source,
* możliwy do uruchomienia lokalnie,
* pozbawiony obowiązkowej zależności od chmury,
* aktywnie utrzymywany,
* wyposażony w stabilny interfejs,
* możliwy do przypięcia do wersji,
* możliwy do backupu i odtworzenia,
* akceptowalny licencyjnie,
* wymienny przez adapter.

## 2.3. Jedna funkcja — jeden właściciel

Nie uruchamiamy równoległych pipeline’ów wykonujących to samo.

* Paperless generuje miniaturę — Core nie generuje drugiej bez potrzeby.
* Paperless wykonuje OCR — Core nie uruchamia osobnego OCR.
* Gotenberg konwertuje Office — NestJS nie steruje równolegle LibreOffice CLI.
* PostgreSQL wystarcza do wyszukiwania Core — nie dodajemy osobnego silnika.

## 2.4. Integracja przez porty

Core korzysta z interfejsów:

```
DocumentProvider 
QueueProvider 
ObjectStorageProvider 
SearchProvider 
PdfConversionProvider 
MalwareScanner 
NotificationProvider 
BackupProvider 
IdentityProvider
```

## 2.5. Panele pomocnicze nie są produktem

Paperless, Bull Board, Grafana, Gotenberg i bazy nie są publiczną częścią systemu. Dostęp administracyjny odbywa się lokalnie albo przez VPN.

***

# 3. Klasyfikacja komponentów

## Tier 0 — platforma uruchomieniowa

Linux, Docker Engine, Docker Compose.

## Tier 1 — krytyczne źródła prawdy

PostgreSQL Core oraz Paperless-ngx z jego bazą i media storage.

## Tier 2 — usługi wykonawcze

Valkey, BullMQ, workery, Gotenberg.

## Tier 3 — prezentacja i dostęp

Next.js, Caddy, PDF.js.

## Tier 4 — operacje

Restic/Borg, Prometheus, Grafana, Loki, ClamAV, WireGuard.

***

# 4. Macierz rekomendacji

|                |                                   |                       |                      |
| -------------- | --------------------------------- | --------------------- | -------------------- |
| Host           | Debian Stable / Ubuntu Server LTS | system operacyjny     | wymagany             |
| Runtime        | Docker Engine                     | kontenery             | wymagany             |
| Orkiestracja   | Docker Compose                    | jedna maszyna         | wymagany             |
| Gateway        | Caddy                             | TLS i routing         | wymagany             |
| Web            | Next.js                           | UI i PWA              | wymagany             |
| API            | NestJS                            | domena i orkiestracja | wymagany             |
| Core DB        | PostgreSQL                        | źródło prawdy Core    | wymagany             |
| DMS/OCR        | Paperless-ngx                     | dokumenty i OCR       | wymagany             |
| Broker         | Valkey                            | backend kolejki       | wymagany             |
| Queue          | BullMQ                            | zadania Core          | wymagany             |
| Konwersja      | Gotenberg                         | Office/HTML/PDF       | zależnie od formatów |
| Viewer         | PDF.js                            | podgląd PDF           | wymagany             |
| Antywirus      | ClamAV                            | skan uploadu          | po MVP               |
| Backup         | Restic lub Borg                   | szyfrowany backup     | wymagany             |
| VPN            | WireGuard                         | jedyny zdalny dostęp  | wymagany kontrakt; aktywacja instalacji opcjonalna |
| Metryki        | Prometheus                        | monitoring            | później              |
| Dashboard      | Grafana                           | wizualizacja          | później              |
| Logi           | Loki                              | centralizacja         | później              |
| Object storage | MinIO                             | S3 local              | odłożony             |
| Search engine  | Meilisearch/OpenSearch            | zaawansowany search   | odłożony             |
| IdP            | Authentik/Keycloak                | SSO/MFA               | odłożony             |

***

# 5. Paperless-ngx

## 5.1. Rola

Paperless-ngx jest wewnętrznym silnikiem dokumentów. Odpowiada za:

* przyjęcie dokumentu,
* zachowanie oryginału,
* archiwalną kopię PDF,
* OCR i ekstrakcję tekstu,
* miniatury,
* indeks treści,
* techniczne metadane,
* tagi, korespondentów i typy dokumentów,
* eksport/import przez oficjalne narzędzia administracyjne,
* REST API dla operacji aplikacyjnych.

## 5.2. Dlaczego pasuje

* self-hosted,
* aktywnie rozwijany,
* wspiera Docker Compose,
* posiada REST API,
* rozwiązuje najdroższy fragment segregatora,
* nie wymaga chmury.

## 5.3. Czego nie oddajemy Paperless

* Workspace,
* kont produktu,
* osób i obiektów,
* relacji domenowych,
* prywatności całej platformy,
* przypomnień,
* nawigacji,
* globalnego systemu tagów,
* przyszłych integracji domu.

## 5.4. Granica integracji

```
Core Document Module 
↓ DocumentProvider 
↓ PaperlessAdapter 
↓ Paperless REST API
```

Zakazane są bezpośrednie zapytania do bazy, ręczne modyfikacje media storage, token w przeglądarce oraz publiczne wystawienie UI Paperless.

Eksport/import instancji nie należy do portu `DocumentProvider`. Operator używa oficjalnych poleceń administracyjnych zgodnie z ADR-019; Core ich nie uruchamia.

## 5.5. Korzyści

* dojrzały OCR,
* szybszy MVP,
* mniej własnego kodu,
* wyszukiwanie treści,
* obsługa wielu formatów,
* eksport danych.

## 5.6. Ryzyka

* druga baza i storage,
* synchronizacja dwóch modeli,
* zmiany API,
* zasoby OCR,
* licencja GPLv3,
* konieczność testów kontraktowych,
* konieczność kontrolowanych aktualizacji.

## 5.7. Strategia wyjścia

* regularny eksport,
* external ID w Core,
* projekcja kluczowych metadanych,
* checksumy,
* adapter,
* brak dostępu do prywatnych tabel,
* próbny eksport i import,
* jawne mapowanie tagów i typów.

## 5.8. Alternatywy

### Mayan EDMS

Bardziej rozbudowany workflow, ale większy koszt operacyjny.

### Docspell / Teedy

Wymagają osobnego porównania API, OCR, aktywności i eksportu.

### Własny pipeline

Największa kontrola, ale najwyższy koszt i sprzeczność z filozofią projektu.

### Decyzja

Paperless-ngx jest preferowany dla MVP po przejściu proof of concept API, backupu i restore.

***

# 6. PostgreSQL

PostgreSQL Core przechowuje całą domenę aplikacji. Paperless korzysta z oddzielnej bazy.

Zalety:

* ACID,
* JSONB,
* FTS,
* `pg_trgm`,
* indeksy GIN,
* dojrzały backup,
* szerokie wsparcie.

Ryzyka:

* niekontrolowany JSONB,
* złe indeksy,
* ciężkie migracje,
* brak testów restore.

SQLite jest zbyt ograniczony dla docelowego systemu wieloużytkownikowego. MySQL/MariaDB nie dają tu istotnej przewagi.

***

# 7. Valkey

Valkey jest otwartym, BSD-licensed serwerem zgodnym z protokołem Redis. Jest preferowany zamiast współczesnego Redis przy założeniu pełnego open source i potencjalnej przyszłej dystrybucji.

Rola:

* backend kolejki Paperless,
* backend BullMQ,
* krótkotrwałe blokady,
* rate limiting,
* cache niewrażliwych danych.

Nie przechowuje jedynej kopii obiektów, audytu, dokumentów ani krytycznego statusu.

## 7.1. Topologia

Wariant prosty:

* jedna instancja,
* osobne prefixy i namespace.

Wariant bezpieczniejszy:

* Valkey dla Paperless,
* osobny Valkey dla Core BullMQ.

Oddzielenie zwiększa RAM, ale ogranicza wpływ awarii. Decyzja po pomiarze.

***

# 8. BullMQ

BullMQ zarządza zadaniami Core:

* ingestion,
* reconciliation,
* eksport,
* cleanup,
* powiadomienia,
* przyszłe integracje.

Wymagane wzorce:

* idempotency,
* retry z backoff,
* timeout,
* limit współbieżności,
* failed state,
* deduplication,
* correlation ID,
* graceful shutdown.

BullMQ OSS jest MIT. Funkcje BullMQ Pro nie mogą stać się ukrytą zależnością architektury bez osobnej decyzji.

Alternatywy:

* RabbitMQ — lepszy przy złożonym routingu, ale cięższy operacyjnie,
* kolejka w PostgreSQL — mniej usług, ale słabszy ekosystem,
* Temporal — zbyt ciężki dla MVP.

Decyzja: BullMQ + Valkey.

***

# 9. Gotenberg

Rola:

* Office → PDF,
* HTML → PDF,
* PDF/A,
* merge/split,
* wybrane operacje PDF.

Przewaga nad bezpośrednim LibreOffice CLI:

* HTTP API,
* izolacja procesów,
* gotowy kontener,
* timeouty,
* zawarte LibreOffice i Chromium.

Ryzyka:

* CPU/RAM,
* niezaufane dokumenty,
* różnice renderowania,
* timeouty,
* brakujące fonty.

Decyzja: używać w pipeline wspieranym przez Paperless; nie wystawiać publicznie.

***

# 10. PDF.js

PDF.js odpowiada za podgląd PDF w interfejsie.

Zasady:

* plik pobierany przez Core,
* autoryzacja przed streamem,
* brak URL Paperless,
* lokalny worker PDF.js,
* przypięta wersja,
* test dużych i zaszyfrowanych PDF,
* cache zgodny z prywatnością.

Alternatywa — natywny viewer przeglądarki — jest prostsza, ale daje mniej spójny UX.

Decyzja: PDF.js, Apache 2.0.

***

# 11. Caddy

Rola:

* jedyny reverse proxy,
* TLS,
* routing,
* limity,
* nagłówki bezpieczeństwa.

Zalety:

* prosta konfiguracja,
* HTTPS by default,
* Apache 2.0,
* mały koszt utrzymania.

Ryzyka:

* błędna konfiguracja proxy,
* token DNS,
* plugin DNS może wymagać własnego builda.

Alternatywy:

* Traefik — wygodny dynamicznie, ale labels mogą przypadkowo wystawić usługę,
* Nginx — dojrzały, lecz bardziej ręczny.

Decyzja: Caddy z jawnymi trasami.

***

# 12. Docker Engine i Compose

Rola:

* izolacja zależności,
* powtarzalny deployment,
* sieci wewnętrzne,
* wolumeny,
* healthchecks,
* sekrety per service.

Zasady:

* brak Docker socketu w kontenerach aplikacji,
* brak `latest`,
* pinowanie tagu i digestu,
* Compose w repozytorium,
* dane poza repozytorium,
* `no-new-privileges`,
* brak privileged,
* jawne sieci i porty.

***

# 13. Next.js

Rola:

* UI,
* PWA,
* dashboard,
* formularze,
* wyszukiwarka,
* viewer.

Granice:

* brak domeny w Route Handlers,
* brak Paperless API,
* brak dostępu do DB,
* brak sekretów.

Ryzyka:

* nadmiar zależności,
* niejasne granice server/client,
* błędny cache danych prywatnych.

***

# 14. NestJS

Rola:

* Core API,
* auth,
* domena,
* adaptery,
* audit,
* agregacja wyszukiwania,
* produkcja jobów.

Ryzyka:

* zbyt duży monolit,
* framework coupling,
* blokowanie event loop przez CPU,
* mieszanie encji ORM z domeną.

Zasada: domena i porty możliwie niezależne od frameworka.

***

# 15. ClamAV

Status: opcjonalny po pionowym MVP.

Pipeline:

* skan w kwarantannie,
* infected → zatrzymanie,
* audit,
* ręczna procedura administratora.

Ryzyka:

* RAM,
* aktualizacje sygnatur,
* false positives,
* brak pełnej gwarancji wykrycia.

Skan nie zastępuje izolacji parserów.

***

# 16. Backup: Restic, Borg i Kopia

Kryteria:

* szyfrowanie,
* deduplikacja,
* retencja,
* integrity check,
* restore pojedynczego pliku,
* pełny restore,
* obsługa docelowego storage.

## Restic

Prosty, szyfrowany, wiele backendów.

## Borg

Bardzo dojrzały, mocny dla lokalnego/SSH repozytorium.

## Kopia

Dobre policy i wiele backendów.

Decyzja: wykonać proof of concept Restic i Borg, wybrać na podstawie pełnego restore.

***

# 17. Monitoring

Prometheus, Grafana i Loki nie są potrzebne do pierwszego uploadu.

Najpierw:

* health endpoint,
* structured logs,
* alert miejsca,
* alert backupu,
* stan kolejki.

Pełny stack po wejściu realnych danych.

***

# 18. MinIO

MinIO daje S3-compatible storage, lecz na MVP dodaje kolejną usługę, backup i aktualizacje.

Decyzja:

* zdefiniować `ObjectStorageProvider`,
* użyć lokalnego filesystemu,
* MinIO dopiero po realnej potrzebie.

***

# 19. Meilisearch i OpenSearch

Meilisearch jest prostszy i dobry do typo tolerance. OpenSearch jest bardzo rozbudowany, ale ciężki operacyjnie.

Decyzja:

* Core: PostgreSQL FTS,
* dokumenty: Paperless search,
* osobny silnik tylko po mierzalnym problemie.

***

# 20. Authentik i Keycloak

Zalety:

* OIDC,
* SSO,
* MFA,
* sesje.

Wady:

* kolejna usługa krytyczna,
* złożony recovery,
* większy onboarding.

Decyzja: własny auth MVP i port `IdentityProvider`.

***

# 21. WireGuard, Tailscale i Headscale

WireGuard daje pełną kontrolę i jest preferowany.

Tailscale jest łatwiejszy przez NAT, ale standardowo zależy od zewnętrznego control plane.

Headscale jest self-hosted, lecz dodaje utrzymanie.

Decyzja: LAN najpierw. Samodzielny WireGuard jest jedyną drogą dostępu
zdalnego; aktywacja może zostać pominięta, lecz nie powstaje alternatywny
publiczny endpoint ani zewnętrzny relay. MVP używa klienta ręcznego, a
późniejsza aplikacja natywna osadza WireGuard zgodnie z ADR-020.

***

# 22. Komponenty odłożone

* Kubernetes,
* Kafka,
* Temporal,
* OpenSearch,
* MinIO,
* Keycloak,
* RabbitMQ,
* service mesh,
* event sourcing framework,
* własny OCR,
* osobny Tika/Poppler/ImageMagick bez konkretnego use case,
* AI.

Każdy wymaga nowego ADR.

***

# 23. Licencje

## Kategorie

* MIT/BSD/Apache 2.0 — permissive,
* GPLv3 — copyleft,
* source-available — nie jest automatycznie open source.

Dla każdego obrazu i pakietu zapisujemy:

```
name 
version 
source 
license 
digest 
usage 
modified? 
distributed? 
notice 
requirement 
replacement
```

Artefakty:

* `THIRD_PARTY_NOTICES.md`,
* SBOM CycloneDX lub SPDX,
* license scan,
* lista wyjątków,
* ADR licencyjny.

Paperless-ngx jest GPLv3. Prywatne użycie lokalne jest prostsze, ale przyszła dystrybucja lub modyfikacja wymaga formalnego przeglądu prawnego. Ten dokument nie jest poradą prawną.

***

# 24. Proces przyjęcia nowego komponentu

1. Opisz brak biznesowy.
2. Sprawdź, czy obecny komponent go nie realizuje.
3. Zidentyfikuj alternatywy.
4. Zweryfikuj oficjalną dokumentację.
5. Zweryfikuj licencję.
6. Oceń aktywność projektu.
7. Oceń API i eksport.
8. Uruchom proof of concept.
9. Przetestuj awarię.
10. Przetestuj backup/restore.
11. Zmierz CPU/RAM/dysk.
12. Napisz adapter.
13. Dodaj contract test.
14. Napisz ADR.
15. Dodaj do SBOM i notices.
16. Dopiero wtedy produkcja.

***

# 25. Scorecard

Skala 0–5:

| Kryterium                | Waga |
| ------------------------ | ---- |
| Dopasowanie funkcjonalne | 5    |
| Self-hosting             | 5    |
| Otwartość licencji       | 5    |
| Stabilność API           | 5    |
| Eksport danych           | 5    |
| Aktywność projektu       | 4    |
| Bezpieczeństwo           | 5    |
| Koszt zasobów            | 3    |
| Koszt operacyjny         | 5    |
| Wymienność               | 4    |
| Dokumentacja             | 4    |

Brak eksportu, backupu lub akceptowalnej licencji dyskwalifikuje komponent niezależnie od sumy.

***

# 26. Polityka aktualizacji

* brak `latest`,
* konkretny tag,
* preferowany digest,
* release notes,
* staging,
* contract tests,
* backup,
* smoke tests,
* kontrolowany rollback,
* aktualizacja SBOM i notices.

Aktualizacja Tier 1 jest zmianą systemową, nie rutynowym restartem.

***

# 27. Polityka forkowania

Fork jest ostatecznością.

Dopuszczalny, gdy:

* istnieje krytyczna potrzeba,
* jest właściciel utrzymania,
* koszt jest zaakceptowany,
* publikacja jest zgodna z licencją,
* istnieje plan synchronizacji upstream.

***

# 28. Właściciele danych

| Dane                  | Właściciel    |
| --------------------- | ------------- |
| Workspace             | Core          |
| Account               | Core          |
| Object                | Core          |
| Relation              | Core          |
| Reminder              | Core          |
| Document context      | Core          |
| Document binary       | Paperless     |
| OCR text              | Paperless     |
| Thumbnail             | Paperless     |
| Audit                 | Core          |
| Job ephemeral state   | BullMQ/Valkey |
| Core search           | Core          |
| Document search index | Paperless     |

***

# 29. Bramy decyzyjne

## Gate OS-1 — Paperless API

Operacje blokujące przez REST:

* upload,
* task status,
* metadata,
* original,
* preview/archive,
* search,
* delete.

Operacje z obowiązkowym fallbackiem:

* thumbnail,
* update mapped metadata,
* health.

Eksport/import jest oddzielną, blokującą próbą interfejsu utrzymaniowego z ADR-019, a nie częścią Gate OS-1 REST.

## Gate OS-2-LAB — Restore Fazy 1

* **E3A:** pełny eksport 3.0.4 został odtworzony i zaimportowany do pustej instancji 3.0.4 z tym samym digestem; nowy token, sanity checker, otwieranie dokumentów i OCR search działają,
* **E3B:** na czystym celu z Paperless 3.0.4 i tym samym digestem odtworzono dump Paperless DB, laboratoryjną Core DB, media, assety i konfigurację,
* po E3B sanity checker i reconciliation przechodzą, a fixture external IDs i checksumy są spójne,
* oba tory wykonano dla Restic i Borg; wybrane narzędzie przeszło wszystkie kryteria blokujące.

Pełny Gate OS-2 produktu jest powtarzany w M17 z logowaniem, relacjami i całym Core.

## Gate OS-3 — Licencje

Brama ma dwa poziomy adekwatne do etapu projektu:

### Gate OS-3-LAB — M3

* wersjonowany inwentarz obrazów i narzędzi laboratorium,
* dla każdej pozycji: źródło, wersja lub digest i deklarowana licencja,
* GPLv3 Paperless oraz prywatny, lokalny model użycia są jawnie zapisane,
* brak licencji niezaakceptowanej dla planowanego użycia laboratoryjnego.

### Gate OS-3-RELEASE — M22

* aktualny SBOM kompletnego produktu,
* `THIRD_PARTY_NOTICES.md` i wymagane teksty licencji,
* brak niezaakceptowanych zależności bezpośrednich i przechodnich,
* GPL i inne zobowiązania udokumentowane dla faktycznego sposobu dostarczenia,
* wynik skanowania licencji zweryfikowany przez człowieka,
* formalny przegląd przed dystrybucją, publikacją zmodyfikowanych obrazów lub monetyzacją.

Samo użycie API jest granicą techniczną, nie automatyczną gwarancją oceny prawnej. Szczegóły: ADR-016.

## Gate OS-4 — Wymienność

* port,
* brak DB access,
* contract tests,
* próbny eksport.

***

# 30. Rekomendowany zestaw MVP

```
Debian/Ubuntu 
Docker Engine + Compose 
Caddy 
Next.js 
NestJS API + Worker 
PostgreSQL Core 
Paperless-ngx + PostgreSQL 
Valkey 
BullMQ 
Gotenberg 
PDF.js 
Restic lub Borg 
WireGuard — wymagany kontrakt dostępu zdalnego; aktywacja instalacji opcjonalna
```

***

# 31. Oficjalne źródła

Zweryfikowane 2026-07-27:

* https://docs.paperless-ngx.com/
* https://docs.paperless-ngx.com/api/
* https://docs.paperless-ngx.com/setup/
* https://docs.paperless-ngx.com/faq/
* https://github.com/paperless-ngx/paperless-ngx/blob/dev/LICENSE
* https://gotenberg.dev/docs/getting-started/introduction
* https://gotenberg.dev/docs/convert-with-libreoffice/convert-to-pdf
* https://valkey.io/
* https://valkey.io/topics/license/
* https://docs.bullmq.io/
* https://github.com/taskforcesh/bullmq
* https://github.com/caddyserver/caddy
* https://mozilla.github.io/pdf.js/
* https://docs.docker.com/compose/
* https://docs.docker.com/compose/how-tos/networking/
* https://docs.docker.com/compose/how-tos/use-secrets/
* https://docs.nestjs.com/techniques/queues
* https://www.postgresql.org/docs/current/textsearch.html

***

# 32. Decyzja końcowa

Open source jest warstwą wykonawczą produktu, nie jego domeną.

Własna wartość powstaje w modelu domu, relacjach, kontekście, UX, uprawnieniach, wyszukiwaniu i procesach.

Ochronę przed lock-in zapewniają:

* jasny właściciel danych,
* porty i adaptery,
* oficjalne API,
* eksport,
* contract tests,
* backup,
* strategia wyjścia.
