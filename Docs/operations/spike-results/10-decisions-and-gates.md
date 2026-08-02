# Raport decyzji i bram M3

**Status:** wynik eksperymentu · **Milestone:** M3 · **Data:** 2026-07-31

**Podstawa:** `../spike-plan.md` §4 i §5 (artefakt trwały nr 6)

---

## 1. Stan rundy

| Tor | Stan |
|---|---|
| E1 — Paperless / Gotenberg / Valkey | wykonany technicznie; **jedno kryterium FAIL (E1-13)**; otwarte wymaganie rzeczywistych skanów |
| E2 — PoC ORM | zamknięty wcześniej; ADR-014 `accepted` (Prisma) |
| E3A — przenośność aplikacyjna | **powtórzony 2026-07-31 z wymuszonym punktem spójności; PASS dla Restic i Borg** (`46/46` kontroli OK) |
| E3B — disaster recovery | wykonany dla Restic i Borg, oba PASS |
| OS-3-LAB | inwentarz kompletny, gate przechodzi |

---

## 2. Legenda statusów

| Status | Znaczenie |
|---|---|
| **PASS** | test faktycznie wykonany na docelowym materiale i spełnia kryterium |
| **PASS wstępny** | technicznie wykonany, ale na materiale syntetycznym albo symulowanym storage |
| **BLOCKED** | wymaga fizycznej czynności użytkownika lub sprzętu, którego nie ma |
| **FAIL** | wykonany i niespełniający kryterium |

---

## 3. Pełna lista wyników tej rundy

### 3.1. E1 — zachowania awaryjne i kolejka

| Test | Status | Podstawa |
|---|---|---|
| E1-13 restart Paperless w trakcie OCR | **FAIL** | zadanie zostaje w stanie `started` bez końca, dokument przepada; powtórzone 2× |
| E1-14 limit pamięci Valkey w izolowanym brokerze | **PASS** | `noeviction`, czytelny błąd OOM, `evicted_keys=0`, środowisko odtworzone |
| E1-15a pomiar bazowy Paperless | **PASS** | `12` kluczy, `2 463 880 B` |
| E1-15b-A ten sam `jobId`, gdy job istnieje | **PASS** | 1 wykonanie, oba warianty |
| E1-15b-B ten sam `jobId` po `removeOnComplete` | **PASS** | 2 wykonania, oba warianty |
| E1-15b-C kill workera w trakcie zadania | **PASS** | 2 wykonania, oba warianty |
| E1-15b-D scenariusz `stalled` i ponowne wykonanie | **PASS** | 2 wykonania, oba warianty |
| E1-15b-E idempotentny zapis do fixture Core | **PASS** | 2 wykonania → 1 skutek, oba warianty |
| E1-15b-F usunięcie joba i reconciliation | **PASS** | intencja przetrwała, job odbudowany, oba warianty |
| E1-15c porównanie topologii Valkey | **PASS** | zachowanie identyczne; decyzja w ADR-008 |
| Kontrakt API: status, wersja, OpenAPI, dokument, checksum | **PASS** | `92` ścieżki w schemacie 3.0.4 |
| Endpointy binarne `/download/`, `/preview/`, `/thumb/` | **PASS z fallbackiem** | typ docelowy w `Accept` → `406`; sprawdzony wariant `application/json; version=10` |

### 3.2. E3 — przenośność i disaster recovery

| Test | Status | Podstawa |
|---|---|---|
| E3A pełny tor — Restic | **PASS wstępny** | powtórzony przebieg z wymuszonym punktem spójności; wszystkie kryteria PASS; storage symulowany |
| E3A pełny tor — Borg | **PASS wstępny** | jak wyżej |
| E3A-01 wymuszony punkt spójności | **PASS** | źródłowy `webserver` w stanie `exited` przez całe okno, eksporter w jednorazowym kontenerze bez portów, `0` pozostawionych kontenerów, dokumenty `9 → 9`, okno `40 s` |
| E3B pełny tor — Restic | **PASS wstępny** | wszystkie kryteria PASS; storage symulowany |
| E3B pełny tor — Borg | **PASS wstępny** | wszystkie kryteria PASS; storage symulowany |
| Kontrola integralności z pełną weryfikacją danych | **PASS** | oba narzędzia, oba tory |
| Przerwanie backupu i bezpieczne ponowienie | **PASS** | kod `137`, poprzedni restore point zachowany |
| Restore pojedynczego pliku | **PASS** | oba narzędzia, dokładnie 1 plik, suma zgodna |
| Otwarcie repozytorium drugą kopią materiału odzyskiwania | **PASS wstępny** | działa; obie kopie na tym samym fizycznym dysku |
| Retencja: dry-run | **PASS** | oba narzędzia, nic nie usunięte |
| Retencja: prune na kopii jednorazowej | **PASS** | `3 → 1`, repozytorium podstawowe nietknięte |
| Kontrola integralności po retencji | **PASS** | oba narzędzia |
| Zredagowana konfiguracja w zestawie DR | **PASS** | `0` jawnych wartości sekretów w plikach konfiguracji; dump bazy pozostaje materiałem wrażliwym i jest chroniony przez szyfrowane repozytorium |
| Reconciliation Core ↔ Paperless po DR | **PASS** | `9/9` powiązań, `0` rozjazdu |

