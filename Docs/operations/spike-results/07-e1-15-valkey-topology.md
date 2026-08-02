# E1-13, E1-14, E1-15 — odporność przetwarzania i topologia Valkey

**Status:** wynik eksperymentu · **Milestone:** M3 · **Data:** 2026-07-31

**Podstawa:** `../spike-plan.md` §1.5 · rozstrzyga uzupełnienie [ADR-008](../../adr/ADR-008-valkey-bullmq.md)

**Środowisko:** Debian 13, 4 vCPU, 15 GiB RAM, Docker 29.6.2, Compose v5.3.1, projekt `homeos-m3-source`, Paperless-ngx `3.0.4@sha256:3838b9a4…e57582`, Valkey `9.1.1` z obrazu `valkey/valkey:9-alpine@sha256:ee91f7a1…be8328`.

Wyniki surowe: `raw/e1-13/`, `raw/e1-13-run2/`, `raw/e1-14/`, `raw/e1-15/`.

---

## 1. E1-13 — restart Paperless w trakcie OCR

**Wynik: FAIL.** Kryterium z planu brzmi „dokument nie ginie; przetwarzanie wznawia się lub kończy czytelnym błędem”. Żaden z dwóch warunków nie został spełniony.

### 1.1. Przebieg

Materiał: syntetyczny, dwudziestostronicowy PDF rastrowy bez warstwy tekstowej, `5 032 237 B`, `sha256:9fbfbf30…2421f`, generator `lab/harness/e1/gen-ocr-fixture.py`. **To nie jest skan rzeczywistej kartki.**

| Krok | Przebieg 1 | Przebieg 2 |
|---|---|---|
| upload przez API | `HTTP 200`, UUID zadania zwrócony | `HTTP 200`, UUID zadania zwrócony |
| potwierdzony stan `started` | tak, < 1 s od uploadu | tak, < 1 s od uploadu |
| procesy workera przed restartem | — | `6` (m.in. `celery MainProcess`, `ForkPoolWorker`, `document_consumer`) |
| odtworzenie wyłącznie `webserver` | wykonane | wykonane |
| **czas niedostępności API** | pomiar nieważny (błąd harnessu) | **26 s** |
| **czas do `healthy`** | pomiar nieważny | **44 s** |
| status tego samego UUID po restarcie | `started` | `started` |
| stan po 15 min | nadal `started` | nadal `started` |
| dokument utworzony | **nie** | **nie** |

### 1.2. Co się faktycznie stało

Po odtworzeniu kontenera rekord zadania pozostaje w API w stanie **nieterminalnym `started`**, z ustawionym `date_started`, `date_done = null` i pustym `related_document_ids`. Katalogi `consume` i scratch w kontenerze są puste — przesłany plik nie istnieje już nigdzie w instancji. Liczba dokumentów nie zmieniła się (`9 → 9`), kosz bez zmian (`1`), sanity checker: `No issues detected`.

Zachowanie powtórzyło się identycznie w dwóch niezależnych przebiegach.

### 1.3. Ocena

| Kryterium | Wynik |
|---|---|
| dokument nie ginie | **FAIL** — przesłany plik przepadł |
| przetwarzanie wznawia się | **FAIL** — brak ponowienia |
| kończy się czytelnym błędem | **FAIL** — zadanie zostaje w stanie `started` bez końca |
| nie powstał duplikat | PASS |
| wcześniejsze dokumenty nietknięte | PASS |
| sanity checker po próbie | PASS |
| źródło wraca do stanu zdrowego | PASS |

Stan `started` bez terminacji jest **gorszy niż czytelny błąd**: klient nie ma sygnału, że praca przepadła, i odpytując status może czekać w nieskończoność.

### 1.4. Konsekwencje projektowe

To najważniejszy wynik funkcjonalny tej rundy. Wpływa na M4, M6 i M11:

1. **Core nie może traktować `task_id` Paperless jako trwałej gwarancji.** Zadanie zniknięte razem z workerem zostawia rekord, który nigdy nie osiągnie stanu końcowego.
2. **Potrzebny jest własny timeout na zadanie po stronie Core** — zadanie w stanie nieterminalnym dłużej niż próg musi być uznane za utracone i zgłoszone operatorowi.
3. **Reconciliation musi wykrywać intencje bez skutku**, a nie tylko joby bez intencji. Dokładnie ten mechanizm potwierdza E1-15b-F.
4. **Potok ingestion Core musi zachować plik w szyfrowanej kwarantannie do terminalnego potwierdzenia**, że Paperless utworzył dokument. Jest to tymczasowy staging przewidziany już w `06-System-Workflows.md` §11.3–§11.7, a nie druga trwała kopia ani zmiana właściciela z ADR-006. Po sukcesie plik jest usuwany; po timeoutach trafia do kontrolowanego retry lub manual review. Dokładne limity, retencję i zachowanie przy długiej niedostępności rozstrzygnie ADR wymagany przez G4-06.
5. **Runbook aktualizacji Paperless musi wymuszać drenaż kolejki** przed restartem: zatrzymanie przyjmowania nowych plików, odczekanie na zakończenie zadań, dopiero potem restart.

Test należy powtórzyć na rzeczywistym skanie oraz po każdej aktualizacji Paperless (RY-13).

---

## 2. E1-14 — limit pamięci Valkey

**Wynik: PASS.** Wykonane na **izolowanym** brokerze z tym samym przypiętym obrazem, w sieci `none`, bez publikowanych portów i bez dostępu do wolumenu źródła. Broker źródła nie był modyfikowany; po próbie potwierdzono, że nie ma narzuconego limitu (`maxmemory=0`).

