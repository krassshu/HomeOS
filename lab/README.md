# Laboratorium M3

Izolowane środowisko eksperymentów E1, E2, E3A i E3B. Nie jest kodem ani konfiguracją produktu.

Odtwarzalne skrypty E1 znajdują się w `harness/e1/` — opis w
[`harness/e1/README.md`](harness/e1/README.md). Obejmują generator syntetycznych
fixture, kontrole kontraktu API, test duplikatów wraz z procedurą rollbacku,
próbę restartu w trakcie OCR, test limitu pamięci izolowanego Valkey oraz
walidator wyników. Harness BullMQ jest w `harness/e1-15/`, a tor E3 —
w `harness/e3/`. **Artefakt nr 4 jest domknięty.**

| Katalog | Zakres |
|---|---|
| `harness/preflight.sh` | audyt hosta, kontenerów, digestów, portów, liczników i czterech wariantów `config` |
| `harness/e1/` | kontrakt API, fixture, duplikaty, E1-13 (restart w trakcie OCR), E1-14 (limit pamięci Valkey), walidator wyników |
| `harness/e1-15/` | pełny harness BullMQ dla wariantu wspólnego i osobnego Valkey |
| `harness/e3/` | materiały odzyskiwania i katalogi storage, fixture Core i manifest, E3A, E3B oraz obowiązkowe próby narzędziowe |

Kolejność uruchamiania i wymagania są opisane w
[`../Docs/operations/spike-results/11-reproduction-config.md`](../Docs/operations/spike-results/11-reproduction-config.md).

PoC ORM E2 znajduje się w `e2/`. Używa istniejącego PostgreSQL jako serwera,
ale tworzy wyłącznie osobne bazy `homeos_e2_*`; nie korzysta z bazy Paperless
ani z danych `core_fixture`.

Konfiguracja używa struktury oficjalnego `docker-compose.postgres-tika.yml` z Paperless-ngx `v3.0.4`. Wszystkie obrazy mają jednocześnie stały tag i digest. Pliki wariantów zapewniają osobne nazwy projektu, wolumeny i katalogi dla środowiska źródłowego oraz celu restore.

Eksperymenty M3 wykonano na laboratoryjnej VM z Debianem 13. Wyniki trwałe są w `../Docs/operations/spike-results/`, a materiały surowe i prywatne pozostają poza Git w `lab-data/` oraz `spike-results/raw/`. Przed powtórzeniem na innym hoście trzeba utworzyć własne sekrety i ponownie przejść warunki zewnętrzne z `../Docs/operations/spike-plan.md`.

## 1. Pliki Compose

| Plik | Rola |
|---|---|
| `compose.baseline.yaml` | struktura oficjalnego wariantu PostgreSQL + Tika dla v3.0.4 i przypięte obrazy |
| `compose.override.yaml` | bezpieczne porty, sekrety z env i nieprodukcyjny fixture Core |
| `compose.source.yaml` | dane, wolumeny i katalogi źródła E1 |
| `compose.restore.yaml` | niezależne dane, wolumeny i katalogi celu E3 |
| `compose.valkey-shared.yaml` | Paperless i harness BullMQ korzystają z jednego Valkey |
| `compose.valkey-split.yaml` | Paperless i harness BullMQ korzystają z różnych instancji Valkey |

`m3-lab.sh` zawsze składa baseline, override, wskazany target i wskazany wariant Valkey. Nie łącz plików `source` i `restore` ani obu wariantów Valkey w jednym poleceniu.

## 2. Sekrety i konfiguracja lokalna

```sh
cp .env.example .env.source
cp restore.env.example .env.restore
```

Zastąp każdą wartość `replace-this` losowym sekretem. Pliki `.env.source` i `.env.restore` są ignorowane przez Git. Nie wpisuj prawdziwych sekretów do plików `*.example`, Compose ani dokumentacji.

Porty domyślne:

| Target | Paperless UI | wspólny Valkey | osobny Valkey BullMQ |
|---|---:|---:|---:|
| source | `127.0.0.1:8000` | `127.0.0.1:16379` | `127.0.0.1:16380` |
| restore | `127.0.0.1:8100` | `127.0.0.1:26379` | `127.0.0.1:26380` |

PostgreSQL, Tika i Gotenberg nie mają portów hosta. Każdy opublikowany port jest przypięty do `127.0.0.1`.

