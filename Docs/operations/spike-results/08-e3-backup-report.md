# E3A i E3B — Restic vs Borg

**Status:** wynik eksperymentu · **Milestone:** M3 · **Data:** 2026-07-31

**Podstawa:** `../spike-plan.md` §3 · wejście do [ADR-015](../../adr/ADR-015-narzedzie-backupu.md) i Gate OS-2-LAB

**Wersje narzędzi:** `restic 0.18.0` (pakiet Debiana `restic 0.18.0-1+b4`), `borg 1.4.0` (pakiet Debiana `borgbackup 1.4.0-5`).

Wyniki surowe i podsumowania: `../../../lab-data/e3/results/` (poza Git zgodnie ze `spike-data-policy.md`).

---

## 0. Zakres i ograniczenie wyniku

> **Storage jest symulowany.** Oba repozytoria, staging, kopie retencyjne i oba katalogi materiałów odzyskiwania leżą na **tym samym fizycznym dysku tej samej maszyny** (`/dev/sda2`, to samo urządzenie `2050`). Ta próba mierzy poprawność, integralność i ergonomię narzędzi. **Nie mierzy** dopasowania do docelowego storage 4 TB, przepustowości łącza off-host ani zachowania przy odległym backendzie.

Dlatego wynik jest techniczny, a nie ostateczny — ADR-015 pozostaje `proposed`.

Oba tory wykonano na **dokładnie tym samym materiale wejściowym**:

- E3A: jeden eksport `document_exporter` 3.0.4, checksum drzewa `2ce5f85cae40…0ea123`, `27` plików, `10` dokumentów (9 aktywnych + 1 z kosza). Pierwszy przebieg nie wymuszał zatrzymania przyjmowania zapisów z E3A-01; **tor powtórzono 2026-07-31 poprawionym harness’em** i to powtórzenie jest wynikiem wiążącym. Eksport z obu przebiegów ma identyczny checksum drzewa.
- E3B: jeden zamrożony zestaw DR, checksum `484aa82e5ca0…58ec3a`, `15` plików, `6 946 464 B`.

---

## 1. E3A — przenośność aplikacyjna

**Wynik: PASS dla obu kandydatów** (przebieg powtórzony 2026-07-31, `46/46` kontroli OK, kod wyjścia `0`).

Dla każdego kandydata: backup eksportu → pełna kontrola integralności → kontrolowane przerwanie dodatkowego backupu → potwierdzenie poprzedniego restore pointa → ponowienie → restore do stagingu → **wyczyszczenie wyłącznie projektu `homeos-m3-restore`** → pusta instancja 3.0.4 z tym samym digestem → `document_importer` → nowy token celu → sanity checker → walidacja biznesowa.

### 1.1. Wymuszony punkt spójności (E3A-01)

| Dowód | Wartość |
|---|---|
| `freeze_enforced` | `yes` |
| stan źródłowego `webserver` podczas eksportu | **`exited`** (sprawdzony `docker inspect`, nie samym kodem `stop`) |
| eksporter | jednorazowy kontener Compose, `--no-deps`, **bez `--service-ports`** |
| pozostawione kontenery exportera | `0` |
| **czas niedostępności źródła** | **`40 s`** (w tym eksport `4 s`, reszta to restart do `healthy`) |
| dokumentów przed / po oknie | `9` / `9` |
| źródło po oknie | `healthy`, sanity checker `No issues detected` |

Dowód zapisany w `e3a-export-freeze.txt`.

> **Korekta harnessu wykryta w tym przebiegu.** Obraz Paperless 3.0.4 startuje przez **s6-overlay** (`ENTRYPOINT ["/init"]`). Przekazanie `document_exporter` jako CMD do `docker compose run` **nie uruchamia eksportera**, tylko cały stack usług razem z workerem Celery i consumerem — czyli drugiego pisarza na danych źródła. Byłoby to gorsze niż pierwotny brak E3A-01. Poprawka wywołuje polecenie administracyjne wprost: `--entrypoint /command/s6-setuidgid` → `paperless python3 manage.py document_exporter --skip-checks ../export --compare-checksums`. Flaga `--skip-checks` jest konieczna, bo pakiet języka OCR `pol` instaluje dopiero init obrazu, a kontrola systemowa Django zgłasza jego brak; eksport czyta bazę i kopiuje pliki, więc OCR nie jest mu potrzebny. Wariant `docker exec` na działającym webserverze pozostaje odrzucony — ponownie złamałby E3A-01.

