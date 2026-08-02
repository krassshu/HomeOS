# ADR-016 — Polityka licencyjna

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27, przyjęty 2026-07-31 po Gate OS-3-LAB |
| **Milestone** | M3 (polityka i inwentarz laboratorium), M22 (pełna brama wydania) |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §26, `architecture/05-Open-Source-Architecture.md` §23, ADR-005 |

---

## Kontekst

Paperless-ngx jest na licencji GPLv3. Deklaracje licencji pozostałych komponentów i każdej zależności trzeba sprawdzać dla **konkretnych, przypiętych wersji**; nie wolno zakładać ich na podstawie nazwy projektu. Samo uruchamianie niezmodyfikowanego programu GPL prywatnie, bez przekazywania kopii innym podmiotom, co do zasady nie uruchamia obowiązków związanych z dystrybucją. Dystrybucja obrazów, instalatora lub zmodyfikowanych kopii jest odrębnym przypadkiem.

## Problem

Jakie zobowiązania licencyjne wynikają z przyjętego stosu i jakie warunki muszą być spełnione przed ewentualną dystrybucją.

## Decyzja

**Propozycja:** integracja z Paperless przez udokumentowane interfejsy, bez kopiowania jego kodu do Core; prowadzenie `THIRD_PARTY_NOTICES.md`; generowanie SBOM (CycloneDX lub SPDX); license scan w CI; rejestr zależności z polami `name`, `version`, `source`, `license`, `digest`, `usage`, `modified`, `distributed`, `notice`.

> **Status `accepted` od 2026-07-31.** Gate OS-3-LAB przeszedł: wersjonowany inwentarz wszystkich faktycznie użytych komponentów laboratorium — z wersją, tagiem, digestem, architekturą, zadeklarowaną licencją, sposobem użycia oraz informacją o modyfikacji i dystrybucji — jest zapisany w [`../operations/spike-results/09-os3-lab-inventory.md`](../operations/spike-results/09-os3-lab-inventory.md). Żaden komponent nie został zmodyfikowany ani dystrybuowany, NOTICE Apache Tika jest zachowany, i **nie stwierdzono licencji nieakceptowalnej dla prywatnego użycia laboratoryjnego**. Przyjęcie dotyczy wyłącznie laboratorium. Pełna zgodność wydaniowa jest weryfikowana ponownie przez Gate OS-3-RELEASE w M22. **Plan przekazywania kopii osobom trzecim, publikacji obrazów, modyfikacji Paperless lub monetyzacji wymaga formalnego przeglądu licencyjnego dla konkretnego sposobu dostarczenia** — ten ADR nie jest poradą prawną.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Rezygnacja z Paperless ze względu na GPLv3 | Brak zobowiązań copyleft | Utrata najdroższego fragmentu funkcjonalności | Nieuzasadnione przy użyciu prywatnym |
| Brak formalnej polityki | Mniej pracy | Ryzyko prawne przy dystrybucji, brak SBOM | Dyskwalifikujące — Gate OS-3-LAB / OS-3-RELEASE |

## Konsekwencje pozytywne

- Granica procesu i udokumentowane API zmniejszają sprzężenie techniczne oraz ułatwiają oddzielną ocenę utworów, ale **same nie stanowią gwarancji kwalifikacji prawnej**.
- SBOM i notices są wymagane przez release criteria niezależnie od licencji.

## Konsekwencje negatywne

- Rejestr zależności wymaga utrzymania przy każdej zmianie.
- Przyszła komercjalizacja wymaga przeglądu prawnego — koszt i czas.

## Warunki ponownej analizy

- Pojawia się zamiar dystrybucji, publikacji lub monetyzacji produktu.
- Komponent zmienia licencję.
- **Warunek domknięcia ADR:** Gate OS-3-LAB — inwentarz licencji, źródeł, wersji i digestów wszystkich obrazów oraz narzędzi użytych w laboratorium; GPLv3 i prywatny model użycia zapisane; brak licencji niezaakceptowanej dla tego użycia.
- **Warunek wydania M22:** Gate OS-3-RELEASE dla kompletnego produktu, wszystkich zależności bezpośrednich i przechodnich, obrazów oraz sposobu dostarczenia.

## Weryfikacja

- **Gate OS-3-LAB (M3):** wersjonowany inwentarz komponentów laboratorium z licencją, źródłem i digestem; udokumentowany model użycia; brak niezaakceptowanej licencji.
- **Gate OS-3-RELEASE (M22):** aktualny SBOM, `THIRD_PARTY_NOTICES.md`, wynik skanowania licencji, zachowane teksty i informacje wymagane przez licencje, źródła/oferty źródła tam, gdzie są wymagane, oraz przegląd sposobu dystrybucji.
- License scan w CI od M9 jest kontrolą pomocniczą, nie zastępuje analizy obowiązków konkretnej licencji.

## Źródła

- Licencja repozytorium Paperless-ngx: <https://github.com/paperless-ngx/paperless-ngx/blob/main/LICENSE>
- FAQ GNU dotyczące używania i przekazywania programów GPL: <https://www.gnu.org/licenses/gpl-faq.html.en>
