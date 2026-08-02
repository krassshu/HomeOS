# OS-3-LAB — inwentarz komponentów laboratorium M3

**Status:** wynik eksperymentu · **Milestone:** M3 · **Data:** 2026-07-31

**Podstawa:** `../spike-plan.md` §4 (F1-07) · rozstrzyga [ADR-016](../../adr/ADR-016-polityka-licencyjna.md) w zakresie laboratoryjnym

> **To nie jest porada prawna.** Dokument zapisuje licencje **zadeklarowane przez upstream** dla wersji faktycznie użytych w laboratorium M3, wraz ze sposobem użycia. Nie jest analizą zgodności ani opinią prawną.

---

## 1. Charakter laboratorium

| Cecha | Stan |
|---|---|
| Zastosowanie | prywatne, eksperymentalne, jedna maszyna laboratoryjna |
| Dystrybucja komponentów | **żadna** — nic nie jest przekazywane osobom trzecim |
| Modyfikacja komponentów | **żadna** — wszystkie obrazy i pakiety użyte bez zmian |
| Publiczne udostępnienie usług | brak — wszystkie porty przypięte do `127.0.0.1` |
| Kod własny | jednorazowe skrypty laboratoryjne, nie dystrybuowane |

W obecnym laboratorium nie zidentyfikowano zdarzenia dystrybucji, które wymagałoby realizacji obowiązków związanych z przekazywaniem kopii GPL-3.0. Jest to opis przyjętego modelu użycia, nie ostateczna kwalifikacja prawna. Przekazanie instalatora, obrazów lub kopii komponentów osobom trzecim albo modyfikacja Paperless wymaga ponownej analizy dla konkretnego sposobu dostarczenia.

---

## 2. Inwentarz komponentów

Wszystkie obrazy są przypięte jednocześnie tagiem i digestem. Architektura hosta: `linux/amd64`.

| Komponent | Źródło | Wersja / tag | Digest obrazu | Arch. | Zadeklarowana licencja | Sposób użycia | Modyfikowany | Dystrybuowany | NOTICE / licencja |
|---|---|---|---|---|---|---|---|---|---|
| **Paperless-ngx** | `ghcr.io/paperless-ngx/paperless-ngx` | `3.0.4` | `sha256:3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582` | amd64 | **GPL-3.0** (etykieta `org.opencontainers.image.licenses`) | kontener DMS: API, OCR, exporter/importer, sanity checker | nie | nie | etykieta obrazu; `raw/os3-lab/image-labels.txt` |
| **PostgreSQL** | `docker.io/library/postgres` | `18` (18.4) | `sha256:3a82e1f56c8f0f5616a11103ac3d47e632c3938698946a7ad26da0df1334744a` | amd64 | **PostgreSQL License** (BSD-podobna) | baza Paperless oraz baza `core_fixture` | nie | nie | upstream `COPYRIGHT` w obrazie |
| **Valkey** | `docker.io/valkey/valkey` | `9-alpine` (9.1.1) | `sha256:ee91f7a174ac4d6a6b0685b3a60e321f0a9dbbb691f9b0e285be2ba1d1be8328` | amd64 | **BSD-3-Clause** | broker Paperless; osobna instancja dla harnessu BullMQ; kontener pomocniczy do pakowania wolumenów | nie | nie | upstream `LICENSE` |
| **Gotenberg** | `docker.io/gotenberg/gotenberg` | `8.34` | `sha256:67097317623a503ba2a6a7e9ae8db6929a1f7e1bbd88077bacf2d325fbdab923` | amd64 | **MIT** | konwersja DOCX/XLSX do PDF w potoku Paperless | nie | nie | upstream `LICENSE` |
| **Apache Tika** | `docker.io/apache/tika` | `3.3.1.0` | `sha256:90b7fa1dc018434075fce9e1d9b88b1e3d0ea6979d0cf86e116c79a8073ae973` | amd64 | **Apache-2.0** | wykrywanie typu i ekstrakcja treści dokumentów biurowych | nie | nie | **NOTICE zachowany**: `raw/os3-lab/tika-NOTICE.txt`; licencja: `raw/os3-lab/tika-LICENSE.txt` |
| **Docker Engine** | Debian / upstream Docker | `29.6.2` | nie dotyczy | amd64 | **Apache-2.0** | uruchamianie kontenerów laboratorium | nie | nie | upstream |
| **Docker Compose** | wtyczka CLI | `v5.3.1` | nie dotyczy | amd64 | **Apache-2.0** | składanie wariantów `source`/`restore` × `shared`/`split` | nie | nie | upstream |
| **Node.js** | `docker.io/library/node` | `24.18.0-bookworm-slim` | `sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d` | amd64 | **MIT** (z komponentami o własnych licencjach) | uruchomienie harnessu BullMQ i PoC ORM | nie | nie | `LICENSE` w obrazie |
| **npm** | w obrazie Node.js | `11.16.0` | jak wyżej | amd64 | **Artistic-2.0** | instalacja zależności harnessu | nie | nie | upstream |
| **BullMQ** | npm | `5.81.2` | nie dotyczy | dowolna | **MIT** (`package.json`) | harness kolejki E1-15 | nie | nie | `node_modules/bullmq` |
| **Prisma** | npm | `7.9.1` (`prisma`, `@prisma/client`) | nie dotyczy | dowolna | **Apache-2.0** (`package-lock.json`) | kandydat ORM w E2 | nie | nie | `lab/e2/package-lock.json` |
| **Drizzle** | npm | `drizzle-orm 0.45.2`, `drizzle-kit 0.31.10` | nie dotyczy | dowolna | **Apache-2.0** / **MIT** | kandydat ORM w E2 | nie | nie | `lab/e2/package-lock.json` |
| **Restic** | Debian trixie | pakiet `0.18.0-1+b4` (restic `0.18.0`) | nie dotyczy | amd64 | **BSD-2-Clause** (`copyright`) | kandydat backupu E3A/E3B | nie | nie | `raw/os3-lab/deb-licenses.txt` |
| **BorgBackup** | Debian trixie | pakiet `1.4.0-5` (borg `1.4.0`) | nie dotyczy | amd64 | **BSD-3-Clause** (`copyright`) | kandydat backupu E3A/E3B | nie | nie | `raw/os3-lab/deb-licenses.txt` |