### 3.3. Pozostające BLOCKED

| Pozycja | Status | Dlaczego |
|---|---|---|
| `DOC-02` — jednostronicowy skan rzeczywistej kartki | **BLOCKED** | wymaga fizycznego skanu użytkownika |
| `DOC-06` — wielostronicowy skan rzeczywistego dokumentu | **BLOCKED** | wymaga fizycznego skanu użytkownika |
| `DOC-03` — zdjęcie z rzeczywistego aparatu telefonu | **BLOCKED** | wymaga zdjęcia użytkownika |
| E1-05 OCR polski na rzeczywistym skanie | **BLOCKED** | zależny od `DOC-02` |
| E1-13 na rzeczywistym skanie | **BLOCKED** | zależny od `DOC-06`; wersja syntetyczna dała FAIL |
| Ocena dopasowania kandydatów do storage 4 TB | **BLOCKED** | dyski nie zostały dostarczone |
| Materiały odzyskiwania poza serwerem | **BLOCKED** | wymaga nośnika zewnętrznego |
| Pomiar RTO na docelowym storage | **BLOCKED** | jak wyżej |

---

## 4. Bramy

### 4.1. Gate OS-1 (zamknięcie E1)

| Kryterium | Próg | Status |
|---|---|---|
| Siedem operacji blokujących `DocumentProvider` przez REST | blokujące | ✅ |
| Trzy operacje ostrzegawcze działają albo mają przetestowany fallback | blokujące na poziomie kontraktu | ✅ (miniatura i preview przez sprawdzony fallback `Accept`) |
| OCR polski pozwala odnaleźć dokument po frazie z treści | blokujące | ⚠️ potwierdzone na materiale syntetycznym; **rzeczywisty skan pozostaje BLOCKED** |
| Zasoby mieszczą się w profilu sprzętowym | ostrzegawcze | ✅ |
| Inwentarz licencji laboratorium kompletny i zaakceptowany | blokujące (OS-3-LAB) | ✅ |
| Brak krytycznego ograniczenia | blokujące | ✅ E1-13 jest wynikiem FAIL, ale nie spełnia przyjętej definicji krytycznego ograniczenia z 08 §G1-02; operacje REST działają, a E3A i E3B przeszły w całości dla obu kandydatów |

**Gate OS-1: nie przechodzi.** Jedyną niezamkniętą pozycją blokującą jest potwierdzenie OCR na rzeczywistych skanach.

**Klasyfikacja E1-13 jest rozstrzygnięta przez już przyjęte kryteria.** 08 §G1-02 definiuje krytyczne ograniczenie jako brak wymaganej operacji REST albo niemożność przejścia E3A/E3B. Żaden z tych warunków nie wystąpił — oba tory przeszły dla Restica i Borga. E1-13 pozostaje poważnym FAIL testu odporności i obowiązkowym wymaganiem projektowym: Core utrzymuje trwałą intencję oraz tymczasowy plik w kwarantannie do terminalnego potwierdzenia, stosuje timeout, retry z tym samym kluczem idempotencji, reconciliation i manual review po wyczerpaniu prób. Nie zmienia to trwałego właściciela binariów z ADR-006. Dokładne limity, retencję i zachowanie przy długiej niedostępności Paperless rozstrzygnie osobny ADR wymagany przez G4-06 przed M12.

### 4.2. Gate OS-2-LAB

E3B przeszedł wcześniej dla obu kandydatów. Audyt harnessu wykazał, że pierwszy przebieg E3A sprawdzał brak aktywnych zadań, ale nie zatrzymywał przyjmowania nowych zapisów wymaganym krokiem E3A-01. Harness poprawiono i **tor powtórzono 2026-07-31 dla Restica i Borga**.

