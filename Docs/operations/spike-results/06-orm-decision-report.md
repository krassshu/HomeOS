# E2 — raport wyboru ORM

**Status:** `accepted — E2 zakończony na VM linux/amd64 2026-07-30`

## Baseline

| Element | Wersja |
|---|---|
| Node.js | `24.18.0` |
| npm | `11.16.0` |
| PostgreSQL | `18.4` |
| Drizzle ORM / Kit | `0.45.2` / `0.31.10` |
| Prisma CLI / Client | `7.9.1` / `7.9.1` |

Oba PoC używają wspólnego kontraktu z
`../../../lab/e2/shared/contract.md`, tych samych fixture i tych samych
asercji.

## Warunki blokujące

| Próba | Drizzle | Prisma | Dowód |
|---|---|---|---|
| E2-01 — model hybrydowy | PASS | PASS | tekst, liczba i boolean odczytane bez utraty typu |
| E2-02 — atomowa transakcja | PASS | PASS | wymuszony wyjątek pozostawił 0 obiektów i 0 wpisów audytu |
| E2-03 — audit z diff | PASS | PASS | zmiana tytułu i drugi wpis audytu |
| E2-04 — PostgreSQL FTS | PASS | PASS | `unaccent`, `pg_trgm`, dwa indeksy GIN, dokładna fraza i literówka |
| E2-05 — migracja `up → down → up` | PASS | PASS | licznik obiektów `1 → 1`, po drugim `up` kolumna miała `NULL` |
| E2-06 — dump/restore i ponowne asercje | PASS | PASS | 1 obiekt, 2 wpisy audytu i historia migracji po restore |
| E2-07 — optimistic concurrency | PASS | PASS | pierwszy zapis przeszedł, zapis ze starą wersją został odrzucony |
| Domena bez importów ORM | PASS | PASS | automatyczny skan `shared/domain/` |

Kandydat z dowolnym niespełnionym warunkiem nie przechodzi do punktacji.

## Walidacja lokalna

Próbę wykonano 2026-07-30 w kontenerach Linux `arm64` na Docker Desktop.
Użyto przypiętego obrazu Node oraz przypiętego obrazu PostgreSQL z manifestu
M3. Dla każdego kandydata utworzono osobną bazę i osobny czysty cel restore.
Oba przebiegi zakończyły się:

```text
drizzle/fresh: PASS [E2-01, E2-02, E2-03, E2-04, E2-05, E2-07]
drizzle/restore: PASS [E2-06]
prisma/fresh: PASS [E2-01, E2-02, E2-03, E2-04, E2-05, E2-07]
prisma/restore: PASS [E2-06]
```

Tymczasowy kontener, sieć, wolumen zależności i dumpy zostały po próbie
usunięte. Wynik dowodzi poprawności konstrukcji laboratorium, ale nie
zastępuje powtórzenia na docelowej VM `linux/amd64`.

Prisma 7.9.1 zgłosiła ostrzeżenie o niewykryciu OpenSSL w obrazie `slim`,
jednak generowanie klienta, migracja, wszystkie zapytania i restore
zakończyły się poprawnie.

## Walidacja na VM

Próbę autorytatywną wykonano 2026-07-30 na docelowej VM `linux/amd64` z
Node.js `24.18.0` oraz PostgreSQL `18.4`. Wynik był identyczny z walidacją
lokalną:

```text
drizzle/fresh: PASS [E2-01, E2-02, E2-03, E2-04, E2-05, E2-07]
drizzle/restore: PASS [E2-06]
prisma/fresh: PASS [E2-01, E2-02, E2-03, E2-04, E2-05, E2-07]
prisma/restore: PASS [E2-06]
```

Prisma ponownie zgłosiła ostrzeżenie OpenSSL, ale nie wpłynęło ono na
generowanie klienta, migrację, zapytania ani restore. Cztery ostrzeżenia
`npm audit` pochodzą z deweloperskiego łańcucha Drizzle Kit do starego
`esbuild`; zależności uruchomieniowe mają wynik `0 vulnerabilities`.

## Punktacja kandydatów spełniających warunki

| Wymiar | Waga | Drizzle 0–5 | Prisma 0–5 | Uzasadnienie |
|---|---:|---:|---:|---|
| PostgreSQL i obejścia | 30% | 4,5 | 3,5 | Drizzle deklaruje `tsvector` i oba indeksy w schemacie; Prisma wymaga `Unsupported("tsvector")` i szerszej migracji ręcznej |
| Migracje | 25% | 4,0 | 4,0 | Oba narzędzia zachowały dane i historię po restore; oba wymagają jawnego SQL dla odwracalnego DDL |
| Sprzężenie i testowalność | 20% | 5,0 | 5,0 | Wspólna domena i asercje nie importują ORM |
| Bezpieczeństwo typów | 15% | 4,5 | 4,0 | Oba są typowane; `Unsupported` i ręcznie typowane wyniki raw query poszerzają lukę po stronie Prisma |
| Diagnostyka i ergonomia | 10% | 3,5 | 4,0 | Prisma ma czytelniejszy raport migracji; Drizzle jest bardziej oszczędny, ale oba wymagają znajomości SQL |
| **Wynik ważony** | **100%** | **87,5%** | **81,0%** | `ocena / 5 × waga` |

## Decyzja

Punktacja techniczna wskazała Drizzle: 87,5% wobec 81,0% Prisma. Wynik ten
pozostaje częścią dowodu i nie jest przeliczany po poznaniu rezultatu.

Podczas przeglądu decyzji ujawniono brak kryterium istotnego dla
długowiecznego archiwum domowego: przewidywalności utrzymania upstream.
Obaj kandydaci przeszli wszystkie warunki blokujące, dlatego uwzględnienie
tego kryterium nie akceptuje rozwiązania niespełniającego wymagań
technicznych.

| Kryterium strategiczne | Drizzle | Prisma |
|---|---|---|
| Stan projektu | aktywny; stabilna linia `0.45.x`, równolegle rozwijane `1.0 RC` | stabilna linia produkcyjna `7.x` |
| Deklaracja wsparcia | brak przyjętej w projekcie polityki LTS | jawna deklaracja Prisma 7 jako produkcyjnego LTS |
| Model utrzymania | mniejszy zespół i rozwój społecznościowy | firma, regularne wydania i dostępny support enterprise |
| Koszt ograniczeń PostgreSQL | niższy | wyższy, ale wszystkie wymagane obejścia przeszły E2 |
| Preferencja właściciela | nie | **tak — priorytetem jest wieloletnie wsparcie** |

Ostatecznie wybrano **Prisma ORM**. Raw SQL pozostaje dozwolony i wymagany
dla `tsvector`, GIN, `pg_trgm` i `unaccent`; E2 potwierdził poprawność tych
obejść, migracji oraz restore.

Przed użyciem w M9 należy ponownie sprawdzić aktualne stabilne wersje i
ostrzeżenia bezpieczeństwa oraz przygotować obraz z wykrywalnym OpenSSL.
Nie zmienia to wyniku E2 dla badanego baseline.