### 1.2. Wyniki obu kandydatów

| Kryterium | Restic | Borg |
|---|---|---|
| backup eksportu utworzył restore point | PASS | PASS |
| pełna kontrola integralności | PASS (`check --read-data`) | PASS (`check --verify-data`) |
| przerwany backup → niezerowy kod | PASS (`137`) | PASS (`137`) |
| poprzedni restore point dostępny po przerwaniu | PASS | PASS |
| bezpieczne ponowienie | PASS | PASS |
| odtworzony eksport bajtowo identyczny | PASS | PASS |
| pusta instancja 3.0.4 z tym samym digestem | PASS | PASS |
| cel bez wolumenów i katalogów źródła | PASS (`0` odwołań) | PASS (`0` odwołań) |
| `document_importer` | PASS (`4 s`, kod `0`) | PASS (`3 s`, kod `0`) |
| nowy token celu, bez tokenu źródła | PASS | PASS |
| sanity checker | PASS (`No issues detected`) | PASS |
| liczniki: dokumenty / tagi / korespondenci / typy | `9/9`, `1/1`, `1/1`, `1/1` | `9/9`, `1/1`, `1/1`, `1/1` |
| wszystkie checksumy dokumentów odtworzone | PASS (`0` braków) | PASS (`0` braków) |
| otwarcie oryginału i preview przez API | PASS (`200`) | PASS (`200`) |
| OCR search w celu | PASS (`2` trafienia) | PASS (`2` trafienia) |
| kosz odtworzony | PASS (`1/1`) | PASS (`1/1`) |
| źródło po torze | PASS (`9` dokumentów, `6` wolumenów, `healthy`) | PASS (jak obok) |

**Obserwacja dotycząca eksportera:** `document_exporter` 3.0.4 eksportuje również **pozycje kosza**. Manifest eksportu zawierał `10` rekordów `documents.document` przy `9` dokumentach aktywnych i `1` w koszu. Kontrola kompletności musi porównywać sumę aktywnych i kosza, inaczej daje fałszywy alarm.

Cel restore był po każdym kandydacie usuwany i odtwarzany od zera.

**Historia braku dowodowego E3A-01:** pierwszy przebieg potwierdził brak aktywnych i zarezerwowanych zadań, lecz pozostawił źródłowy webserver dostępny podczas `document_exporter`. W izolowanym laboratorium nie zaobserwowano równoległych zapisów, ale nie było to równoważne z ich technicznym zablokowaniem. Harness poprawiono, a tor **powtórzono w całości dla Restica i Borga** — dopiero ten przebieg zamyka E3A-01. Brak proceduralny został wykryty audytem raportu, a nie w trakcie testu; zapis zachowano, żeby historia wyniku była odtwarzalna.

**Kroki manualne po przerwaniu — obserwacja z tego przebiegu:** Restic wymagał `unlock` (blokada po `SIGKILL`), Borg tym razem **nie** wymagał `break-lock`. Zachowanie Borga po przerwaniu okazało się więc niestabilne między przebiegami; ocena ergonomii w §3.1 opiera się na powtarzalnych próbach `tool-trials.sh`, które nie były w tej rundzie powtarzane.

Rozmiary repozytoriów po tym przebiegu (`restic 3 809 294 910 B`, `borg 1 690 484 661 B`) **nie są miarą wielkości backupu eksportu** — zawierają skumulowany materiał przerwań i ponowień (`400 MB` danych losowych na próbę). Porównywalne pomiary rozmiaru i czasu są w §3, na czystych repozytoriach.

---

## 2. E3B — disaster recovery

### 2.1. Zamrożony zestaw DR

