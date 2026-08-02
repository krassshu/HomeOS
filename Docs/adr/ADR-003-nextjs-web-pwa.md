# ADR-003 — Next.js jako web i PWA

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §6, `architecture/05-Open-Source-Architecture.md` §13, ADR-002 |

---

## Kontekst

Użytkownicy korzystają z desktopu i telefonu. Upload zdjęciem z telefonu jest istotnym przypadkiem użycia.

## Problem

Jaka technologia frontendu i czy budować aplikację natywną.

## Decyzja

**Next.js (App Router, TypeScript) obsługuje UI i PWA.** Aplikacja natywna jest odłożona; PWA jest pierwszym krokiem mobilnym.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| React SPA | Prostszy model mentalny | Brak SSR, słabszy pierwszy render | 03 §27 wskazuje Next.js |
| Aplikacja natywna od początku | Lepsze powiadomienia i praca w tle | Dwa dodatkowe kody, sklepy, wydania | Odłożona do czasu udowodnienia ograniczeń PWA |

## Konsekwencje pozytywne

- Jeden kod na desktop i mobile; instalacja na ekranie głównym bez sklepów.
- Server Components dla prostych odczytów, Client Components dla formularzy.

## Konsekwencje negatywne

- PWA ma słabszą pracę w tle i różnice iOS/Android.
- Ryzyko błędnego cache danych prywatnych (RY-26) wymaga świadomej konfiguracji.
- Granice server/client bywają niejasne i wymagają dyscypliny.

## Warunki ponownej analizy

- Powiadomienia systemowe lub praca w tle okazują się wymaganiem, którego PWA nie spełnia.
- Użytkownicy zgłaszają powtarzalny problem z instalacją lub działaniem offline.

## Weryfikacja

Brak sekretów w bundlu klienta; przegląd konfiguracji cache dla danych prywatnych; test dostępu z drugiego konta.
