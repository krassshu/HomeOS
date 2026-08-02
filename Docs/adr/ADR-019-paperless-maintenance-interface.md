# ADR-019 — Interfejs utrzymaniowy Paperless

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-28 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | ADR-007, ADR-015, `../architecture/05-Open-Source-Architecture.md` §5, `../operations/spike-plan.md` |

---

## Kontekst

Core komunikuje się z Paperless wyłącznie przez oficjalne REST API zgodnie z ADR-007. Paperless udostępnia jednak eksport i import instancji jako oficjalne polecenia administracyjne `document_exporter` i `document_importer`, a nie jako część REST API.

## Problem

Eksport/import jest niezbędny dla strategii wyjścia i restore, ale umieszczenie operacji `export` w porcie REST `DocumentProvider` tworzyłoby kontrakt, którego Paperless nie realizuje przez REST.

## Decyzja

**`DocumentProvider` zawiera wyłącznie operacje dostępne przez oficjalne REST API. Eksport, import, dump bazy, backup mediów i restore są operacjami utrzymaniowymi wykonywanymi poza Core przez oficjalne narzędzia administracyjne oraz runbook operatora.**

Kod domenowy i `PaperlessAdapter`:

- nie uruchamiają poleceń administracyjnych,
- nie czytają bazy ani katalogu mediów Paperless,
- nie uzależniają żądań użytkownika od eksportera,
- nie przechowują poświadczeń operatora.

Automatyzacja operacyjna może uruchamiać oficjalne polecenia w kontenerze Paperless, ale musi być oddzielona od aplikacji, audytowalna i opisana w runbooku.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| `export` w `DocumentProvider` | Jeden interfejs | Paperless nie udostępnia eksportu instancji przez REST; fałszywy kontrakt | Odrzucona |
| Własny endpoint eksportu w Core | Wygodne wywołanie | Core musiałby znać mechanikę utrzymaniową Paperless i przechowywać uprawnienia operatora | Odrzucona |
| Bezpośredni odczyt mediów i bazy | Szybki | Łamie ADR-007, zależy od wewnętrznego formatu | Zakazany |

## Konsekwencje pozytywne

- ADR-007 pozostaje prawdziwy dla całej komunikacji aplikacyjnej.
- Port `DocumentProvider` da się pokryć contract testami REST.
- Strategia wyjścia używa wspieranego eksportera/importera, a disaster recovery korzysta z jawnie odrębnego backupu baz i mediów.
- Uprawnienia utrzymaniowe nie trafiają do aplikacji.

## Konsekwencje negatywne

- Powstają dwa jawnie rozdzielone kontrakty: aplikacyjny i operacyjny.
- Test eksport/import nie jest częścią contract testów `PaperlessAdapter`.
- Runbook musi być aktualizowany przy zmianach poleceń administracyjnych Paperless.

## Warunki ponownej analizy

- Paperless udostępni stabilny, oficjalny REST API dla pełnego eksportu i importu.
- Automatyzacja backupu wymaga osobnej usługi z własnym API.

## Weryfikacja

- Contract test `DocumentProvider` nie wywołuje powłoki ani Docker API.
- E1 testuje REST Paperless 3.0.4 od zera i zapisuje OpenAPI pobrany z uruchomionej instancji 3.0.4; odpowiedzi i zachowania 2.x nie są fixture kontraktu.
- E3A tworzy pełny eksport narzędziem 3.0.4 i importuje go do pustej instancji 3.0.4 z tym samym digestem.
- E3B odtwarza logiczny dump bazy i media na instancji 3.0.4 z tym samym digestem; po restore uruchamia sanity checker i reconciliation.

## Źródła

- Oficjalna administracja Paperless-ngx: <https://docs.paperless-ngx.com/administration/>
- Oficjalna dokumentacja REST API Paperless-ngx: <https://docs.paperless-ngx.com/api/>
