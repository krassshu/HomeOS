# ADR-001 — Monolit modułowy

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `domain/01-Core-Domain-Model.md` §33.15, `architecture/03-Technology-Architecture.md` §5, `07-Product-and-Delivery-Roadmap.md` §7 |

---

## Kontekst

Projekt jest rozwijany przez jedną osobę, działa na jednej maszynie i obsługuje jedno gospodarstwo domowe. Dokument 03 §7.3 szkicuje odległą przyszłość z osobnymi usługami, co bywa mylone z planem MVP.

## Problem

Czy dzielić system na usługi od początku, czy budować jeden proces z mocnymi granicami wewnętrznymi.

## Decyzja

**Budujemy monolit modułowy.** Jeden proces API, jeden lub kilka procesów worker, jedna domenowa baza PostgreSQL, jasno wydzielone moduły i osobny bounded context dokumentów realizowany przez Paperless.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Mikroserwisy od początku | Niezależne skalowanie i wdrożenia | Więcej wdrożeń, punktów awarii, koszt monitoringu, transakcje rozproszone, narzut sieciowy | Koszt operacyjny przekracza korzyść przy jednym operatorze i jednej maszynie; 07 §36 zakazuje wprost |
| Monolit bez granic modułów | Najszybszy start | Nieodwracalne sprzężenie, brak drogi do późniejszego podziału | Ryzyko RY-16 rozrostu monolitu bez możliwości refaktoryzacji |

## Konsekwencje pozytywne

- Jedno wdrożenie, jeden zestaw logów, jeden punkt diagnozy.
- Transakcje lokalne tam, gdzie to możliwe — brak sagi w domenie.
- Zachowana droga do późniejszego podziału, o ile granice są egzekwowane.

## Konsekwencje negatywne

- Łatwo o niekontrolowany rozrost, jeżeli granice nie są testowane (RY-16).
- Ciężkie operacje CPU nie mogą działać w procesie API.
- Skalowanie odbywa się przez procesy, nie przez niezależne usługi.

## Warunki ponownej analizy

- Zespół rośnie do poziomu, w którym równoległa praca na jednym repozytorium blokuje wydania.
- Moduł ma udokumentowany, odmienny profil zasobowy (np. AI/OCR), którego nie da się obsłużyć procesem worker.
- Pojawia się realne wymaganie niezależnego wdrażania części systemu.

## Weryfikacja

Test architektury w CI: zakaz importów do internals innych modułów; `packages/domain` bez zależności od ORM i frameworka.