| Pomiar | Wartość |
|---|---|
| ustawiony `maxmemory` | `3 145 728 B` (3 MiB) |
| domyślna `maxmemory-policy` | **`noeviction`** |
| zapisów przyjętych przed limitem | `24` (payload 64 KiB) |
| komunikat błędu | `OOM command not allowed when used memory > 'maxmemory'.` |
| `evicted_keys` przy `noeviction` | `0` |
| znacznik kontrolny po limicie | nienaruszony |
| liczba kluczy vs potwierdzone zapisy | zgodna (`25` = 24 + znacznik) |
| odczyt po odmowie zapisu | działa, wartość pełna (`65 537 B`) |

### 2.1. Kontrast: polityka eksmisji

Po przełączeniu tej samej izolowanej instancji na `allkeys-lru` i ponownym zapełnieniu: **`evicted_keys=51`, a znacznik kontrolny został usunięty** — bez żadnego błędu.

To jest dowód, dlaczego broker kolejki nie może pracować na polityce eksmisji: zadania znikają cicho. `noeviction` zamienia przepełnienie w głośny, obsługiwalny błąd.

### 2.2. Odtwarzalność

Środowisko zostało odtworzone od zera: nowy kontener miał `0` kluczy i `maxmemory=0`. Tymczasowy broker i jego wolumen usunięto.

---

## 3. E1-15 — harness BullMQ

Wykonano **sześć scenariuszy w obu topologiach**, tym samym kodem i obciążeniem. BullMQ `5.81.2`, Node `24.18.0`, trwały stan w bazie `core_fixture` (tabele `e1_15_*` tworzone i usuwane przez harness; fixture E3 nietknięty).

Wariant `split` uruchomiono na **osobnym, tymczasowym kontenerze Valkey** z tym samym digestem, zamiast przełączać projekt source na `compose.valkey-split.yaml`. Dzięki temu konfiguracja źródła nie zmieniła się ani na chwilę.

### 3.1. Wyniki scenariuszy

| # | Scenariusz | Wspólny broker | Osobny broker |
|---|---|---|---|
| A | ten sam `jobId`, gdy job nadal istnieje | ten sam identyfikator, `1` oczekujący, **1 wykonanie** | identycznie |
| B | ten sam `jobId` po `removeOnComplete` | job usunięty, identyfikator przyjęty ponownie, **2 wykonania** | identycznie |
| C | kill workera w trakcie aktywnego zadania | `1` wykonanie przed zabiciem, `1` zdarzenie `stalled`, **2 wykonania łącznie** | identycznie |
| D | wymuszony `stalled` i ponowne wykonanie | `1` zdarzenie `stalled`, **2 wykonania** | identycznie |
| E | dwie dostawy tej samej intencji, idempotentny zapis | **2 wykonania, 1 skutek biznesowy** | identycznie |
| F | usunięcie joba, trwała intencja, reconciliation | intencja przetrwała, job odbudowany, intencja zamknięta | identycznie |

**Wnioski niezależne od topologii:**

- `jobId` deduplikuje **tylko dopóki job istnieje**. Po `removeOnComplete` ten sam identyfikator uruchamia pracę ponownie (A vs B).
- Awaria workera daje **dostawę co najmniej jednokrotną**, nie dokładnie jednokrotną (C, D). Zadanie wykonało się dwa razy.
- Jeden skutek biznesowy zapewnia **idempotentny zapis w Core**, a nie kolejka (E).
- Trwała intencja plus reconciliation odbudowuje utracony job (F). To potwierdza wzorzec potrzebny również po wyniku E1-13.

### 3.2. Pomiary

| Pomiar | Wspólny | Osobny |
|---|---:|---:|
| czas wykonania scenariuszy | `21 s` | `24 s` |
| `used_memory` brokera Paperless w spoczynku | `2 463 880 B` | — |
| `used_memory` pustej drugiej instancji | — | `944 672 B` |
| RSS kontenera drugiej instancji | — | `6,09 MiB` |
| RSS kontenera brokera Paperless | `17,29 MiB` | — |
| kluczy Paperless przed / po | `12 / 12` | `12 / 12` |
| kluczy prefiksu harnessu po sprzątaniu | `0` | `0` |
| kolizje z kluczami `celery*` Paperless | brak | brak (osobna instancja) |

### 3.3. Rozstrzygnięcie topologii

**Zalecenie: dwie osobne instancje Valkey.** Pełne uzasadnienie — wraz z argumentami o granicy kontekstu, izolacji awarii przy `maxmemory`, ryzyku polityki eksmisji, niezależnym restarcie i kosztach operacyjnych — jest zapisane w uzupełnieniu [ADR-008](../../adr/ADR-008-valkey-bullmq.md).

Skrót: obie topologie działają funkcjonalnie identycznie, różnica pamięci to ~6 MiB, więc decyduje **izolacja awarii i granica bounded context**, a nie zużycie zasobów.

---

## 4. Status prób

| Próba | Status | Uwaga |
|---|---|---|
| E1-13 restart w trakcie OCR | **FAIL** | powtórzony dwukrotnie; materiał syntetyczny |
| E1-14 limit pamięci Valkey | **PASS** | izolowany broker, źródło nietknięte |
| E1-15a pomiar bazowy Paperless | **PASS** | |
| E1-15b-A…F scenariusze BullMQ | **PASS** | oba warianty |
| E1-15c porównanie topologii | **PASS** | rozstrzygnięcie w ADR-008 |

E1-13 pozostaje otwarte jako **wymaganie do powtórzenia na rzeczywistym skanie** oraz jako zadanie projektowe dla M4/M6/M11/M12 (trwała intencja, tymczasowy staging, timeout, idempotentne retry, reconciliation i manual review). Wynik FAIL nie jest krytycznym ograniczeniem w rozumieniu 08 §G1-02, ponieważ wymagane operacje REST oraz E3A/E3B przeszły.
