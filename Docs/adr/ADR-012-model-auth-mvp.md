# ADR-012 — Model uwierzytelniania MVP

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-07-27 |
| **Milestone** | M2 |
| **Zastępuje** | — |
| **Zastąpiony przez** | — |
| **Powiązane** | `architecture/03-Technology-Architecture.md` §21, `architecture/05-Open-Source-Architecture.md` §20, `architecture/discrepancy-register.md` R-10 |

---

## Kontekst

System obsługuje kilku użytkowników jednego gospodarstwa. Zewnętrzny dostawca tożsamości byłby kolejną usługą krytyczną z własnym recovery.

## Problem

Czy wdrażać zewnętrzny IdP, czy zaimplementować uwierzytelnianie w Core.

## Decyzja

**Uwierzytelnianie implementuje NestJS za portem `IdentityProvider`.** Hasła
Argon2id, rate limiting logowania, audit logowania i przygotowanie pod MFA.
Zewnętrzny IdP jest odłożony.

Sesje są server-side i mają nieprzezroczysty, kryptograficznie losowy token.
PostgreSQL przechowuje wyłącznie hash tokenu oraz stan sesji i jest źródłem
prawdy; Valkey może być tylko cache. Web używa host-only cookie `HttpOnly`,
`Secure`, `SameSite` z ochroną CSRF. Przyszły klient natywny przechowuje ten sam
rodzaj tokenu w bezpiecznym magazynie systemowym. JWT oraz rotowane refresh
tokeny nie wchodzą do MVP.

Blokada konta, zakończenie członkostwa, wylogowanie albo odebranie urządzenia
natychmiast unieważnia odpowiednie sesje. Okresy ważności ustala polityka M5.

## Alternatywy

| Alternatywa | Zalety | Wady | Dlaczego odrzucona |
|---|---|---|---|
| Authentik / Keycloak | SSO, MFA, dojrzałe zarządzanie sesjami | Kolejna usługa krytyczna, złożony recovery, przerost dla domu | Jawnie poza MVP (07 §6) |
| Uwierzytelnianie bez portu | Mniej abstrakcji | Brak drogi do późniejszego IdP | Port kosztuje niewiele i zachowuje opcję |
| Krótki JWT + rotowany refresh token | Brak odczytu sesji dla części żądań | Złożona rotacja i wykrywanie ponownego użycia; trudniejsze natychmiastowe revoke | Skala domowa nie uzasadnia kosztu, a szybkie odebranie dostępu jest ważniejsze |

## Konsekwencje pozytywne

- Mniej usług i prostszy onboarding domownika.
- Pełna kontrola nad UX logowania i zapraszania.
- Port `IdentityProvider` zachowuje drogę do przyszłego SSO.

## Konsekwencje negatywne

- Odpowiedzialność za bezpieczeństwo sesji, resetu i blokad spoczywa na nas.
- MFA i passkeys wymagają osobnej pracy (wydanie 1.1).
- Procedura odzyskania konta właściciela musi zostać zaprojektowana (G3-02).

## Warunki ponownej analizy

- Pojawia się wymaganie SSO na poziomie organizacji.
- Liczba użytkowników przekracza skalę gospodarstwa domowego.

## Weryfikacja

Permission tests z test matrix (M5). Test rate limitingu i procedury odzyskania administratora.

**G3-01 rozstrzygnięte:** obowiązują sesje server-side opisane w
`10-Conceptual-Data-Model.md` §M4-D17. Otwarte pozostają wyłącznie konkretne
czasy wygaśnięcia i parametry polityki M5.
