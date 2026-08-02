# ADR-020 — Samodzielny WireGuard jako jedyna droga dostępu zdalnego

| Pole | Wartość |
|---|---|
| **Status** | `accepted` |
| **Data** | 2026-08-01 |
| **Milestone** | M4 / M18 |
| **Zastępuje** | ADR-011 |
| **Zastąpiony przez** | — |
| **Powiązane** | `08-MVP-Scope.md` S-18, `operations/04-Deployment-and-Infrastructure.md` §13, `architecture/05-Open-Source-Architecture.md` §21 |

---

## Kontekst

HomeOS najpierw powstaje jako lokalna aplikacja webowa. Po ustabilizowaniu
lokalnego produktu otrzyma natywną aplikację mobilną, a w przyszłości może
otrzymać klienta desktopowego. Użytkownik ma móc połączyć się ze swoim domowym
serwerem z dowolnego miejsca bez prowadzenia ruchu przez obcy control plane,
relay albo publiczny hosting aplikacji.

ADR-011 wskazywał WireGuard jako opcjonalny dodatek. Nowe wymaganie ustanawia
go trwałym kontraktem wszystkich przyszłych kanałów dostępu zdalnego.

## Decyzja

1. HomeOS działa w pełni w LAN bez VPN i bez Internetu potrzebnego do zwykłej
   pracy lokalnej.
2. Jedyną wspieraną drogą zdalnego dostępu jest samodzielnie utrzymywany
   WireGuard. Tailscale, zewnętrzny relay i zewnętrzny control plane nie są
   częścią produktu.
3. Aktywację dostępu zdalnego użytkownik może pominąć podczas instalacji, ale
   architektura, model urządzeń i procedury od początku zakładają WireGuard;
   nie powstaje alternatywny publiczny endpoint aplikacji.
4. Brama WireGuard działa na warstwie infrastruktury — na routerze albo w
   odseparowanej VM — nie wewnątrz uprzywilejowanego kontenera Core.
5. Publicznie osiągalny może być wyłącznie port UDP WireGuard. Caddy i
   aplikacja pozostają dostępne z LAN oraz z dedykowanej podsieci VPN.
6. Każde urządzenie ma osobną parę kluczy i adres VPN. Tunel typu split kieruje
   tylko zasoby HomeOS; nie daje zwykłemu użytkownikowi dostępu do Proxmoxa,
   NAS-a, SSH ani całego LAN-u.
7. WireGuard jest pierwszą warstwą dostępu, ale nie zastępuje sesji,
   uprawnień ani ponownego uwierzytelnienia HomeOS.
8. MVP udostępnia provisioning dla ręcznie uruchamianych oficjalnych klientów
   WireGuard. Późniejsza aplikacja natywna osadza klienta WireGuard i używa
   tego samego kontraktu urządzeń, kluczy, tras i unieważniania.
9. Klucz prywatny powstaje na urządzeniu i nie opuszcza go. Serwer rejestruje
   klucz publiczny. Zgubienie urządzenia unieważnia peer VPN i sesje HomeOS.
10. Instalator wykonuje preflight osiągalności: publiczny IPv4 albo osiągalny
    IPv6, konfiguracja NAT/firewalla i opcjonalna nazwa dynamiczna. CGNAT bez
    osiągalnego IPv6 blokuje dostęp zdalny; produkt nie przechodzi wtedy na
    obcy relay.
11. Klient i API zachowują neutralną granicę transportu, aby bardzo późny
    wariant hostowany nie wymagał przebudowy domeny. Obecne profile obsługują
    wyłącznie LAN i WireGuard. Tryb `hosted` może powstać dopiero po publicznym
    wydaniu, na podstawie nowego ADR i osobnego modelu bezpieczeństwa; nie jest
    fallbackiem dla CGNAT ani częścią lokalnej instalacji.

## Etapy dostarczenia

| Etap | Zakres |
|---|---|
| lokalny produkt | web/PWA w LAN; brak zależności działania od VPN |
| M18 | brama i hardening WireGuard, ręczny klient, onboarding i revoke urządzenia |
| po MVP | natywna aplikacja mobilna z osadzonym WireGuard i automatycznym split tunnel |
| później | opcjonalny klient desktopowy korzystający z tego samego kontraktu |
| po publicznym wydaniu | ewentualny osobny wariant hostowany po ponownej analizie izolacji i ryzyka |

## Konsekwencje pozytywne

- Ruch biegnie bezpośrednio urządzenie–dom, bez usług pośredniczących.
- Aplikacja, baza, panel Proxmox i usługi dokumentowe nie są wystawione
  publicznie.
- Kanały web, mobile i ewentualny desktop używają jednego modelu urządzeń.
- Lokalny HomeOS pozostaje użyteczny przy awarii Internetu.

## Konsekwencje negatywne

- Wbudowany VPN wymaga natywnej aplikacji i integracji z API systemów iOS oraz
  Android; PWA nie wystarczy.
- Inny aktywny VPN na urządzeniu może kolidować z tunelem HomeOS.
- Operator musi zarządzać osiągalnością, kluczami, firewall’em i procedurą
  zgubionego telefonu.
- Niektóre sieci blokujące UDP mogą uniemożliwić połączenie. Bez relaya nie ma
  automatycznego fallbacku.

## Alternatywy odrzucone

| Alternatywa | Powód odrzucenia |
|---|---|
| publiczny endpoint lokalnej instalacji | nieakceptowalna powierzchnia ataku; nie przesądza o osobnym przyszłym produkcie hostowanym |
| Tailscale | zewnętrzny control plane i możliwy relay |
| Headscale | osobna usługa sterująca i relay niepotrzebne dla przyjętego modelu |
| własny protokół VPN | zbędne ryzyko kryptograficzne i utrzymaniowe |

## Weryfikacja

- Zdalny klient dociera do Caddy wyłącznie przez adres z podsieci WireGuard.
- Bez aktywnego tunelu aplikacja nie jest osiągalna z WAN.
- Peer zwykłego użytkownika nie dociera do Proxmoxa, NAS-a, SSH ani baz.
- Ponowienie onboardingu nie tworzy drugiego peera.
- Revoke zgubionego urządzenia odcina tunel i wszystkie jego sesje.
- Brak publicznego IPv4/IPv6 kończy preflight czytelnym stanem `remote_blocked`,
  bez konfiguracji zewnętrznego relaya.