Jeden zestaw dla obu kandydatów, zbudowany raz:

| Element | Wartość |
|---|---|
| logiczny dump PostgreSQL Paperless | `359 543 B` (`pg_dump -Fc`) |
| logiczny dump PostgreSQL `core_fixture` | `5 687 B` (`pg_dump -Fc`) |
| media Paperless | `6 562 816 B` (tar wolumenu) |
| assety Core | `4 608 B` |
| zredagowana konfiguracja | 7 plików, `0` jawnych wartości sekretów |
| wersje narzędzi + manifest źródłowy | tak |
| plików łącznie / rozmiar | `15` / `6 946 464 B` |
| **czas zamrożenia zapisów** | **`38 s`** |
| checksum zestawu | `484aa82e5ca0…58ec3a` |

Zamrożenie zatrzymało wyłącznie usługę `webserver` (API, consumer i worker w jednym kontenerze). **Nie kopiowano aktywnych plików danych PostgreSQL** — wyłącznie logiczne dumpy. Po odmrożeniu: `webserver` `healthy`, sanity checker `No issues detected`, liczba dokumentów niezmieniona (`9 → 9`).

> **Granica bezpieczeństwa wyniku:** „0 wartości sekretów” dotyczy wyłącznie zredagowanych plików konfiguracji. Dump Paperless zawiera dane uwierzytelniające i inne informacje wrażliwe, dlatego cały zestaw DR musi pozostać w szyfrowanym repozytorium z prywatnym stagingiem. Cel laboratoryjny użył nowego `PAPERLESS_SECRET_KEY`; próba nie potwierdza odzyskania źródłowych sekretów aplikacyjnych ani odszyfrowania przyszłych ustawień takich jak hasła kont pocztowych. Oddzielny szyfrowany pakiet sekretów i jego pełny test należą do bezwzględnej bramy M17.

### 2.2. Odtworzenie na czysty cel

| Kryterium | Restic | Borg |
|---|---|---|
| zestaw DR zabezpieczony | PASS | PASS |
| pełna kontrola integralności | PASS | PASS |
| przerwanie → niezerowy kod | PASS (`137`) | PASS (`137`) |
| wcześniejszy restore point dostępny | PASS | PASS |
| bezpieczne ponowienie | PASS | PASS |
| odtworzony zestaw identyczny z zamrożonym | PASS | PASS |
| logiczne odtworzenie bazy Paperless | PASS | PASS |
| logiczne odtworzenie bazy `core_fixture` | PASS | PASS |
| media i assety odtworzone | PASS (`25` plików) | PASS (`25` plików) |
| Paperless 3.0.4 z tym samym digestem | PASS | PASS |
| **przebudowa indeksu wymagana** | **nie** | **nie** |
| sanity checker | PASS | PASS |
| liczba dokumentów | `9/9` | `9/9` |
| reconciliation Core ↔ Paperless | PASS (`9/9` zgodnych, `0` rozjazdu) | PASS (`9/9`, `0`) |
| external IDs wskazują istniejące dokumenty | PASS | PASS |
| checksumy assetów zgodne z manifestem | PASS (`0` niezgodnych) | PASS (`0`) |
| otwarcie oryginału i preview | PASS | PASS |
| OCR search po DR | PASS (`2` trafienia) | PASS (`2` trafienia) |
| cel niezależny od źródła | PASS (`0` odwołań) | PASS (`0` odwołań) |

**Obserwacja dotycząca indeksu:** zestaw DR celowo nie zawiera katalogu `data` Paperless (indeks wyszukiwania jest danymi pochodnymi). Mimo to wyszukiwanie pełnotekstowe działało **bez ręcznej przebudowy** — instancja 3.0.4 odtworzyła indeks samodzielnie przy starcie. Ręczny `document_index reindex` nie był potrzebny w żadnym przebiegu.

---

## 3. Obowiązkowe próby narzędziowe

Wykonane na czystych repozytoriach zawierających wyłącznie zestaw DR, żeby pomiary rozmiaru i czasu były porównywalne.

