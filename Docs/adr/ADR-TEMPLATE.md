# ADR-NNN — <krótki tytuł decyzji>

| Pole | Wartość |
|---|---|
| **Status** | `draft` / `proposed` / `accepted` / `deprecated` |
| **Data** | RRRR-MM-DD |
| **Milestone** | M<n> |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | ADR-NNN, `dokument.md` §N |

---

## Kontekst

Co jest prawdą o systemie i o projekcie w momencie podejmowania decyzji. Fakty, nie opinie.

## Problem

Jakie pytanie wymaga rozstrzygnięcia i dlaczego nie można go zostawić otwartym.

## Decyzja

Jedno zdanie orzekające. Bez „powinniśmy rozważyć". Następnie szczegóły, jeżeli są potrzebne.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| | | | |

## Konsekwencje pozytywne

- …

## Konsekwencje negatywne

- …

Konsekwencje negatywne muszą być wypisane. ADR bez wad jest ADR-em nieprzemyślanym.

## Warunki ponownej analizy

Co konkretnie musiałoby się wydarzyć, żeby wrócić do tej decyzji. Warunek musi być **obserwowalny** — „gdyby okazało się to problemem" nie jest warunkiem.

- …

## Weryfikacja

Jak sprawdzamy, że decyzja jest respektowana w kodzie: test architektury, contract test, przegląd, brama.

---

## Zasady pisania ADR

1. **Jeden ADR = jedna decyzja.** Nie łączymy niepowiązanych rozstrzygnięć.
2. **ADR nie jest edytowany po przyjęciu.** Zmiana decyzji = nowy ADR + stary otrzymuje status `deprecated` i wskazanie następcy.
3. **Status `proposed` wymaga zapisanego warunku lub eksperymentu rozstrzygającego.** Nie zostawiamy propozycji bez ścieżki do decyzji.
4. **Decyzja o wysokim koszcie odwrócenia wymaga ADR.** Decyzja łatwo odwracalna — niekoniecznie.
5. Nowy komponent technologiczny wymaga ADR **oraz** przejścia procesu z `architecture/05-Open-Source-Architecture.md` §24.
