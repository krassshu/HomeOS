# ADR-007 — Integracja aplikacyjna z Paperless wyłącznie przez oficjalne API

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | Nazwa „Document Gateway” z `architecture/03-Technology-Architecture.md` §13.1 |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/05-Open-Source-Architecture.md` §5.4, `workflows/06-System-Workflows.md` §11, `07-Product-and-Delivery-Roadmap.md` §11, §16, `architecture/discrepancy-register.md` R-17, ADR-019 |

---

## Kontekst

Paperless posiada bazę danych, katalog mediów i REST API. Dostęp do bazy lub do plików byłby szybszy, ale utrwaliłby zależność od wewnętrznych szczegółów komponentu.

## Problem

Jak Core komunikuje się z Paperless i jak ograniczyć zasięg tej zależności.

## Decyzja

**Komunikacja aplikacyjna Core z Paperless odbywa się wyłącznie przez oficjalne REST API, za portem `DocumentProvider`, którego jedyną produkcyjną implementacją jest `PaperlessAdapter`.** Port jest definiowany **przed** adapterem (brama M6 przed M11). Oficjalny exporter/importer, dump, backup i restore są interfejsem utrzymaniowym operatora poza Core, zgodnie z ADR-019; nie są wyjątkiem pozwalającym aplikacji czytać bazę ani katalog mediów.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Bezpośrednie zapytania do bazy Paperless | Szybsze odczyty | Zależność od schematu wewnętrznego, awarie po aktualizacji | Zakaz bezwzględny (05 §5.4) |
| Bezpośredni dostęp do katalogu mediów | Prostsze pobieranie plików | Omija model uprawnień Paperless, ryzyko niespójności | Zakaz bezwzględny |
| Adapter bez portu | Mniej kodu na start | Port powstałby jako opis implementacji i przestałby chronić przed lock-in | Kolejność M6 → M11 jest celowa |

## Konsekwencje pozytywne

- Cała wiedza o Paperless jest w jednym pliku — wymiana komponentu nie dotyka domeny.
- `FakeDocumentProvider` pozwala rozwijać pipeline uploadu równolegle z adapterem.
- Contract testy wykrywają zmiany API przed wdrożeniem na produkcję.

## Konsekwencje negatywne

- Niektóre operacje są wolniejsze niż zapytanie do bazy.
- Port trzeba utrzymywać jako osobny artefakt.
- Compatibility matrix wersji wymaga aktualizacji przy każdej zmianie Paperless.

## Warunki ponownej analizy

- API Paperless przestaje pokrywać wymaganą operację i nie ma obejścia zgodnego z tą decyzją.
- Wydajność odczytu staje się zmierzonym problemem produkcyjnym.

## Weryfikacja

**Test architektury w CI: żaden moduł poza `PaperlessAdapter` nie importuje typów Paperless ani nie zna jego URL-i.** Contract test suite. Gate OS-4.
