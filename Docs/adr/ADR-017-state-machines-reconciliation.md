# ADR-017 — State machines i reconciliation

| Pole | Wartość |
|---|---|
| **Status** | `proposed` |
| **Data** | 2026-07-27 |
| **Milestone** | M4 |
| **Zastępuje** | Listę 8 stanów z `architecture/03-Technology-Architecture.md` §13.2 |
| **Zastąpiony przez** | — |
| **Powiązane** | `workflows/06-System-Workflows.md` §4, §12, §22, §32–§34, `architecture/discrepancy-register.md` R-19 |

---

## Kontekst

Core i Paperless nie uczestniczą w jednej transakcji. Spójność zapewniają: zapis intencji, state machine, kolejka, retry, reconciliation i kompensacja.

## Problem

Jak zapewnić spójność między Core a Paperless bez transakcji rozproszonej i jak wykrywać oraz naprawiać rozjazdy.

## Decyzja

**Propozycja:** każda zmiana stanu dokumentu jest walidowana przez **14-stanową state machine** z `workflows/06-System-Workflows.md` §12, a nie przez zapis pola. Reconciliation obsługuje **7 klas rozjazdów**: `core_pending_external_ready`, `core_ready_external_missing`, `metadata_drift`, `checksum_mismatch`, `orphan_external`, `orphan_core`, `duplicate_external_ref`. Rozjazdy bezpieczne są naprawiane automatycznie, niebezpieczne oznaczane do decyzji ręcznej.

FAIL E1-13 dodaje obowiązkowy kontrakt dla ingestion: trwała intencja istnieje przed wysłaniem pliku; wejście pozostaje w tymczasowym, szyfrowanym stagingu do terminalnego potwierdzenia; nieterminalne zadanie Paperless ma skończony timeout; retry używa tego samego klucza idempotencji i checksum; reconciliation odbudowuje utracony job albo kieruje intencję do manual review. Cleanup stagingu następuje dopiero po potwierdzeniu sukcesu lub jawnej decyzji zgodnej z retencją. Ten ADR nie ustala limitu ani retencji kwarantanny i nie rozstrzyga zachowania przy długiej niedostępności Paperless — to zakres osobnego ADR G4-06 przed M12.

> **Status `proposed`.** Domykany w M4 (model danych) i M6 (kontrakt integracji).

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Zapis stanu bez maszyny stanów | Prostsze | Nieprawidłowe przejścia, trudna diagnoza | Ryzyko RY-02 |
| Transakcja rozproszona / two-phase commit | Silna spójność | Niewykonalne przy REST API Paperless | Wykluczone przez ADR-007 |
| Saga z kompensacją dla każdego kroku | Pełna odwracalność | Znaczna złożoność przy jednym operatorze | Nadmiarowe dla MVP |

## Konsekwencje pozytywne

- Nieprawidłowe przejścia stanów są wykrywane, nie zapisywane.
- Reconciliation naprawia rozjazdy powstałe po awarii bez ręcznej interwencji w typowych przypadkach.
- Klasy rozjazdów dają mierzalną metrykę `reconciliation drift`.

## Konsekwencje negatywne

- Więcej kodu niż prosty zapis pola.
- Reconciliation wymaga własnych testów i raportu.
- Przypadki niejednoznaczne wymagają ręcznej decyzji administratora.
- Tymczasowy staging wymaga limitu pojemności, retencji, szyfrowania i monitorowania osieroconych plików.

## Warunki ponownej analizy

- **Warunek domknięcia:** model danych (M4) i kontrakt integracji (M6).
- Po przyjęciu: pojawia się klasa rozjazdu spoza siedmiu zdefiniowanych.

## Weryfikacja

Test: restart workera nie tworzy duplikatu ani nie gubi wejścia (brama M12). Test kontraktowy odtwarza E1-13 i potwierdza timeout, zachowanie staged original, idempotentne ponowienie oraz cleanup po sukcesie. Test „Paperless usunął, Core nie zapisał sukcesu” jest finalizowany przez reconciliation.
