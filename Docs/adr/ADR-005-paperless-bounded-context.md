# ADR-005 — Paperless-ngx jako Document Bounded Context

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §12, `architecture/05-Open-Source-Architecture.md` §5, ADR-006, ADR-007, `architecture/discrepancy-register.md` R-02, R-03 |

---

## Kontekst

OCR, ekstrakcja tekstu, generowanie miniatur, archiwalne PDF i indeksowanie treści to najdroższy fragment segregatora. Dokument 01 zakładał własny magazyn plików i OCR w fazie 5.

## Problem

Czy budować własny pipeline dokumentowy, czy wykorzystać dojrzały komponent open source.

## Decyzja

**Paperless-ngx jest wewnętrznym silnikiem dokumentów i osobnym bounded contextem.** Odpowiada za przyjęcie dokumentu, oryginał, archiwalny PDF, OCR, miniatury, indeks treści, techniczne metadane oraz własny model tagów, korespondentów i typów. Core odpowiada za kontekst, znaczenie, prywatność, relacje i audyt.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Własny pipeline dokumentowy | Pełna kontrola | Najwyższy koszt, konieczność napisania OCR i parserów | Sprzeczne z filozofią projektu (05 §5.8) |
| Mayan EDMS | Bogatszy workflow | Większy koszt operacyjny | Strategia wyjścia, gdyby Gate OS-1 nie przeszedł |
| Docspell / Teedy | Alternatywne DMS | Wymagają osobnego porównania API, OCR, aktywności i eksportu | Do rozważenia dopiero po niepowodzeniu Gate OS-1 |

## Konsekwencje pozytywne

- Rozwiązuje najdroższy fragment produktu bez pisania własnego OCR.
- Self-hosted, aktywnie rozwijany, z REST API i Docker Compose.
- OCR wchodzi do MVP zamiast do odległej fazy 5 (R-03).

## Konsekwencje negatywne

- Druga baza i drugi storage — backup obejmuje dwa systemy.
- Synchronizacja dwóch modeli i ryzyko rozjazdu (RY-02).
- Licencja GPLv3 wymaga przeglądu przed dystrybucją (ADR-016).
- Zmiany API wymagają contract testów i kontrolowanych aktualizacji (RY-13).
- Krytyczna zależność — Core musi obsługiwać jego niedostępność.

## Warunki ponownej analizy

- **Gate OS-1 nie przechodzi** — brak wymaganej operacji REST lub sprawdzonego fallbacku.
- Eksport/import utrzymaniowy jest niewystarczający albo Gate OS-2-LAB / pełny Gate OS-2 nie przechodzi.
- Zmiana licencji lub porzucenie projektu przez upstream.
- Zużycie zasobów wyklucza pracę na docelowym sprzęcie.

## Weryfikacja

E1 zamyka Gate OS-1, a E3A i E3B wspólnie zamykają Gate OS-2-LAB w M3. Pełny Gate OS-2 produktu jest powtarzany w M17. Gate OS-4 jest weryfikowany przez port, zakaz dostępu do bazy/mediów, contract testy i próbny eksport.
