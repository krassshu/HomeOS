# ADR-011 — WireGuard jako opcjonalny zdalny dostęp

| Pole | Wartość |
|---|---|
| **Status** | `deprecated` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | ADR-020 |
| **Powiązane** | `operations/04-Deployment-and-Infrastructure.md` §13, `architecture/05-Open-Source-Architecture.md` §21, `architecture/discrepancy-register.md` R-07 |

---

> **SUPERSEDED:** ADR-020 zachowuje LAN jako podstawę, ale ustanawia
> samodzielny WireGuard jedynym kontraktem dostępu zdalnego oraz podstawą
> przyszłej aplikacji natywnej. Opcjonalna jest aktywacja w konkretnej
> instalacji, nie wybór technologii dostępu zdalnego.

## Kontekst

Dostęp z telefonu spoza domu jest przydatny, ale nie jest warunkiem działania produktu. Wystawienie aplikacji publicznie byłoby najprostsze i najgorsze.

## Problem

Jak umożliwić dostęp mobilny bez wystawiania aplikacji do Internetu.

## Decyzja

**Podstawowym trybem dostępu jest LAN. WireGuard jest opcjonalną „cienką rurką” dla dostępu mobilnego.** Aplikacja **nigdy** nie jest wystawiana przez port forwarding.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Port forwarding aplikacji | Najprostsze | Publiczna powierzchnia ataku na dane medyczne i finansowe | Zakaz bezwzględny (04 §13, §43) |
| Tailscale | Łatwiejszy przez NAT | Standardowo zależy od zewnętrznego control plane | Sprzeczne z modelem local-first |
| Headscale | Self-hosted control plane | Kolejna usługa krytyczna do utrzymania | Koszt operacyjny przy jednym operatorze |

## Konsekwencje pozytywne

- Pełna kontrola, mała powierzchnia ataku, wysoka wydajność.
- Brak publicznego panelu aplikacji.
- Zakres MVP nie rośnie, jeżeli rodzina korzysta wyłącznie w domu.

## Konsekwencje negatywne

- Zarządzanie kluczami i konfiguracja klientów.
- Problemy z NAT u niektórych operatorów.
- Wymaga procedury zgubionego telefonu (RY-23).

## Warunki ponownej analizy

- NAT uniemożliwia zestawienie połączenia i nie ma obejścia.
- Pojawia się wymaganie dostępu dla osób spoza gospodarstwa.

## Weryfikacja

Test procedury zgubionego telefonu jako element bramy M19. Router: brak UPnP dla serwera, brak przekierowań do aplikacji.

**Otwarte:** czy WireGuard wchodzi do MVP (decyzja G6-06, brama M17).
