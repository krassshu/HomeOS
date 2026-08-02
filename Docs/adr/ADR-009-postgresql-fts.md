# ADR-009 — PostgreSQL FTS przed osobnym silnikiem wyszukiwania

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | Komponent `S[Wyszukiwarka]` z `domain/01-Core-Domain-Model.md` §30 |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §19, `architecture/05-Open-Source-Architecture.md` §19, `architecture/discrepancy-register.md` R-08 |

---

## Kontekst

Wyniki wyszukiwania pochodzą z dwóch źródeł: domeny Core (nazwy, pola, tagi, notatki) i treści dokumentów (OCR w Paperless).

## Problem

Czy dodawać osobny silnik wyszukiwania, czy wykorzystać PostgreSQL i Paperless.

## Decyzja

**Wyszukiwanie domenowe realizuje PostgreSQL FTS z `pg_trgm`, `unaccent` i indeksami GIN. Treść dokumentów wyszukuje Paperless. Agregacja, filtrowanie uprawnieniami i scalanie rankingu odbywają się w NestJS.** Osobny silnik nie wchodzi do MVP.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Meilisearch | Prosty, dobra tolerancja literówek | Kolejna usługa, backup, aktualizacje, drugi indeks | Odłożony — wymaga mierzalnego problemu |
| OpenSearch | Bardzo rozbudowany | Ciężki operacyjnie na domowym sprzęcie | Jawnie poza MVP (07 §6) |
| Wspólny indeks dla Core i dokumentów | Jeden ranking | Duplikacja treści OCR poza Paperless, problem uprawnień | Narusza zasadę jednego właściciela danych |

## Konsekwencje pozytywne

- Zero dodatkowych usług, backupów i aktualizacji.
- Uprawnienia egzekwowane w jednym miejscu — po stronie Core, przed zwróceniem wyniku.
- Awaria Paperless degraduje wyszukiwanie do wyników domenowych z flagą `partial=true`, a nie do błędu.

## Konsekwencje negatywne

- Tolerancja literówek jest słabsza niż w dedykowanym silniku.
- Scalanie rankingu z dwóch źródeł wymaga własnej heurystyki.
- Zaawansowane facety byłyby kosztowne.

## Warunki ponownej analizy

- Zmierzony problem wydajności przy realnym wolumenie.
- Potrzeba dużych facetów lub setek tysięcy rekordów.
- Tolerancja literówek okazuje się niewystarczająca w pilocie (Faza 8).
- Pojawia się wymaganie wspólnego indeksu dla obu źródeł.

## Weryfikacja

Testy scenariuszy z `07-Product-and-Delivery-Roadmap.md` §12. **Test bezpieczeństwa: prywatny dokument nie pojawia się w wynikach nieuprawnionego użytkownika.**
