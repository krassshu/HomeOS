# Manifest laboratorium Fazy 1

**Status:** `accepted — specyfikacja baseline` · **Milestone:** M3 · **Data weryfikacji:** 2026-07-28

Manifest określa jedyny baseline M3: **Paperless-ngx 3.0.4** wraz ze strukturą oficjalnego Compose z taga `v3.0.4`. Pliki w `lab/` zostały przebudowane i statycznie zweryfikowane według sekcji 1.1. Nie oznacza to zaliczenia kontroli hosta ani eksperymentów. Zmiana któregokolwiek obrazu wymaga aktualizacji manifestu, konfiguracji laboratorium i macierzy kompatybilności oraz ponowienia odpowiednich testów.

## 1. Źródło Compose

- Projekt: `paperless-ngx/paperless-ngx`
- Wersja M3: `v3.0.4`
- Obraz: `ghcr.io/paperless-ngx/paperless-ngx:3.0.4@sha256:3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582`
- Plik bazowy: `docker/compose/docker-compose.postgres-tika.yml`
- Źródło pliku bazowego: <https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/v3.0.4/docker/compose/docker-compose.postgres-tika.yml>
- Zasada: zachowujemy strukturę i ustawienia oficjalnego pliku v3.0.4; w baseline zmieniamy wyłącznie referencje obrazów na tag + digest, a lokalne różnice pozostają w plikach override i wariantów.

### 1.1. Rebaseline konfiguracji przed E1

Nie wolno zmienić wyłącznie numeru obrazu w starym Compose. Przed pierwszym uruchomieniem:

- [x] zastąp `lab/compose.baseline.yaml` strukturą oficjalnego pliku z taga `v3.0.4`,
- [x] przejrzyj różnice względem scaffoldu 2.x: usługi, wolumeny, zmienne, healthchecks, zależności i polecenia,
- [x] dostosuj override do struktury v3.0.4 i usuń obejścia, które przestały być potrzebne; oficjalny Compose v3.0.4 używa już Valkey,
- [x] przypnij **tag i digest** Paperless oraz pozostałe obrazy z tabeli,
- [x] sprawdź wartości `.env.example` i `docker-compose.env` przeciw dokumentacji v3.0.4; nie przenoś nieznanych zmiennych z 2.x,
- [x] sprawdź cztery rozwinięte warianty Compose i potwierdź brak obrazu z tagiem pływającym,
- [ ] na hoście zapisz digest manifestu właściwego dla architektury i porównaj go z tabelą,
- [ ] po kontroli hosta oznacz zewnętrzny warunek `BASELINE-3.0.4` jako spełniony.

