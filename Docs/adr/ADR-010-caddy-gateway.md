# ADR-010 — Caddy jako jedyny gateway

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `operations/04-Deployment-and-Infrastructure.md` §10, `architecture/05-Open-Source-Architecture.md` §11 |

---

## Kontekst

System zawiera hasła, dokumenty medyczne, tokeny i dane rodzinne. TLS obowiązuje także w sieci lokalnej.

## Problem

Jaki reverse proxy i jak ograniczyć powierzchnię wystawienia usług.

## Decyzja

**Caddy jest jedynym punktem wejścia do systemu.** Obsługuje TLS, routing, limity uploadu, timeouty i nagłówki bezpieczeństwa. Trasy są **jawne** — wyłącznie `web` i `/api`. Bazy, Valkey, Paperless i Gotenberg nie mają publicznych portów.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Traefik | Docker discovery, dynamiczna konfiguracja | **Błędna etykieta może przypadkowo wystawić usługę** | Ryzyko nieakceptowalne przy dokumentach medycznych |
| Nginx | Dojrzały, przewidywalny | Więcej konfiguracji ręcznej, TLS nieautomatyczny | Wyższy koszt utrzymania przy jednym operatorze |

## Konsekwencje pozytywne

- Prosty Caddyfile i automatyzacja TLS.
- Jawne trasy eliminują ryzyko przypadkowego wystawienia panelu pomocniczego.
- Niski koszt utrzymania, licencja Apache 2.0.

## Konsekwencje negatywne

- Lokalne CA wymaga dystrybucji zaufania na każde urządzenie.
- Publiczny ACME wymaga domeny i dostępu do walidacji DNS.
- Plugin DNS może wymagać własnego builda obrazu.

## Warunki ponownej analizy

- Pojawia się wymaganie dynamicznego odkrywania usług przy większej liczbie hostów.
- Caddy przestaje spełniać wymagania bezpieczeństwa lub wydajności.

## Weryfikacja

Przegląd Caddyfile: brak wildcard proxy, brak tras do paneli pomocniczych. Skan portów hosta: wyłącznie 443 (i port VPN, jeśli wdrożony).
