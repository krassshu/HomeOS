# Konfiguracja do powtórzenia eksperymentu M3

**Status:** artefakt trwały nr 7 · **Milestone:** M3 · **Data:** 2026-07-31

Zestaw danych potrzebnych do odtworzenia laboratorium M3 od zera i powtórzenia prób przy aktualizacji Paperless (RY-13).

---

## 1. Host

| Parametr | Wartość użyta w M3 |
|---|---|
| System | Debian GNU/Linux 13 (trixie), jądro `6.12.96+deb13-amd64` |
| Architektura | `x86_64` |
| vCPU | `4` |
| RAM | `15 GiB` |
| Dysk | `92 GB`, wolne `78 GB` przed próbami |
| Docker Engine | `29.6.2` |
| Docker Compose | `v5.3.1` |
| containerd | `v2.2.6` |
| Python (host) | `3.13.5` |

Warunek dla prób backupu: **minimum 20 GB wolnego miejsca**. `lab/harness/preflight.sh` przerywa, jeżeli zapas jest mniejszy.

---

## 2. Obrazy — tag i digest

Wszystkie referencje przypięte jednocześnie tagiem i digestem. Żaden obraz nie używa `latest`.

| Usługa | Referencja |
|---|---|
| `webserver` | `ghcr.io/paperless-ngx/paperless-ngx:3.0.4@sha256:3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582` |
| `db`, `core_fixture_db` | `docker.io/library/postgres:18@sha256:3a82e1f56c8f0f5616a11103ac3d47e632c3938698946a7ad26da0df1334744a` |
| `broker` | `docker.io/valkey/valkey:9-alpine@sha256:ee91f7a174ac4d6a6b0685b3a60e321f0a9dbbb691f9b0e285be2ba1d1be8328` |
| `gotenberg` | `docker.io/gotenberg/gotenberg:8.34@sha256:67097317623a503ba2a6a7e9ae8db6929a1f7e1bbd88077bacf2d325fbdab923` |
| `tika` | `docker.io/apache/tika:3.3.1.0@sha256:90b7fa1dc018434075fce9e1d9b88b1e3d0ea6979d0cf86e116c79a8073ae973` |
| harness Node | `docker.io/library/node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d` |

Wersje uruchomieniowe potwierdzone w kontenerach: PostgreSQL `18.4`, Valkey `9.1.1`, Node `24.18.0`, npm `11.16.0`.

---

## 3. Warianty Compose

`lab/m3-lab.sh <source|restore> <shared|split> <akcja>` zawsze składa cztery pliki: baseline, override, target i wariant Valkey.

| Wariant | Projekt | UI | Wolumeny |
|---|---|---|---|
| `source` | `homeos-m3-source` | `127.0.0.1:8000` | prefiks `homeos-m3-source-*` |
| `restore` | `homeos-m3-restore` | `127.0.0.1:8100` | prefiks `homeos-m3-restore-*` |

Potwierdzono, że source i restore **nie współdzielą żadnego wolumenu ani katalogu danych**. Każda konfiguracja deklaruje siedem jednoznacznie nazwanych wolumenów; aktywny wariant `shared` używa sześciu, a `split` dodatkowo używa wolumenu Core Valkey. Część wspólna nazw i bind mountów jest pusta.

Walidacja bez uruchamiania usług:

```sh
./m3-lab.sh source shared config
./m3-lab.sh source split config
./m3-lab.sh restore shared config
./m3-lab.sh restore split config
```

---

## 4. Zmienne środowiskowe

Pliki `.env.source` i `.env.restore` powstają z `.env.example` i `restore.env.example`; są ignorowane przez Git i mają uprawnienia `0600`. Wymagane klucze:

```text
PAPERLESS_DB_PASSWORD
PAPERLESS_SECRET_KEY
CORE_FIXTURE_DB_PASSWORD
PAPERLESS_UI_PORT
VALKEY_SHARED_PORT
VALKEY_CORE_PORT
PAPERLESS_TIME_ZONE
PAPERLESS_OCR_LANGUAGE
PAPERLESS_OCR_LANGUAGES
PAPERLESS_CONSUMER_DELETE_DUPLICATES
```