Powtórzony przebieg dowodzi punktu spójności: źródłowy `webserver` był w stanie `exited` przez całe okno eksportu (sprawdzone `docker inspect`, nie samym kodem `stop`), eksporter działał w jednorazowym kontenerze Compose bez publikowanych portów i nie pozostawił po sobie kontenera, a liczba dokumentów przed i po oknie jest identyczna (`9`/`9`). Okno niedostępności źródła: `40 s`. Wszystkie `46` kontroli zakończyło się wynikiem OK.

W trakcie powtórzenia wykryto i naprawiono drugi błąd harnessu: obraz 3.0.4 startuje przez s6-overlay, więc przekazanie `document_exporter` jako CMD uruchamiało cały stack usług — z workerem i consumerem — zamiast eksportera. Szczegóły i przyjęte wywołanie: [`08-e3-backup-report.md`](08-e3-backup-report.md) §1.1.

**Gate OS-2-LAB: zamknięty w zakresie laboratoryjnym.** Storage nadal jest symulowany, więc gate potwierdza poprawność procedur, a nie gotowość produkcyjną. Pełny Gate OS-2 produktu pozostaje bramą M17.

### 4.3. Gate OS-3-LAB

Wszystkie kryteria spełnione — szczegóły w [`09-os3-lab-inventory.md`](09-os3-lab-inventory.md) §5.

**Gate OS-3-LAB: przechodzi.** OS-3-RELEASE pozostaje obowiązkową bramą M22.

---

## 5. Decyzje architektoniczne tej rundy

| ADR | Stan przed | Stan po | Uzasadnienie |
|---|---|---|---|
| **ADR-008** Valkey + BullMQ | `accepted`, topologia otwarta | `accepted`, **topologia rozstrzygnięta** | dwie osobne instancje; decyduje granica bounded context i izolacja awarii, nie RAM (~6 MiB różnicy) |
| **ADR-014** ORM | `accepted` | bez zmian | rozstrzygnięty w E2 |
| **ADR-015** narzędzie backupu | `proposed` | **`proposed`** | E3A (powtórzony) i E3B PASS dla obu kandydatów, ale kryterium storage off-host pozostaje nieocenione — rekomendacja wstępna: Restic |
| **ADR-016** polityka licencyjna | `proposed` | **`accepted`** | inwentarz OS-3-LAB kompletny, brak licencji nieakceptowalnej dla prywatnego laboratorium |
| **ADR-019** interfejs utrzymaniowy | `accepted` | potwierdzony | exporter/importer wywoływane wyłącznie operacyjnie, nigdy przez `DocumentProvider` |

---

## 6. Artefakty trwałe (plan §5)

| # | Artefakt | Stan |
|---|---|---|
| 1 | Manifest plików testowych | ✅ [`01-test-document-manifest.md`](01-test-document-manifest.md) |
| 2 | Wyniki pomiarów | ✅ [`02-resource-measurements.csv`](02-resource-measurements.csv) |
| 3 | Notatki o API | ✅ [`03-api-notes.md`](03-api-notes.md) |
| 4 | Skrypty E1, E3A i E3B | ✅ `lab/harness/e1/`, `lab/harness/e1-15/`, `lab/harness/e3/` — **artefakt domknięty** |
| 5 | Macierz kompatybilności | ✅ [`05-compatibility-matrix.md`](05-compatibility-matrix.md) |
| 6 | Raport decyzji i bram | ✅ ten dokument |
| 7 | Konfiguracja do powtórzenia | ✅ [`11-reproduction-config.md`](11-reproduction-config.md) |

---

## 7. Czy M3 jest zamknięty

**Nie.**

| Powód | Co odblokowuje |
|---|---|
| Brak rzeczywistych skanów papieru | dostarczenie `DOC-02`, `DOC-03`, `DOC-06` przez użytkownika |
| Gate OS-1 nie przechodzi | dostarczenie rzeczywistych skanów i pozytywny wynik OCR po frazie |
| ADR-015 `proposed` | dostarczenie dysków 4 TB i powtórzenie §3 planu na docelowym storage |

Zamknięte i niewymagające powtórzenia: E2, OS-3-LAB, topologia ADR-008 oraz techniczne tory E3A i E3B. **Gate OS-2-LAB jest zamknięty w zakresie laboratoryjnym** i nie blokuje już M3; otwarte pozostają wyłącznie rzeczywiste skany (OS-1) i test docelowego storage (ADR-015).