Źródła wersji: [oficjalne wydania Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx/releases) oraz [dokumentacja konfiguracji](https://docs.paperless-ngx.com/configuration/).

## 2. Przypięte obrazy i deklaracje licencji

| Komponent | Tag | Digest manifestu | Deklaracja upstream | Źródło |
|---|---|---|---|---|
| Paperless-ngx | `3.0.4` | `sha256:3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582` | GPL-3.0 | <https://github.com/paperless-ngx/paperless-ngx/blob/v3.0.4/LICENSE> |
| Valkey | `9-alpine` | `sha256:ee91f7a174ac4d6a6b0685b3a60e321f0a9dbbb691f9b0e285be2ba1d1be8328` | BSD-3-Clause | <https://github.com/valkey-io/valkey/blob/9.0/COPYING> |
| PostgreSQL | `18` | `sha256:3a82e1f56c8f0f5616a11103ac3d47e632c3938698946a7ad26da0df1334744a` | PostgreSQL License | <https://www.postgresql.org/about/licence/> |
| Gotenberg | `8.34` | `sha256:67097317623a503ba2a6a7e9ae8db6929a1f7e1bbd88077bacf2d325fbdab923` | MIT | <https://github.com/gotenberg/gotenberg/blob/v8.34.0/LICENSE> |
| Apache Tika | `3.3.1.0` | `sha256:90b7fa1dc018434075fce9e1d9b88b1e3d0ea6979d0cf86e116c79a8073ae973` | Apache-2.0; obraz zawiera komponenty z dodatkowymi notices | <https://github.com/apache/tika/blob/main/LICENSE.txt> |

Digest wieloplatformowy jest źródłem prawdy dla deklaracji Compose. W raporcie E1-01 zapisuje się również digest manifestu właściwego dla architektury hosta. Dla Paperless 3.0.4 zweryfikowano:

- `linux/amd64`: `sha256:d5651511a6e3a5cb5e5c0da1f5024aa296a4051a28d9d743ce832a8eca16b453`,
- `linux/arm64`: `sha256:34f8cd0ed2ca808f47a1b706d3168216a1d95232865689f4a6182e57501adf4a`.

Powyższe wartości są deklaracjami projektów nadrzędnych, a nie zakończoną oceną obrazu kontenera. Gate OS-3-LAB wymaga sprawdzenia etykiet i materiałów licencyjnych faktycznie pobranego obrazu, w tym zależności wbudowanych, oraz zapisania wyniku w raporcie bram. W przypadku Tika należy dodatkowo zachować jego `NOTICE` i listę licencji komponentów dołączonych.

## 2.1. Narzędzia hosta i eksperymentów

Wyniki E1-01 oraz przygotowania E2 i E3A/E3B uzupełniają poniższą tabelę o faktycznie użyte wersje. Puste pole wersji oznacza, że Gate OS-3-LAB nie jest jeszcze zamknięty.

| Narzędzie | Wersja użyta | Deklaracja upstream | Źródło |
|---|---|---|---|
| Docker Engine / Moby | `29.6.2` | Apache-2.0 | <https://github.com/moby/moby/blob/master/LICENSE> |
| Docker Compose | `5.3.1` | Apache-2.0 | <https://github.com/docker/compose/blob/main/LICENSE> |
| Restic | — | BSD-2-Clause | <https://github.com/restic/restic/blob/master/LICENSE> |
| BorgBackup | — | BSD-3-Clause | <https://github.com/borgbackup/borg/blob/master/LICENSE> |
| Node.js (harness i E2) | `24.18.0` · npm `11.16.0` | MIT oraz licencje dołączonych komponentów | <https://github.com/nodejs/node/blob/main/LICENSE> |
| BullMQ (harness) | — | MIT | <https://github.com/taskforcesh/bullmq/blob/master/LICENSE> |
| Drizzle ORM (E2) | `0.45.2` · Drizzle Kit `0.31.10` | Apache-2.0 | <https://github.com/drizzle-team/drizzle-orm/blob/main/LICENSE> |
| Prisma ORM (E2) | CLI `7.9.1` · Client `7.9.1` | Apache-2.0 | <https://github.com/prisma/prisma/blob/main/LICENSE> |

E2 używa jednorazowego kontenera `node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d` dla `linux/amd64`; obraz raportuje Debian 12 Bookworm. W dniu przygotowania laboratorium Node `24.18.1` był bieżącym LTS, ale odpowiadające mu oficjalne tagi Docker `trixie-slim` i `bookworm-slim` nie były jeszcze dostępne. E2 przypina ostatni dostępny obraz LTS i wymaga ponownej kontroli przed późniejszym użyciem poza spike'em.

Wersje ORM odczytano bezpośrednio z rejestru npm przez przypięty kontener Node. E2 używa wyłącznie stabilnego taga Drizzle `latest`, nie linii `1.0.0-rc`, oraz jednakowej wersji CLI i klienta Prisma. Informacja npm o dostępności nowego major release nie jest podstawą aktualizacji npm w trakcie eksperymentu.

## 3. Środowisko

Model laboratorium:

1. jedna stała, izolowana maszyna Linux lub Linux VM z Docker Engine i Compose dla E1 oraz — jeśli wygodnie — E2,
2. tymczasowy czysty cel restore tworzony dopiero dla E3 z nowej VM albo ze zweryfikowanego czystego snapshotu; po każdym kandydacie cel jest usuwany albo cofany do tego samego snapshotu,
3. profil referencyjny 4 vCPU, 16 GB RAM i 100 GB wolnego miejsca służy porównaniu pomiarów, ale **nie jest minimalnym wymaganiem ani bramą startu E1/E2**,
4. brak publicznego wystawienia usług,
5. katalog danych prywatnych poza Git.

Docker Desktop na macOS może służyć do wstępnych prób E1/E2, ale miarodajne pomiary E1 i oba warianty E3 wykonuje się na odtwarzalnym środowisku Linux. Pomiary zapisują model hosta, architekturę, liczbę vCPU, RAM i typ dysku. Jeżeli host ma mniej niż profil referencyjny, nie blokuje to eksperymentu; wynik otrzymuje adnotację i nie może samodzielnie przesądzać o sprzęcie produkcyjnym.

## 4. Konfiguracja wymagana

- `PAPERLESS_OCR_LANGUAGE=pol`
- Tika i Gotenberg włączone przez oficjalny wariant Compose
- unikalny `PAPERLESS_SECRET_KEY`
- hasła baz i token API poza Git
- obrazy uruchamiane po digescie
- czas kontenerów UTC; raport w Europe/Warsaw
- source i restore mają osobne nazwy projektów, wolumeny oraz katalogi danych
- wariant `shared` udostępnia jeden Valkey Paperless i BullMQ, a wariant `split` tworzy osobny `core_broker`

W 3.0.4 nie ustawiamy jawnie `PAPERLESS_SEARCH_LANGUAGE`: inicjalizacja tej opcji importuje moduł wyszukiwania przed gotowością rejestru aplikacji Django i zatrzymuje migracje błędem `AppRegistryNotReady`. Jest to zweryfikowana niezgodność runtime 3.0.4, nie założenie odziedziczone z 2.x. E1 ma ocenić wyszukiwanie polskich treści przy `PAPERLESS_OCR_LANGUAGE=pol` bez wymuszonego stemmera.

## 5. Stan gotowości zewnętrznej według eksperymentu

### E1 — blokuje pierwszy upload

- [ ] kontrola hosta dla `BASELINE-3.0.4` z §1.1 jest wykonana
- [ ] Docker Engine działa na wybranej maszynie
- [ ] prywatny zestaw `DOC-01`…`DOC-10` jest skompletowany
- [ ] bezpieczny `.env`, sekret aplikacji, hasło bazy, konto administratora i token API są poza Git
- [ ] wersje Docker Engine/Compose i faktyczne digesty obrazów są zapisane

### E2 — blokuje porównanie ORM

- [x] zapisane wersje Node.js, PostgreSQL, Drizzle i Prisma
- [x] oba PoC używają tego samego schematu, danych i asercji

E2 zakończono 2026-07-30 na VM `linux/amd64`. Obaj kandydaci przeszli
E2-01…E2-07 i restore. ADR-014 przyjął Prisma ze względu na długoterminowy
profil utrzymania; techniczny wynik Drizzle pozostaje zapisany w raporcie.

### E3A/E3B — blokuje pierwszy backup i restore

- [ ] źródło zawiera dane E1 oraz fixture Core z manifestem checksum
- [ ] można utworzyć tymczasowy czysty cel Linux, niezależny od wolumenów źródła
- [ ] Restic i Borg są dostępne w zapisanych wersjach
- [ ] dla każdego kandydata wybrano realny docelowy storage lub udokumentowany odpowiednik laboratoryjny
- [ ] dwie kopie testowych materiałów odzyskiwania są zapisane poza repozytorium backupu
- [ ] inwentarz OS-3-LAB obejmuje faktycznie użyte artefakty

Nie wolno zmieniać tych pól na `[x]` na podstawie deklaracji. Każde wymaga empirycznej kontroli opisanej w `spike-plan.md`.
