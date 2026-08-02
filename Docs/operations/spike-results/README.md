# Wyniki Fazy 1

Ten katalog przechowuje wyłącznie zanonimizowane, trwałe artefakty opisane w `../spike-plan.md` §5.

Pliki:

| Plik | Artefakt planu §5 | Zakres |
|---|---|---|
| `01-test-document-manifest.md` | 1 | manifest plików testowych i ich cech |
| `02-resource-measurements.csv` | 2 | RAM, CPU, czasy, przyrost dysku, mnożniki |
| `03-api-notes.md` | 3 | faktyczne struktury odpowiedzi REST 3.0.4 |
| `05-compatibility-matrix.md` | 5 | pokrycie operacji, fallbacki, konfiguracja, OCR, exporter/importer, E3B |
| `06-orm-decision-report.md` | 6 (część E2) | rozstrzygnięcie ADR-014 |
| `07-e1-15-valkey-topology.md` | 6 (część E1) | E1-13, E1-14, E1-15 i rozstrzygnięcie topologii Valkey |
| `08-e3-backup-report.md` | 6 (część E3) | E3A i E3B, porównanie Restic vs Borg |
| `09-os3-lab-inventory.md` | 6 (OS-3-LAB) | inwentarz licencyjny laboratorium |
| `10-decisions-and-gates.md` | 6 | zbiorczy raport decyzji, bram i statusów PASS / PASS wstępny / BLOCKED / FAIL |
| `11-reproduction-config.md` | 7 | konfiguracja do powtórzenia eksperymentu |
| `12-user-checklist.md` | — | czynności pozostawione użytkownikowi |

Każdy artefakt dotyczący Paperless musi wskazywać `3.0.4`, wieloplatformowy digest obrazu oraz digest właściwy dla architektury hosta. `03-api-notes.md` zawiera checksum surowego OpenAPI pobranego z `/api/schema/` na uruchomionej instancji 3.0.4; `/api/schema/view/` jest interaktywną przeglądarką, a nie plikiem schematu. `05-compatibility-matrix.md` obejmuje ponownie sprawdzone API, konfigurację, OCR, duplikaty, exporter/importer, sanity checker i E3B; nie wolno uzupełnić jej wynikami z 2.x.

Artefakt 4 — skrypty testujące — mieszka w izolowanym katalogu narzędziowym laboratorium: `lab/harness/e1/` (kontrakt API, duplikaty, restart w trakcie OCR, limit pamięci Valkey), `lab/harness/e1-15/` (harness BullMQ) i `lab/harness/e3/` (fixture, storage, E3A, E3B, próby narzędziowe).

Katalogi `raw/` i `private/` są ignorowane przez Git. Zasady redakcji: [`../spike-data-policy.md`](../spike-data-policy.md).

Wyniki torów E3 zawierające ścieżki repozytoriów i pomiary jednostkowe pozostają w ignorowanym katalogu `lab-data/e3/results/` na maszynie laboratoryjnej.

Wszystkie siedem artefaktów trwałych istnieje. Nie oznacza to zamknięcia Fazy 1 — stan bram i pozycje blokujące są w [`10-decisions-and-gates.md`](10-decisions-and-gates.md).
