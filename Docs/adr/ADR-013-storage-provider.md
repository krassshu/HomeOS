# ADR-013 — Storage provider dla assetów Core

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §20, `architecture/05-Open-Source-Architecture.md` §18, ADR-006, `architecture/discrepancy-register.md` R-09 |

---

## Kontekst

Dokumenty należą do Paperless (ADR-006). Core potrzebuje miejsca na assety własne: avatary, zdjęcia obiektów, ikony i eksporty. MinIO był rozważany jako S3-compatible storage.

## Problem

Gdzie Core przechowuje własne assety i czy potrzebny jest storage obiektowy.

## Decyzja

**Lokalny filesystem za portem `ObjectStorageProvider`.** MinIO jest odłożone do czasu wystąpienia mierzalnej potrzeby. Decyzja dotyczy wyłącznie assetów Core; dokumenty pozostają własnością Paperless.

Decyzja jest przyjęta przed E1, ponieważ nie zależy od API Paperless, jest łatwo odwracalna dzięki portowi i usuwa niewykonalne wymaganie testowania produkcyjnych assetów Core przed powstaniem modelu danych.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| MinIO | S3-compatible, gotowe SDK | Kolejna usługa krytyczna, backup, aktualizacje | Odłożone — brak realnej potrzeby na MVP (05 §18) |
| Assety w bazie jako BLOB | Jeden backup | Rozrost bazy, gorsza wydajność | Niepotrzebne przy małych assetach |
| Assety w Paperless | Jeden system plików | Miesza dokumenty z assetami UI, narusza granice | Sprzeczne z ADR-005 |

## Konsekwencje pozytywne

- Zero dodatkowych usług na MVP.
- Port istnieje od początku — migracja do S3 nie dotyka domeny.
- Prostszy backup: katalog obok pozostałych danych.

## Konsekwencje negatywne

- Brak wbudowanej replikacji i wersjonowania obiektów.
- Uprawnienia plikowe wymagają poprawnego UID/GID w kontenerach.
- Skalowanie poza jeden host wymagałoby zmiany implementacji portu.

## Warunki ponownej analizy

- Wolumen assetów przekracza możliwości lokalnego filesystemu.
- Pojawia się wymaganie dostępu do assetów z wielu hostów.
- Pomiary E3B lub M17 wykażą, że lokalny filesystem utrudnia spójny backup albo restore.

## Weryfikacja

E3B używa laboratoryjnego fixture assetów i potwierdza, że katalog daje się odtworzyć wraz z checksumami. Pełny eksport Workspace jest weryfikowany po powstaniu Core w M17.
