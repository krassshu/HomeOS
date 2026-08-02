# Checklista czynności pozostawionych użytkownikowi

**Status:** artefakt operacyjny · **Milestone:** M3 · **Data:** 2026-07-31

Lista pozostałych czynności wraz z właścicielem. Otwarte pozycje wymagają użytkownika, sprzętu albo późniejszej decyzji — **żadnej otwartej pozycji nie może już wykonać agent na obecnym laboratorium**. Sekcje 0 i 4 zachowują rozstrzygnięcia historyczne.

---

## 0. Ponowny E3A — WYKONANE, nic do zrobienia

Audyt wykazał, że pierwszy E3A nie wymuszał zatrzymania przyjmowania zapisów z E3A-01. Harness poprawiono, a tor **powtórzono 2026-07-31 dla Restica i Borga — oba PASS** (`46/46` kontroli OK).

Dowód punktu spójności: źródłowy `webserver` w stanie `exited` przez całe okno, eksporter w jednorazowym kontenerze bez publikowanych portów, `0` pozostawionych kontenerów, dokumenty `9 → 9`, okno `40 s`, źródło z powrotem `healthy`.

**Gate OS-2-LAB jest zamknięty w zakresie laboratoryjnym.** Zastrzeżenie symulowanego storage pozostaje — patrz §2.

---

## 1. Fizyczne skany papieru — blokują Gate OS-1

Cały materiał wejściowy tej rundy jest syntetyczny. Trzy pozycje wymagają rzeczywistych dokumentów:

| # | Czego potrzeba | Wymagania | Co odblokowuje |
|---|---|---|---|
| 1 | **`DOC-02`** — jednostronicowy skan rzeczywistej kartki | skaner lub aplikacja skanująca, 200–300 dpi, PDF; treść polska z diakrytykami; **dokument nieosobowy** (ulotka, instrukcja, wydruk testowy) | E1-05: OCR polski na rzeczywistym skanie |
| 2 | **`DOC-06`** — wielostronicowy skan rzeczywistego dokumentu | 4–20 stron, ten sam skaner, PDF bez warstwy tekstowej | E1-09d oraz **powtórzenie E1-13 na materiale rzeczywistym** |
| 3 | **`DOC-03`** — zdjęcie dokumentu telefonem | zdjęcie z rzeczywistego aparatu, naturalne oświetlenie, JPG/PNG | E1-09a: ścieżka uploadu mobilnego |

**Jak przekazać:** pliki umieścić w `lab-data/documents/` na maszynie laboratoryjnej. Katalog jest ignorowany przez Git. Nie umieszczać dokumentów zawierających dane osobowe — obowiązuje `spike-data-policy.md`.

**Po dostarczeniu** uruchomić:

```sh
lab/harness/e1/api-checks.sh all --file lab-data/documents/DOC-02.pdf
lab/harness/e1/ocr-restart-test.sh --file lab-data/documents/DOC-06.pdf --expect-pages <N> --phrase "<fraza z treści>"
```

---

## 2. Dyski 4 TB — blokują ADR-015

Repozytoria Restic i Borg z tej rundy leżą na dysku systemowym maszyny laboratoryjnej. To symulacja, a **nie ochrona przed fizyczną utratą serwera**.

| # | Czynność | Dlaczego |
|---|---|---|
| 4 | Podłączyć docelowy storage 4 TB | bez niego kryterium „dopasowanie do storage off-host i RTO” (waga 10%) pozostaje nieocenione |
| 5 | Powtórzyć `lab/harness/e3/e3a.sh` i `e3b.sh` z repozytoriami na docelowym storage | wynik techniczny obu kandydatów jest równy; rozstrzygnąć ma zachowanie na faktycznym nośniku |
| 6 | Zmierzyć czas backupu i RTO przy realnym wolumenie danych | zestaw testowy ma ~7 MB, docelowy storage 4 TB |
| 7 | Sprawdzić zachowanie przy nośniku z błędami odczytu | nieobjęte tą rundą |

