# ADR-006 — Paperless właścicielem binariów dokumentów na MVP

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | Rozwiązanie z `domain/01-Core-Domain-Model.md` §30 (`FS[(Magazyn plików)]` jako komponent Core) |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §12.1, `architecture/05-Open-Source-Architecture.md` §28, ADR-005, ADR-013, `architecture/discrepancy-register.md` R-02 |

---

## Kontekst

Dokument może być przechowywany przez Core, przez Paperless albo przez oba. Wybór determinuje zakres backupu, tryb degradacji i strategię wyjścia.

## Problem

Kto jest właścicielem binarnego pliku dokumentu.

## Decyzja

**Paperless jest właścicielem plików dokumentowych, Core właścicielem ich kontekstu.** Core przechowuje `DocumentReference` ze stabilnym identyfikatorem zewnętrznym oraz `DocumentProjection` z kluczowymi metadanymi. Assety Core (avatary, zdjęcia obiektów, ikony, eksporty) pozostają po stronie Core za portem `ObjectStorageProvider`.

Tymczasowy, szyfrowany staging uploadu po stronie potoku ingestion nie jest drugim trwałym właścicielem. Plik pozostaje w kwarantannie tylko do terminalnego potwierdzenia utworzenia dokumentu w Paperless albo do kontrolowanego zakończenia obsługi błędu. Po sukcesie jest usuwany. Wymóg ten został potwierdzony przez FAIL E1-13: restart Paperless w trakcie OCR może pozostawić zadanie `started` i utracić przyjęte wejście.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Core przechowuje oryginał, Paperless kopię | Większa niezależność od Paperless | Podwójny storage, duplikacja, trudna synchronizacja | 03 §12.1 — nierekomendowana na start |
| Core przechowuje wszystko, Paperless tylko OCR | Pełna kontrola nad plikami | Rezygnacja z większości pipeline'u Paperless | Znosi główną korzyść z ADR-005 |

## Konsekwencje pozytywne

- Brak podwójnego storage i brak problemu synchronizacji dwóch kopii.
- Wykorzystanie pełnego pipeline'u: OCR, archive PDF, miniatura, indeks.
- Szybsze MVP i mniej własnego kodu.

## Konsekwencje negatywne

- Backup **musi** obejmować dwa systemy w spójnym punkcie czasu.
- Migracja poza Paperless wymaga eksportu (strategia wyjścia).
- Core musi obsługiwać niedostępność Paperless w trybie zdegradowanym.
- Potok ingestion wymaga ograniczonego retencją stagingu, timeoutu i bezpiecznego cleanupu; nie wolno traktować samego `task_id` Paperless jako gwarancji trwałości wejścia.
- Utrata mediów Paperless jest utratą dokumentów — stąd waga ADR-015.

## Warunki ponownej analizy

- Eksport Paperless okazuje się niewystarczający do odtworzenia dokumentów.
- Pojawia się wymaganie prawne przechowywania oryginałów pod kontrolą aplikacji.
- Gate OS-2-LAB lub pełny Gate OS-2 w M17 nie przechodzi.

## Weryfikacja

Gate OS-2-LAB w M3 i pełny Gate OS-2 w M17. Tabela właścicieli danych w `architecture/05-Open-Source-Architecture.md` §28. Test: odtworzenie dokumentu z backupu i weryfikacja checksum.