| Próba | Restic | Borg |
|---|---:|---:|
| rozmiar źródła | `6 946 464 B` | `6 946 464 B` |
| **rozmiar repozytorium** | `6 351 335 B` | `6 382 907 B` |
| **czas backupu** | `0,80 s` | `0,26 s` |
| **czas pełnego restore** | `0,74 s` | `0,19 s` |
| pełny restore | PASS | PASS |
| **restore pojedynczego pliku** | PASS — dokładnie `1` plik, suma zgodna | PASS — dokładnie `1` plik, suma zgodna |
| **otwarcie drugą kopią materiału odzyskiwania** | PASS (hasło z `recovery-copy-b`) | PASS (passphrase z `recovery-copy-b`) |
| eksport klucza poza repozytorium | nie dotyczy (hasło jest materiałem) | PASS (`813 B`, kopie A i B identyczne) |
| **dry-run retencji** | PASS — `3 → 3`, nic nie usunięte | PASS — `3 → 3`, nic nie usunięte |
| **retencja + prune na kopii jednorazowej** | PASS — `3 → 1` | PASS — `3 → 1` |
| repozytorium podstawowe nietknięte | PASS (`3` snapshoty) | PASS (`3` archiwa) |
| kontrola integralności po retencji | PASS | PASS |
| kod i komunikat przy złym haśle | `12`, `wrong password or no key found` | `2`, `passphrase … is incorrect` |

Prune nigdy nie był wykonywany na podstawowym repozytorium wynikowym — wyłącznie na jednorazowych kopiach w `retention-copies/`.

### 3.1. Kroki manualne i diagnostyka

To jedyny wymiar, w którym kandydaci różnią się wyraźnie.

| Sytuacja | Restic | Borg |
|---|---|---|
| po zabiciu backupu (`SIGKILL`) | zostaje blokada; `restic unlock`, komunikat wskazuje PID, host i polecenie naprawcze | zostaje blokada; `borg break-lock` |
| po retencji | `forget --prune` zwalnia miejsce w jednym kroku | `prune` **nie zwalnia miejsca**; wymagany osobny `borg compact` |
| praca na kopii repozytorium | działa bez dodatkowych kroków | wymaga `BORG_RELOCATED_REPO_ACCESS_IS_OK=yes` |
| dostęp do oryginału po użyciu kopii w tym samym katalogu stanu klienta | bez zmian | klient odmawia dostępu: `Cache, or information obtained from the security directory is newer than repository` |
| **liczba kroków manualnych** | **1** | **3** |

**Najważniejsza obserwacja operacyjna:** Borg identyfikuje repozytorium po jego ID, a nie po ścieżce, i domyślnie utrzymuje wspólny katalog `security`/`cache` dla kopii o tym samym ID. Po operacji na skopiowanym repozytorium klient używający tego samego katalogu stanu może odmówić otwarcia oryginału. Repozytorium i dane pozostają poprawne; bezpieczna procedura nadaje każdej kopii osobny `BORG_BASE_DIR` od pierwszego użycia.

Potwierdzono empirycznie, że dane oryginału **nie ucierpiały**: po wskazaniu izolowanego `BORG_BASE_DIR` repozytorium podstawowe pokazało komplet `3` archiwów. To pułapka ergonomiczna i operacyjna, nie utrata danych — ale w scenariuszu odzyskiwania po awarii, wykonywanym pod presją, jest to realne ryzyko pomyłki.

Restic nie ma odpowiednika tego zachowania: kopia repozytorium jest zwykłym katalogiem.

---

## 4. Punktacja wg kryteriów planu §3.4

Warunek wejścia — pełne przejście E3A i E3B oraz kontroli integralności — **spełnili obaj kandydaci** (E3A potwierdzony powtórzonym przebiegiem z wymuszonym punktem spójności).

