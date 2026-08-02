# ADR-015 — Narzędzie backupu

| Pole | Wartość |
|---|---|
| **Status** | `proposed` |
| **Data** | 2026-07-27 |
| **Milestone** | M3 (wybór narzędzia), M17 (walidacja produkcyjna) |
| **Zastępuje** | Listę trzech kandydatów z `operations/04-Deployment-and-Infrastructure.md` §28 (Kopia odpada) |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/05-Open-Source-Architecture.md` §16, `07-Product-and-Delivery-Roadmap.md` §22, §36.6, `architecture/discrepancy-register.md` R-12 |

---

## Kontekst

Backup obejmuje dane obu baz, dokumenty i derivative Paperless, assety Core, konfigurację i sekrety odzyskiwania. Restic i Borg są transportem oraz repozytorium zaszyfrowanych plików; nie tworzą same spójnego logicznego backupu PostgreSQL. Restore jest bramą bezwzględną MVP — bez niego nie ma produkcyjnego wydania.

## Problem

Które narzędzie backupu odtwarza reprezentatywny stack laboratoryjny na czystym celu i może następnie zostać zweryfikowane na pełnym produkcie w M17.

## Decyzja

**Nierozstrzygnięte.** Kandydaci: **Restic** i **Borg**. Kopia wypada z krótkiej listy (R-12).

> **Status `proposed`.** Rozstrzygany dwoma torami na Paperless **3.0.4 z przypiętym digestem**: E3A sprawdza pełny `document_exporter`/`document_importer` 3.0.4, a E3B — disaster recovery z logicznych dumpów obu baz, mediów Paperless, assetów Core i konfiguracji. Oba tory wykonuje się osobno dla Restic i Borg na czystym celu 3.0.4. Nie dziedziczą wyników ani założeń z 2.x.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Restic | Prosty, szyfrowany, wiele backendów | Mniej opcji polityki retencji niż Borg | Kandydat |
| Borg | Bardzo dojrzały, mocny dla lokalnego i SSH repozytorium | Słabsze wsparcie dla zdalnych backendów obiektowych | Kandydat |
| Kopia | Dobre polityki, wiele backendów | Nie występuje w 05 ani 07 | Odpada (R-12) |
| Własne skrypty + tar/gzip | Pełna kontrola | Brak deduplikacji, szyfrowania i weryfikacji integralności | Dyskwalifikujące |

## Konsekwencje pozytywne

- Decyzja oparta na wykonanym odtworzeniu, nie na deklaracjach.

## Konsekwencje negatywne

- Oba tory restore dla obu kandydatów kosztują czas w Fazie 1.
- Utrata klucza szyfrującego oznacza utratę backupu — wymaga procedury dwóch kopii.

## Warunki ponownej analizy

- **Warunek rozstrzygnięcia:** kandydat kończy E3A i E3B na czystym celu, przechodzi pełną kontrolę integralności właściwą dla narzędzia, test przerwania, odczyt z drugiej kopii klucza, retencję/prune i restore pojedynczego pliku. Porównanie zachowuje ten sam zestaw danych, host, izolację i kryteria sukcesu, ale może używać różnych naturalnych backendów; dopasowanie do faktycznego storage jest częścią wyniku.
- Po przyjęciu: narzędzie przestaje wspierać docelowy storage albo traci utrzymanie.

## Wynik techniczny z 2026-07-31 (E3A i E3B, laboratorium M3)

Pełny raport: [`../operations/spike-results/08-e3-backup-report.md`](../operations/spike-results/08-e3-backup-report.md).

Restic `0.18.0` i Borg `1.4.0` poprawnie zabezpieczyły i odtworzyły ten sam eksport oraz ten sam zamrożony zestaw DR. E3B przeszedł do końca. Audyt wykazał, że pierwszy przebieg E3A nie wymuszał zatrzymania przyjmowania nowych zapisów z E3A-01; harness poprawiono, a **tor powtórzono 2026-07-31 dla obu kandydatów — oba PASS**, z udowodnionym punktem spójności (źródłowy `webserver` w stanie `exited`, eksporter w jednorazowym kontenerze bez portów, dokumenty `9 → 9`, okno `40 s`).

| Wymiar | Restic | Borg |
|---|---|---|
| E3A i E3B w całości | PASS (E3A potwierdzony powtórzonym przebiegiem) | PASS (jak obok) |
| pełna kontrola integralności danych | PASS | PASS |
| przerwanie i bezpieczne ponowienie | PASS | PASS |
| restore pojedynczego pliku | PASS | PASS |
| otwarcie drugą kopią materiału odzyskiwania | PASS | PASS |
| retencja, dry-run i prune na kopii | PASS | PASS |
| czas backupu / restore zestawu `6 946 464 B` | `0,80 s` / `0,74 s` | `0,26 s` / `0,19 s` |
| rozmiar repozytorium | `6 351 335 B` | `6 382 907 B` |
| **kroki manualne w obsłudze** | **1** (`unlock`) | **3** (`break-lock`, `compact`, zgoda na przeniesienie repozytorium) |

Różnica rozstrzygająca leży wyłącznie w ergonomii operacyjnej. Borg identyfikuje repozytorium po ID, nie po ścieżce, i domyślnie współdzieli stan `security`/`cache` między kopiami: po operacji na kopii klient korzystający z tego samego katalogu stanu może odmówić otwarcia oryginału. Dane nie giną; bezpieczna procedura wymaga osobnego `BORG_BASE_DIR` dla każdej kopii od pierwszego użycia. W procedurze odzyskiwania wykonywanej pod presją jest to realne ryzyko pomyłki. Restic nie ma odpowiednika tego zachowania.

**Rekomendacja wstępna: Restic.**

## Dlaczego status pozostaje `proposed`

Zamknięcie Gate OS-2-LAB **nie rozstrzyga tego ADR-a.** Kryterium „dopasowanie do docelowego storage off-host i RTO” (waga 10% w planie §3.4) **nie zostało ocenione**. Cała próba działała na symulowanym storage: oba repozytoria, staging, kopie retencyjne i obie kopie materiałów odzyskiwania leżały na tym samym fizycznym dysku tej samej maszyny. Nie zmierzono też zachowania przy wolumenie zbliżonym do 4 TB, backupu przez sieć ani odczytu z nośnika z błędami.

Rozstrzygnięcie wymaga powtórzenia §3 planu na docelowym storage po dostarczeniu dysków. Do tego czasu **nie wolno przedstawiać rekomendacji wstępnej jako decyzji**.

## Weryfikacja

**Brama M3:** E3A odtwarza użyteczną kolekcję przez oficjalny eksport/import, a E3B odtwarza na czystym celu obie bazy, media, assety i konfigurację; sanity checker, reconciliation, OCR search, external IDs i checksumy przechodzą. — **Spełnione dla obu torów i obu kandydatów; Gate OS-2-LAB zamknięty w zakresie laboratoryjnym.**  
**Brama bezwzględna M17:** na czystej maszynie odtworzono produkt, zalogowano się, otwarto dokumenty, wykonano OCR search, sprawdzono relacje i zweryfikowano checksum. Pełny restore testowany co najmniej kwartalnie.