## 3. Walidacja bez uruchamiania usług

Sprawdź wszystkie cztery kombinacje:

```sh
./m3-lab.sh source shared config
./m3-lab.sh source split config
./m3-lab.sh restore shared config
./m3-lab.sh restore split config
```

Wyświetlenie dokładnych referencji obrazów, razem z tagami i digestami:

```sh
./m3-lab.sh source shared images
./m3-lab.sh source split images
```

`versions` jest równoważnym aliasem `images`. Polecenia `config`, `images` i `versions` korzystają z bezpiecznego pliku przykładowego, jeżeli lokalny env jeszcze nie istnieje. Nie uruchamiają ani nie pobierają obrazów.

## 4. Warianty Valkey

Wariant `shared` publikuje na localhost port Valkey używanego przez Paperless. Harness BullMQ łączy się z tym portem i używa własnego prefiksu kluczy.

Wariant `split` pozostawia Valkey Paperless wyłącznie w sieci Compose i tworzy `core_broker` z osobnym wolumenem. Harness BullMQ łączy się z lokalnym portem `VALKEY_CORE_PORT`.

Każdy scenariusz E1-15b trzeba wykonać osobno dla obu wariantów z tym samym obciążeniem i warunkami początkowymi.

## 5. Polecenia operacyjne

Uruchomienie i zatrzymanie wybranego wariantu:

```sh
./m3-lab.sh source shared up
./m3-lab.sh source shared down
```

Eksport źródła, import do celu restore i sanity checker:

```sh
./m3-lab.sh source shared export
./m3-lab.sh restore shared prepare-restore
./m3-lab.sh restore shared import
./m3-lab.sh restore shared sanity
```

`prepare-restore` odmawia pracy, jeżeli katalog restore nie jest pusty albo istnieje którykolwiek nazwany wolumen celu. Nie uruchamia usług.

Pełny reset jest destrukcyjny i wymaga jawnego potwierdzenia dokładnej nazwy targetu:

```sh
M3_CONFIRM_RESET=homeos-m3-source ./m3-lab.sh source shared reset
M3_CONFIRM_RESET=homeos-m3-restore ./m3-lab.sh restore shared reset
```

Nie wykonuj resetu przed zapisaniem wymaganych artefaktów E1/E3.

## 6. Izolacja danych

Źródło używa prefiksu `homeos-m3-source-*` i katalogu `../lab-data/m3-source`. Restore używa prefiksu `homeos-m3-restore-*` i katalogu `../lab-data/m3-restore`. Rozdzielone są:

- dane, media, eksport i consume Paperless,
- PostgreSQL Paperless,
- Valkey Paperless,
- PostgreSQL i assety fixture Core,
- Valkey BullMQ w wariancie `split`,
- sieci i nazwy projektów Compose.

Współdzielone są wyłącznie niezmienne pliki konfiguracji i schemat inicjalizacyjny fixture. Zestaw eksportu przeznaczony do importu należy skopiować kontrolowanie ze źródła do katalogu restore; nie wolno montować wspólnego katalogu danych.

## 7. Zakres fixture Core

`core_fixture_db` tworzy wyłącznie:

- `document_link(external_id, checksum_sha256)`,
- `asset(path, checksum_sha256)`.

To nie jest model produkcyjny. Po utworzeniu dokumentów w E1 wpisz ich external IDs i checksumy do fixture przed E3. Prywatne próbki i wyniki pozostają w ignorowanym katalogu `lab-data/`.

Pierwsza sesja E1 musi potwierdzić wersję `3.0.4`, pobrać OpenAPI z działającej instancji i ponownie sprawdzić REST, konfigurację, OCR, exporter/importer, sanity checker oraz restore. Nie wolno dziedziczyć wyników ani zachowania z serii 2.x.

Nie ustawiaj `PAPERLESS_SEARCH_LANGUAGE` w obrazie 3.0.4. Jawna wartość powoduje podczas startu przedwczesny import modułu wyszukiwania i błąd `AppRegistryNotReady`. Polski OCR pozostaje ustawiony przez `PAPERLESS_OCR_LANGUAGE=pol`; jakość wyszukiwania bez wymuszonego stemmera jest przedmiotem E1, nie założeniem konfiguracji.