| Kryterium | Waga | Restic | Borg | Uzasadnienie |
|---|---:|---:|---:|---|
| Poprawność i powtarzalność E3A + E3B | 35% | 5 | 5 | oba tory w całości PASS, checksumy bajtowo zgodne |
| Integralność repozytorium i diagnostyka uszkodzeń | 15% | 5 | 5 | pełna weryfikacja danych bez błędów; czytelne komunikaty |
| Zachowanie po przerwaniu i restore points | 10% | 5 | 4 | oba zachowują poprzedni snapshot; Borg wymaga dodatkowego kroku |
| Obsługa kluczy i odtworzenie z drugiej kopii | 10% | 5 | 5 | obie kopie działają; Borg dodatkowo eksportuje klucz |
| Retencja, prune i restore pojedynczego pliku | 10% | 5 | 3 | Borg wymaga `compact` i izolacji stanu przy pracy na kopii |
| Dopasowanie do storage off-host i RTO | 10% | — | — | **nieoceniane — storage symulowany** |
| Prostota, audytowalność i diagnostyka runbooka | 10% | 5 | 3 | 1 krok manualny vs 3; pułapka identyczności repozytoriów |

**Wynik cząstkowy bez kryterium storage** (suma `ocena/5 × waga`, znormalizowana do 90% dostępnej wagi):

- **Restic: 90,0 / 90** → `100 %`
- **Borg: 79,5 / 90** → `88,3 %`

Czas backupu i rozmiar repozytorium są pomiarami pomocniczymi. Borg był szybszy (`0,26 s` vs `0,80 s`) i o `0,5 %` większy — obie różnice są nieistotne przy tej skali danych i nie przeważają nad poprawnością ani ergonomią.

---

## 5. Rekomendacja wstępna

**Restic — rekomendacja wstępna, nie decyzja końcowa.**

Podstawa: identyczna poprawność obu kandydatów przy wyraźnie prostszej obsłudze operacyjnej Restica (jeden krok manualny zamiast trzech, brak pułapki wspólnego stanu przy kopiach repozytorium).

**Czego ta rekomendacja nie obejmuje i co blokuje decyzję końcową:**

1. Kryterium „dopasowanie do docelowego storage off-host i RTO” (waga 10%) **nie zostało ocenione**, bo storage 4 TB jeszcze nie istnieje.
2. Nie zmierzono zachowania przy dużym wolumenie danych — zestaw testowy to ~7 MB, docelowy storage to 4 TB.
3. Nie zmierzono backupu przez sieć ani czasu odtworzenia z nośnika zewnętrznego.
4. Nie zweryfikowano zachowania obu narzędzi przy nośniku z błędami odczytu.

Dlatego **ADR-015 pozostaje `proposed`**. Rozstrzygnięcie wymaga powtórzenia §3 na docelowym storage po dostarczeniu dysków.

---

## 6. Gate OS-2-LAB

| Kryterium | Status |
|---|---|
| E3A: pełny eksport 3.0.4 z wymuszonym punktem spójności zaimportowano na pustej instancji 3.0.4 z tym samym digestem | ✅ dla obu — punkt spójności wymuszony i udowodniony |
| E3A: nowy token, sanity checker, otwieranie dokumentów i OCR search działają | ✅ dla obu |
| E3B: odtworzono obie bazy, media, assety i konfigurację na czystym celu | ✅ dla obu |
| E3B: sanity checker oraz reconciliation przechodzą | ✅ dla obu |
| External IDs, liczniki i checksumy zgadzają się z manifestem | ✅ dla obu |
| Oba tory wykonano dla Restic i Borg; kandydat przeszedł wszystkie kryteria blokujące | ✅ dla obu |

**Gate OS-2-LAB: zamknięty w zakresie laboratoryjnym.** E3A i E3B przechodzą dla Restica i Borga, a E3A wykonano ponownie z wymuszonym i udowodnionym punktem spójności.

**Czego to zamknięcie nie oznacza.** Storage pozostaje symulowany — oba repozytoria, staging, kopie retencyjne i obie kopie materiałów odzyskiwania leżą na tym samym fizycznym dysku. Gate potwierdza poprawność procedur laboratoryjnych, **nie gotowość produkcyjną**. Pełna walidacja restore produktu pozostaje bramą M17, a ADR-015 pozostaje `proposed` do czasu testu na docelowym storage 4 TB.
