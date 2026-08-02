# ADR-014 — Wybór ORM

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Data decyzji** | 2026-07-30 |
| **Milestone** | M3 (wybór), M9 (użycie w fundamencie) |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §10, `07-Product-and-Delivery-Roadmap.md` §36.5, ADR-004 |

---

## Kontekst

Model danych obejmuje dynamiczne pola w modelu hybrydowym, transakcje, audit z diff, indeksy FTS z `pg_trgm` i `unaccent` oraz migracje. Zmiana ORM po zbudowaniu warstwy danych oznacza jej przepisanie.

## Problem

Który ORM udźwignie zaawansowane konstrukcje PostgreSQL bez sprzęgania domeny z frameworkiem.

## Decyzja

Wybrano **Prisma ORM** jako warstwę persistence używaną od M9. Raw SQL jest
jawnie dozwolony tam, gdzie jest czytelniejszy albo wymagany przez funkcje
PostgreSQL, w szczególności FTS, `pg_trgm` i `unaccent`.

> **Status `accepted`.** Eksperyment E2 wykonano osobno dla Drizzle i Prisma
> na identycznym modelu, danych i asercjach, bez udziału Paperless. Obaj
> kandydaci przeszli E2-01…E2-07 oraz dump/restore. Techniczna punktacja
> wyniosła 87,5% dla Drizzle i 81,0% dla Prisma. Ponieważ oba rozwiązania
> spełniły wymagania blokujące, właściciel projektu wybrał Prisma ze względu
> na jawny kierunek LTS, model utrzymania i priorytet wieloletniego wsparcia.
> Pełny raport: `../operations/spike-results/06-orm-decision-report.md`.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Drizzle | Blisko SQL, mocne typowanie, mniejsza abstrakcja, dobre dopasowanie do PostgreSQL | Stabilna linia nadal przed 1.0; mniejsza przewidywalność długoterminowego wsparcia | Odrzucony decyzją strategiczną; przeszedł wszystkie warunki blokujące i wygrał punktację techniczną |
| Prisma | Bardzo dobry DX, generowane typy, jawny kierunek LTS i instytucjonalne wsparcie | `Unsupported("tsvector")`, szersza ręczna migracja dla FTS, wymóg bibliotek OpenSSL | **Wybrany po E2 i przeglądzie ryzyka utrzymania** |
| MikroORM / TypeORM | Klasyczne encje, integracja z NestJS | **Ryzyko niejawnych zapytań i sprzężenia domeny z ORM** | Odradzane (03 §10) |

## Konsekwencje pozytywne

- Decyzja podjęta na podstawie zmierzonego zachowania, nie na podstawie dokumentacji.
- Wybrany ORM ma jawny kierunek produkcyjnego LTS i regularny model wydań.
- Domena nie importuje Prisma; zależność pozostaje w adapterze persistence.
- Wymagane obejścia PostgreSQL zostały sprawdzone wraz z migracją i restore.

## Konsekwencje negatywne

- PoC kosztuje czas w Fazie 1.
- Wybór jest trudny do odwrócenia po M10.
- `tsvector` nie jest w pełni modelowany przez Prisma i wymaga
  `Unsupported` oraz jawnego SQL.
- Obraz uruchomieniowy musi zawierać wspieraną bibliotekę OpenSSL.
- Techniczna punktacja E2 faworyzowała Drizzle; Prisma wybrano świadomie ze
  względu na długoterminowy profil ryzyka.

## Warunki ponownej analizy

- Prisma przestaje wspierać wymaganą konstrukcję PostgreSQL i nie ma
  bezpiecznego, jawnego obejścia.
- Zależności narzędzia migracji mają podatność istotną dla sposobu użycia w
  produkcie i nie istnieje zgodna aktualizacja.
- Wyniki prób migracji lub optimistic concurrency przestają przechodzić po
  aktualizacji wymaganej przed M9.
- Zmienia się deklarowany model LTS lub utrzymanie Prisma przestaje zapewniać
  oczekiwaną przewidywalność.

## Weryfikacja

E2 wykonano na Node.js `24.18.0`, PostgreSQL `18.4`, Drizzle ORM `0.45.2` /
Kit `0.31.10` i Prisma `7.9.1`. Obaj kandydaci przeszli model hybrydowy,
atomową transakcję, audit z diff, FTS, `up → down → up`, optimistic
concurrency oraz `pg_dump`/restore z ponowieniem wspólnych asercji.
Automatyczny test potwierdził brak importów ORM w domenie. Przed M9 należy
powtórzyć próbę na wybranej stabilnej wersji Prisma i obrazie z poprawnie
wykrywanym OpenSSL.