### 2.1. Zależności dociągnięte razem z Borgiem

Borg z repozytorium Debiana wymaga dwóch pakietów Pythona, zainstalowanych do prefiksu użytkownika razem z nim:

| Pakiet | Wersja | Licencja |
|---|---|---|
| `python3-msgpack` | `1.0.3-3+b4` | Apache-2.0 |
| `python3-packaging` | `25.0-1` | Apache-2.0 lub BSD-2-Clause |

### 2.2. Sposób instalacji narzędzi backupu

Na maszynie laboratoryjnej nie było uprawnień `sudo`. Pakiety pobrano z **oficjalnego repozytorium Debiana trixie** poleceniem `apt-get download` i rozpakowano do prefiksu użytkownika (`lab-data/toolchain/prefix`) bez instalacji systemowej. Wersje pakietów są dokładnie takie, jakie dostarcza dystrybucja; nie zmieniano ani nie aktualizowano żadnych niezwiązanych pakietów systemowych.

---

## 3. Ocena dla prywatnego użycia laboratoryjnego

| Pytanie | Odpowiedź |
|---|---|
| Czy któryś komponent ma licencję niedopuszczalną dla prywatnego użycia laboratoryjnego? | **Nie.** Wszystkie deklarują licencje open source: GPL-3.0, Apache-2.0, MIT, BSD-2/3-Clause, PostgreSQL License, Artistic-2.0. |
| Czy któryś komponent został zmodyfikowany? | Nie. |
| Czy cokolwiek zostało dystrybuowane? | Nie. |
| Czy zachowano wymagane NOTICE? | Tak — NOTICE Apache Tika zachowany w wynikach surowych. |
| Czy inwentarz jest kompletny wobec listy z zadania? | Tak — wszystkie 14 wskazanych komponentów ujęte. |

**Wniosek:** dla obecnego, prywatnego i niedystrybucyjnego charakteru laboratorium **nie ma licencji nieakceptowalnej**.

---

## 4. Czego ten inwentarz NIE rozstrzyga

**OS-3-RELEASE pozostaje obowiązkową bramą M22.** Ten dokument dotyczy wyłącznie laboratorium. Przed jakąkolwiek dystrybucją produktu trzeba osobno rozstrzygnąć co najmniej:

1. **GPL-3.0 Paperless-ngx** — konsekwencje przy dystrybucji produktu zawierającego lub zestawiającego ten komponent, w tym pytanie o granicę „mere aggregation” w obrazach i Compose.
2. **Pełne drzewo zależności tranzytywnych** — inwentarz obejmuje komponenty bezpośrednie, nie każdą bibliotekę wewnątrz obrazów i `node_modules`.
3. **Obowiązki atrybucji** dla wszystkich licencji Apache-2.0 i BSD w wydawanym artefakcie.
4. **Zgodność wersji w momencie wydania** — wersje z M3 nie są wersjami wydania.
5. **Licencje czcionek, słowników OCR i modeli** obecnych w obrazie Paperless.

Zmiana charakteru projektu z prywatnego na dystrybuowany unieważnia wniosek z §3 i wymaga pełnej analizy OS-3-RELEASE.

---

## 5. Gate OS-3-LAB

| Kryterium | Status |
|---|---|
| Inwentarz obejmuje wszystkie faktycznie użyte komponenty z listy | ✅ |
| Dla każdego zapisano wersję/tag, digest, architekturę i licencję | ✅ |
| Zapisano sposób użycia, modyfikację i dystrybucję | ✅ |
| Zachowano NOTICE tam, gdzie licencja tego wymaga | ✅ (Tika) |
| Brak licencji nieakceptowalnej dla prywatnego użycia laboratoryjnego | ✅ |
| Zapisano niedystrybucyjny charakter laboratorium | ✅ |
| OS-3-RELEASE pozostaje bramą M22 | ✅ zapisane w §4 |

**Gate OS-3-LAB: przechodzi.**