**Dopiero po tych krokach** ADR-015 może przejść do `accepted`. Rekomendacja wstępna (Restic) jest zapisana w [`08-e3-backup-report.md`](08-e3-backup-report.md) §5.

---

## 3. Materiały odzyskiwania poza serwerem — blokują realną ochronę DR

| # | Czynność | Stan obecny |
|---|---|---|
| 8 | Przenieść hasło repozytorium Restic na nośnik **poza serwerem** | obie kopie w `lab-data/e3/recovery-copy-a` i `-b` |
| 9 | Przenieść passphrase i eksport klucza Borg poza serwer | jak wyżej |
| 10 | Potwierdzić, że obie kopie są na **różnych** nośnikach fizycznych | obecnie oba katalogi są na tym samym urządzeniu (`2050`) |

> Dwie kopie na jednym dysku nie są dwiema kopiami. Utrata tego dysku oznacza jednoczesną utratę backupu i materiału potrzebnego do jego odczytania.

Wartości haseł **nie są i nie mogą być** zapisane w dokumentacji ani w repozytorium. Pliki mają uprawnienia `0600`.

---

## 4. Rozstrzygnięcia właściciela projektu — wykonane

| # | Decyzja | Kontekst |
|---|---|---|
| 11 | **Rozstrzygnięte:** FAIL E1-13 jest wymaganiem odporności M4/M6/M11/M12, nie krytycznym ograniczeniem z 08 §G1-02 | wymagane: trwała intencja, tymczasowy staging do potwierdzenia, timeout, idempotentne retry, reconciliation i manual review; test na rzeczywistym skanie nadal należy powtórzyć; parametry kwarantanny rozstrzygnie ADR G4-06 |
| 12 | **Rozstrzygnięte:** dwie osobne instancje Valkey | uzupełnienie ADR-008; wpływa na Compose produktu w M9 |
| 13 | **Rozstrzygnięte:** inwentarz OS-3-LAB zaakceptowany | ADR-016 przeniesiony do `accepted` na tej podstawie |

---

## 5. Czego użytkownik NIE musi robić

Te elementy są wykonane i nie wymagają powtórzenia, dopóki nie zmieni się wersja Paperless:

- E2 i wybór ORM (ADR-014 `accepted`).
- Topologia Valkey — zmierzona w obu wariantach.
- E3A i E3B — pełne tory przeszły dla obu kandydatów; E3A powtórzony z wymuszonym punktem spójności.
- Inwentarz licencyjny laboratorium.
- Fixture Core, manifest źródłowy i zestaw DR.

---

## 6. Stan środowiska po tej rundzie

| Pozycja | Stan |
|---|---|
| Projekt `homeos-m3-source` | działa, `6` kontenerów, `healthy` (potwierdzone po ponowieniu E3A) |
| Dokumenty Paperless | `9` aktywnych, `1` w koszu — **bez zmian względem stanu sprzed rundy i sprzed ponowienia E3A** |
| Wolumeny źródła | `6` używanych przez aktywny wariant shared nienaruszonych; wariant split dodaje siódmy wolumen Core Valkey |
| Konfiguracja źródła | niezmieniona (potwierdzone sumą kontrolną pliku env) |
| Projekt `homeos-m3-restore` | usunięty po ostatnim kandydacie; odtwarzalny w całości |
| Zadania osierocone | `2` rekordy w stanie `started` po próbach E1-13 — ślad dowodowy, nie usunięto |

Dwa zawieszone rekordy zadań to **materiał dowodowy wyniku FAIL E1-13**. Nie usunięto ich, żeby nie zatrzeć dowodu. Nie wpływają na dokumenty ani na eksport; są widoczne w `/api/tasks/`.

Materiały odzyskiwania z §3 chronią obecnie wyłącznie dostęp do repozytoriów Restic/Borg. Nie zawierają pakietu sekretów aplikacyjnych HomeOS/Paperless. Taki oddzielny, szyfrowany pakiet oraz test jego użycia są obowiązkowe przed produkcyjną bramą M17; nie są częścią potwierdzonego wyniku OS-2-LAB.
