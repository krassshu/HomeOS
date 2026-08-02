# ADR-008 — Valkey + BullMQ jako broker i kolejka

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | Decyzję o Redis z `architecture/03-Technology-Architecture.md` §18, §27, §31 oraz `operations/04-Deployment-and-Infrastructure.md` §4, §8, §22, §45, §47 |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/05-Open-Source-Architecture.md` §7–§8, `architecture/discrepancy-register.md` R-01 |

---

## Kontekst

System wymaga zadań asynchronicznych: ingestion, poll, reconciliation, eksport, cleanup, notyfikacje. Dokumenty 03 i 04 wskazywały Redis; dokument 05 zastąpił go Valkey.

## Problem

Jaki broker i jaka biblioteka kolejek, przy założeniu pełnego open source i możliwej przyszłej dystrybucji.

## Decyzja

**Valkey jako broker (BSD, zgodny z protokołem Redis) oraz BullMQ (MIT) jako biblioteka kolejek.** Wszystkie wystąpienia „Redis” w dokumentach 03 i 04 należy czytać jako „Valkey”.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Redis | Największa popularność | Licencja utrudnia przyszłą dystrybucję | Zastąpiony przez Valkey (05 §7) |
| RabbitMQ | Lepszy przy złożonym routingu | Cięższy operacyjnie | Brak use case dla złożonego routingu |
| Kolejka w PostgreSQL | Mniej usług | Słabszy ekosystem i narzędzia | BullMQ daje gotowe retry, backoff, deduplikację |
| Temporal | Silne workflow | Zbyt ciężki dla MVP | 05 §8 |

## Konsekwencje pozytywne

- Valkey i BullMQ deklarują licencje permisywne, co ogranicza ryzyko licencyjne; pełna dystrybucja nadal wymaga Gate OS-3-RELEASE dla konkretnych wersji i zależności.
- BullMQ dostarcza retry z backoff, timeout, limit współbieżności, failed queue i deduplikację.
- Ten sam **typ brokera** może obsługiwać kolejkę Paperless i kolejkę Core; liczba instancji pozostaje do rozstrzygnięcia pomiarem E1.

## Konsekwencje negatywne

- Valkey jest młodszym projektem niż Redis — mniejsza baza doświadczeń.
- Wymaga korekty istniejących diagramów, Compose i nazw wolumenów (`data/valkey/`).
- **BullMQ Pro nie może stać się ukrytą zależnością architektury** bez osobnej decyzji.
- Awaria brokera zatrzymuje przetwarzanie (RY-27).

## Warunki ponownej analizy

- Valkey przestaje być aktywnie utrzymywany.
- Pojawia się wymaganie routingu wiadomości, którego BullMQ nie obsługuje.
- Pomiar w E1 wykazuje, że jedna instancja nie wystarcza — wtedy uzupełnienie tego ADR o topologię dwuinstancyjną.

## Weryfikacja

Valkey nie przechowuje jedynej kopii żadnych danych trwałych. Test „Valkey down”: odczyt Core działa, API nie udaje sukcesu, reconciliation odbudowuje zadania po powrocie.

---

## Uzupełnienie z 2026-07-31 — rozstrzygnięcie topologii (E1-14, E1-15)

**Status uzupełnienia:** rozstrzygnięte pomiarem laboratoryjnym M3. Podstawa: `../operations/spike-results/07-e1-15-valkey-topology.md`.

### Decyzja

**Dwie osobne instancje Valkey: jedna należąca do Paperless, druga do kolejki BullMQ Core.**

### Co zmierzono

Harness E1-15b wykonał sześć scenariuszy w obu topologiach, na tym samym obrazie Valkey `9-alpine@sha256:ee91f7a1…`, z tym samym obciążeniem:

| Scenariusz | Wspólny broker | Osobny broker |
|---|---|---|
| ten sam `jobId`, gdy job istnieje | 1 wykonanie | 1 wykonanie |
| ten sam `jobId` po `removeOnComplete` | 2 wykonania | 2 wykonania |
| kill workera w trakcie aktywnego zadania | 2 wykonania, 1 `stalled` | 2 wykonania, 1 `stalled` |
| wymuszony `stalled` i ponowne wykonanie | 2 wykonania | 2 wykonania |
| dwa wykonania, idempotentny zapis | 2 wykonania, **1 skutek** | 2 wykonania, **1 skutek** |
| usunięcie joba, reconciliation | intencja przetrwała, job odbudowany | intencja przetrwała, job odbudowany |

**Zachowanie funkcjonalne obu topologii jest identyczne.** Żaden scenariusz nie rozstrzyga wyboru.

### Dlaczego nie decyduje RAM

| Pomiar | Wartość |
|---|---|
| `used_memory` brokera Paperless w spoczynku | `2 463 880 B` (~2,35 MiB) |
| `used_memory` pustej drugiej instancji | `944 672 B` (~0,92 MiB) |
| RSS kontenera drugiej instancji w spoczynku | `6,09 MiB` |
| RSS kontenera brokera Paperless | `17,29 MiB` |

Druga instancja kosztuje około **6 MiB RSS** przy profilu 16 GB, czyli ~0,04 % pamięci hosta. Różnica jest nieistotna i zgodnie z planem E1 **nie jest** podstawą decyzji.

### Co faktycznie rozstrzyga

1. **Granica kontekstu (decydujące).** Broker Paperless jest szczegółem implementacyjnym Paperless. ADR-005 i ADR-007 ustalają integrację wyłącznie przez API, a zasada portów i adapterów zabrania sięgania do wewnętrznych magazynów cudzego systemu. Podpięcie kolejki Core do brokera Paperless byłoby obejściem tej granicy — niezależnie od tego, że technicznie działa.

2. **Izolacja awarii przy limicie pamięci.** E1-14 wykazał, że domyślna polityka to `noeviction`, a po osiągnięciu `maxmemory` broker odpowiada `OOM command not allowed when used memory > 'maxmemory'.` i **odmawia każdego zapisu**. We wspólnej instancji nasycenie pamięci przez jeden system zatrzymuje kolejki obu. Przy osobnych instancjach zasięg awarii kończy się na jednym systemie.

3. **Cichej utraty zadań nie wolno kupić za pamięć.** Ta sama próba pokazała, że polityka `allkeys-lru` usuwa dane bez błędu: przy `maxmemory=3mb` wyrzuciła `51` kluczy razem ze znacznikiem kontrolnym. Wspólna instancja zwiększa pokusę ustawienia polityki eksmisji „żeby się mieściło”, co dla brokera kolejki oznacza ciche gubienie zadań. Osobna instancja Core pozwala twardo utrzymać `noeviction`.

4. **Niezależny restart.** Aktualizacja albo restart Paperless nie może zrywać połączeń kolejki Core i odwrotnie. Przy wspólnej instancji każda operacja utrzymaniowa na brokerze dotyka obu systemów.

5. **Kolizje kluczy.** Zmierzono, że prefiks `homeos-core` i klucze `celery*` Paperless pozostają rozłączne — liczba kluczy Paperless nie zmieniła się (`12 → 12`) w żadnym przebiegu. Rozdzielność jest więc osiągalna konwencją, ale opiera się wyłącznie na dyscyplinie: pojedyncze `FLUSHALL`, `--scan | DEL` albo pomyłka w prefiksie dotyka wtedy cudzych danych. Osobna instancja czyni tę klasę błędów niemożliwą, zamiast jedynie mało prawdopodobną.

6. **Koszt operacyjny.** Osobna instancja to jeden kontener i jeden wolumen więcej do uruchomienia i monitorowania. Valkey nie przechowuje jedynej kopii danych trwałych, więc **nie zwiększa to zakresu backupu ani procedury odtwarzania** — koszt jest ograniczony do uruchamiania i obserwowalności.

### Konsekwencje

- Compose produktu definiuje dwie usługi Valkey: brokera Paperless (własność Paperless) i brokera Core.
- Kolejka Core używa własnego prefiksu również przy osobnej instancji — prefiks pozostaje drugą warstwą ochrony, nie jedyną.
- Broker Core pracuje z `maxmemory-policy=noeviction`. Progi alertów pamięci brokera należą do M19.
- Core nigdy nie łączy się z brokerem Paperless. Naruszenie tej zasady jest błędem architektonicznym, nie optymalizacją.

### Czego to uzupełnienie nie rozstrzyga

Pomiary wykonano przy obciążeniu laboratoryjnym, nie produkcyjnym. Progi pamięci, liczba kolejek i współbieżność wracają do weryfikacji w M17 i M19.
