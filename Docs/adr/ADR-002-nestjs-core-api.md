# ADR-002 — NestJS jako Core API

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §7, `architecture/05-Open-Source-Architecture.md` §14, ADR-003 |

---

## Kontekst

Frontend jest pisany w TypeScript. System potrzebuje jednego publicznego API, orkiestracji integracji, producenta zadań i źródła audytu.

## Problem

Który framework backendowy pełni rolę Core API i czy Next.js może być backendem.

## Decyzja

**NestJS jest jedynym publicznym API systemu.** Odpowiada za reguły biznesowe, uwierzytelnianie, orkiestrację integracji, produkcję jobów, audyt i agregację wyszukiwania. **Next.js nie jest backendem.**

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Next.js Route Handlers jako backend | Jeden framework, mniej kodu | Brak dependency injection i modułowości, mieszanie warstw, ryzyko wycieku sekretów do klienta | 03 §6 wprost: Next.js nie jest głównym backendem |
| Spring / ASP.NET / FastAPI | Dojrzałe ekosystemy | Drugi język w projekcie jednoosobowym | Wspólny język z frontendem przeważa (03 §27) |

## Konsekwencje pozytywne

- Wspólny język i typy z frontendem przez `packages/contracts`.
- Dependency injection i modułowość wspierają granice z ADR-001.
- Dojrzałe wsparcie kolejek (BullMQ) i generowania OpenAPI.

## Konsekwencje negatywne

- Ekosystem npm wymaga kontroli zależności i SBOM.
- Ciężkie CPU nie może działać w głównym procesie — musi trafić do workera.
- Łatwo stworzyć sprzężony monolit, jeżeli domena zależy od frameworka.

## Warunki ponownej analizy

- Profil obciążenia wymusza runtime o innej charakterystyce.
- Pojawia się moduł, którego nie da się sensownie zaimplementować w TypeScript (np. lokalne AI).

## Weryfikacja

Test architektury: `apps/web` nie importuje klienta bazy danych ani klienta HTTP Paperless.
