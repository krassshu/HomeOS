# ADR-018 — Audit policy

| Pole | Wartość |
|---|---|
| **Status** | `proposed` |
| **Data** | 2026-07-27 |
| **Milestone** | M5 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `workflows/06-System-Workflows.md` §3.5, §37, `domain/02-Object-Model.md` §28 |

---

## Kontekst

System zawiera dokumenty medyczne, finansowe i dane tożsamości. Audit musi umożliwiać odtworzenie biegu zdarzeń, nie stając się przy tym drugim miejscem wycieku danych wrażliwych.

## Problem

Co dokładnie rejestrujemy, czego nie rejestrujemy i jak długo przechowujemy zapisy audytowe.

## Decyzja

**Propozycja:** rejestrujemy co najmniej 19 zdarzeń z
`workflows/06-System-Workflows.md` §37: 16 bazowych oraz 3 dotyczące ujawnienia
i dostępu do wartości wrażliwej. Każde zawiera actor, workspace, target,
timestamp, correlation ID, result, sesję, urządzenie, klienta i transport.
Audit **nie zawiera sekretów ani całych treści dokumentów**. Dokładne zwykłe
wartości należą do historii obiektu; wartości wrażliwe są redagowane bez treści
i bez skrótu. Permanent delete usuwa treść historii, pozostawiając strukturę
zdarzeń i tombstone. Po usunięciu samego konta nazwa może pochodzić z
zachowanej osoby; po pełnym usunięciu osoby audit wyświetla niezmienny
identyfikator i pseudonim bez danych osobowych. Katalog zdarzeń rozszerza się
jawnie wraz z pozostałymi procesami MVP. **Audit domenowy nie może być
wyłącznie logiem Docker.**

> **Status `proposed`.** Domykany w M5 wraz z modelem uprawnień i prywatności.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Audit pełnych wartości pól | Pełna odtwarzalność zmian | Drugie miejsce przechowywania danych medycznych i finansowych | Nieakceptowalne bez dodatkowych zabezpieczeń |
| Tylko log techniczny | Mniej pracy | Brak historii domenowej, brak rozliczalności | Wykluczone (04 §32) |
| Audit bez correlation ID | Prostszy zapis | Niemożliwe powiązanie zdarzeń jednego procesu | Utrudnia diagnozę rozjazdów |

## Konsekwencje pozytywne

- Rozliczalność działań bez tworzenia drugiego repozytorium danych wrażliwych.
- Correlation ID pozwala prześledzić cały proces przez API, kolejkę i adapter.
- Historia obiektu jest funkcją produktu, nie tylko narzędziem diagnostycznym.

## Konsekwencje negatywne

- Ograniczenie wartości wrażliwych w audycie zmniejsza odtwarzalność części zmian.
- Retencja audytu wymaga decyzji i wpływu na rozmiar bazy.
- Diff dla dynamicznych pól wymaga własnej implementacji.

## Warunki ponownej analizy

- **Warunek domknięcia:** macierz uprawnień i rozstrzygnięcie 7 trudnych przypadków w M5.
- Po przyjęciu: pojawia się wymaganie prawne dotyczące retencji lub zakresu audytu.

## Weryfikacja

Test: logi i audit nie zawierają sekretów. Przegląd: każde z 19 zdarzeń ma
miejsce powstania w kodzie, a trzy zdarzenia wartości wrażliwej nie zapisują
treści ani skrótu.