**Nie ustawiać `PAPERLESS_SEARCH_LANGUAGE`** — jawna wartość zatrzymuje start 3.0.4 błędem `AppRegistryNotReady`.

---

## 5. Narzędzia backupu

| Narzędzie | Pakiet Debiana | Wersja binarna |
|---|---|---|
| Restic | `restic 0.18.0-1+b4` | `restic 0.18.0` |
| BorgBackup | `borgbackup 1.4.0-5` | `borg 1.4.0` |
| — zależność | `python3-msgpack 1.0.3-3+b4` | |
| — zależność | `python3-packaging 25.0-1` | |

Na maszynie bez `sudo` pakiety pobrano przez `apt-get download` i rozpakowano do `lab-data/toolchain/prefix`, z opakowaniami w `lab-data/toolchain/bin`.

**Uwagi wersyjne istotne przy powtórzeniu:**

- Borg 1.4 **nie zna** `BORG_PASSPHRASE_FILE`; hasło podaje się przez `BORG_PASSCOMMAND="cat <plik>"`.
- Borg wymaga `BORG_RELOCATED_REPO_ACCESS_IS_OK=yes` oraz **osobnego `BORG_BASE_DIR`** przy pracy na kopii repozytorium.
- Po `prune` Borg wymaga osobnego `compact`, żeby zwolnić miejsce.
- Restic po zabitym backupie wymaga `restic unlock`.

---

## 6. Katalogi laboratorium

Wszystko poza wersjonowaną częścią repozytorium, w ignorowanym `lab-data/`:

```text
lab-data/m3-source/{export,consume}      dane robocze źródła
lab-data/m3-restore/{export,consume}     dane robocze celu restore
lab-data/fixtures/                       syntetyczne fixture
lab-data/toolchain/{debs,prefix,bin}     restic i borg
lab-data/e3/repositories/{restic,borg}   repozytoria wynikowe
lab-data/e3/restore-staging/             odtworzone zestawy
lab-data/e3/retention-copies/            kopie jednorazowe do prune
lab-data/e3/recovery-copy-{a,b}          materiały odzyskiwania (0600)
lab-data/e3/{export,dr-set,manifest}     eksport E3A, zestaw DR, manifest
lab-data/e3/{sizing,single-file-restore} pomiary i próby narzędziowe
lab-data/e3/results/                     podsumowania prób
```

---

## 7. Kolejność uruchomienia

```sh
# 1. Audyt i preflight
lab/harness/preflight.sh

# 2. Fixture E1 (syntetyczne)
lab/harness/e1/gen-fixtures.sh --out lab-data/fixtures
lab/harness/e1/gen-ocr-fixture.py  # w kontenerze, dla E1-13

# 3. Kontrakt API
lab/harness/e1/api-checks.sh status|version|schema|document|download|search|checksum

# 4. Zachowania awaryjne
lab/harness/e1/ocr-restart-test.sh --file lab-data/fixtures/DOC-13-ocr-restart.pdf
lab/harness/e1/valkey-memory-test.sh
lab/harness/e1-15/run.sh --variant both

# 5. Fixture Core i manifest źródłowy
lab/harness/e3/prepare-storage.sh
lab/harness/e3/build-fixture.sh

# 6. E3A, E3B i próby narzędziowe
lab/harness/e3/e3a.sh
lab/harness/e3/e3b.sh
lab/harness/e3/tool-trials.sh

# 7. Walidacja
lab/harness/e1/validate-results.sh --csv Docs/operations/spike-results/02-resource-measurements.csv
node scripts/validate-docs.mjs
```

Token API nigdy nie jest podawany w argumentach. Źródła w kolejności: `PAPERLESS_API_TOKEN`, `PAPERLESS_TOKEN_FILE` (`0600`), `M3_ALLOW_CONTAINER_TOKEN=1`.

---

## 8. Czego konfiguracja nie obejmuje

- Docelowego storage 4 TB — repozytoria E3 są symulacją na dysku hosta.
- Materiałów odzyskiwania poza serwerem — obie kopie leżą na tym samym urządzeniu.
- Rzeczywistych skanów papieru — cały materiał wejściowy tej rundy jest syntetyczny.
