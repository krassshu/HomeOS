# ADR-004 — PostgreSQL jako baza Core

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §9, `architecture/05-Open-Source-Architecture.md` §6, ADR-009 |

---

## Kontekst

Domena wymaga transakcji, dynamicznych pól, wyszukiwania pełnotekstowego i wieloużytkownikowego dostępu. Paperless posiada własną, odrębną bazę.

## Problem

Jaka baza przechowuje domenę Core i czy dzielić ją z Paperless.

## Decyzja

**PostgreSQL jest bazą Core i jedynym źródłem prawdy domeny.** Baza Paperless jest **odrębna** — Core jej nie czyta i nie modyfikuje.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Wspólna baza z Paperless | Prostszy backup, jedna instancja | Bardzo silne sprzężenie, ryzyko awarii po aktualizacji Paperless | 03 §9.2 — zakaz bezwzględny |
| SQLite | Zero administracji | Zbyt ograniczony dla systemu wieloużytkownikowego | 05 §6 |
| MySQL / MariaDB | Popularność | Brak istotnej przewagi; słabsze JSONB i FTS | 05 §6 |

## Konsekwencje pozytywne

- ACID, JSONB, FTS, `pg_trgm`, indeksy GIN, dojrzały backup.
- Model hybrydowy dynamicznych pól bez tworzenia kolumny na każde pole użytkownika.
- Wyszukiwanie domenowe bez dodatkowego silnika (ADR-009).

## Konsekwencje negatywne

- Dwie bazy oznaczają dwa dumpy i wymóg spójnego punktu w czasie przy backupie.
- Ryzyko niekontrolowanego JSONB (RY-25) — wymaga jawnej polityki w M4.
- Ciężkie migracje wymagają testu na kopii i planu rollbacku.

## Warunki ponownej analizy

- Wolumen danych przekracza możliwości jednej instancji na domowym sprzęcie.
- Pojawia się wymaganie replikacji lub wysokiej dostępności.

## Weryfikacja

Test architektury: brak połączenia z bazą Paperless w kodzie Core. Test migracji na pustej bazie i na bazie z danymi.
