# 04 — Deployment and Infrastructure

## Wdrożenie, sieć, bezpieczeństwo, aktualizacje, backup i utrzymanie lokalnego segregatora

**Wersja:** 0.4

**Status:** `accepted z wyjątkami (dokument mieszany)`

**Data weryfikacji:** 2026-07-27

**Zależności:** [`../domain/01-Core-Domain-Model.md`](../domain/01-Core-Domain-Model.md), [`../domain/02-Object-Model.md`](../domain/02-Object-Model.md), [`../architecture/03-Technology-Architecture.md`](../architecture/03-Technology-Architecture.md)

**Model:** local-first, self-hosted, single-home

**Priorytet:** krytyczny

> ## Status dokumentu
>
> | Pole | Wartosc |
> |---|---|
> | **Status** | `accepted z wyjatkami (dokument mieszany)` |
> | **Priorytet w hierarchii zrodel prawdy** | Czwarty z 7 - operacyjnie nadrzedny |
> | **Obowiazuje w zakresie** | cala warstwa operacyjna: host, sprzet, Compose, sieci Docker, reverse proxy, DNS, TLS, zdalny dostep, firewall, sekrety, hardening, wolumeny, health, tryby degradacji, migracje, pinowanie wersji, aktualizacje, CI/CD, backup 3-2-1, restore, monitoring, logi, alerty, scenariusze awarii, runbooki, etapy wdrozenia |
> | **Nie obowiazuje w zakresie** | **Broker: wszystkie wystapienia Redis -> Valkey** (R-01) - §4, §6, §8, §9, §22, §24, §39, §41, §45, §47. **§28 Kopia** wypada z krotkiej listy narzedzi backupu -> **Restic lub Borg** (R-12). **§31 etap 2 monitoringu** - po MVP (R-18) |
> | **Ostatni przeglad** | 2026-07-27 (Faza 0 / M0) |
> | **Rejestr rozbieznosci** | [`discrepancy-register.md`](../architecture/discrepancy-register.md) |
>
> Hierarchia zrodel prawdy: **07 dla kolejnosci, 08 dla zakresu, accepted ADR dla decyzji szczegolowych, nastepnie 06 > 05 > 04 > 03 > 02 > 01**.
> Pelne uzasadnienie: [`00-Analiza-i-Mapa-Realizacji.md`](../00-Analiza-i-Mapa-Realizacji.md), sekcja 8.


***

# 1. Cel

Dokument opisuje sposób uruchomienia wszystkich komponentów jako jednej lokalnej platformy.

Obejmuje:

* host i kontenery,
* sieć,
* jeden punkt wejścia,
* dostęp lokalny i zdalny,
* DNS oraz TLS,
* sekrety,
* storage,
* zasoby sprzętowe,
* backup i restore,
* aktualizacje,
* monitoring,
* logi,
* tryb offline,
* kontrolowany Internet,
* CI/CD,
* awarie,
* runbooki,
* skalowanie.

***

# 2. Założenia

1. System działa na własnym serwerze.
2. Dane podstawowe pozostają lokalnie.
3. Podstawowe funkcje działają bez Internetu.
4. Dostęp z telefonu spoza domu jest opcjonalny.
5. Usługi wewnętrzne nie są publiczne.
6. Użytkownik widzi jedną aplikację.
7. Aktualizacje są kontrolowane.
8. Backup istnieje także poza głównym serwerem.
9. Awaria usługi pomocniczej nie może uszkodzić Core.
10. Kubernetes nie jest potrzebny w MVP.

***

# 3. Zasada nadrzędna

> Reverse proxy jest jedynym punktem wejścia. Bazy, Redis, Paperless, Gotenberg i workery nie mają portów wystawionych do Internetu ani niezaufanej sieci.

Frontend nigdy nie komunikuje się bezpośrednio z usługami wewnętrznymi.

***

# 4. Topologia

> **SUPERSEDED W ZAKRESIE BROKERA** - `R[(Redis)]` -> `R[(Valkey)]` (R-01). Reszta topologii aktualna.

```
flowchart TB 
  PHONE[Telefon poza domem] 
  VPN[WireGuard / prywatny VPN] 
  LAN[Zaufana sieć LAN] 
  RP[Caddy] 
  WEB[Next.js] 
  API[NestJS API] 
  W[Worker] 
  CDB[(Core PostgreSQL)] 
  R[(Redis)] 
  P[Paperless-ngx] 
  PDB[(Paperless PostgreSQL)] 
  G[Gotenberg] 
  F[(Document volumes)] 
  B[(Backup repository)] 
  
  
  
  PHONE --> VPN 
  VPN --> RP 
  LAN --> RP 
  RP --> WEB 
  RP --> API 
  API --> CDB 
  API --> R 
  W --> R 
  W --> CDB 
  API --> P 
  W --> P 
  P --> PDB 
  P --> G 
  P --> F 
  CDB -. backup .-> B 
  PDB -. backup .-> B 
  F -. backup .-> B
```

***

# 5. System hosta

Rekomendacja:

* Debian Stable lub Ubuntu Server LTS,
* Docker Engine,
* Docker Compose Plugin,
* firewall,
* osobny użytkownik deploymentu,
* klucze SSH,
* brak codziennej pracy jako root,
* automatyczne poprawki bezpieczeństwa hosta w kontrolowanym trybie.

## 5.1. Bare metal

Zalety:

* prostota,
* brak narzutu hypervisora,
* bezpośrednie dyski.

Wady:

* trudniejsza migracja,
* mniejsza izolacja od innych usług.

## 5.2. VM na Proxmox

Zalety:

* izolacja,
* snapshot środowiska,
* migracja,
* przydział zasobów,
* dobre dopasowanie do przyszłego homelabu.

Wady:

* kolejna warstwa,
* konieczność utrzymania hypervisora,
* snapshot nie zastępuje backupu.

### Decyzja

* serwer tylko dla aplikacji: Linux bare metal,
* szerszy homelab: VM na Proxmox,
* backup aplikacyjny obowiązkowy w obu wariantach.

***

# 6. Sprzęt

## Profil startowy

* 4 rdzenie x86\_64,
* 8 GB RAM minimum,
* 16 GB RAM zalecane,
* SSD dla systemu i baz,
* oddzielny wolumen danych,
* gigabit LAN,
* UPS zalecany.

Jednocześnie działają:

* dwa PostgreSQL,
* Redis,
* Paperless,
* Gotenberg/LibreOffice,
* Next.js,
* NestJS API,
* worker,
* reverse proxy,
* opcjonalny antywirus i monitoring.

## 6.1. Pojemność

Należy uwzględnić:

```
oryginały 
  + archiwalne PDF 
  + miniatury 
  + bazy i indeksy 
  + kosz 
  + kopie tymczasowe 
  + backup lokalny 
  + margines
```

Utrzymywać co najmniej 20–25% wolnego miejsca.

***

# 7. Docker Compose

Compose jest odpowiedni, ponieważ:

* deklaruje cały stack,
* zapewnia powtarzalność,
* izoluje zależności,
* jest wspierany przez Paperless,
* jest wystarczający dla jednej maszyny.

Compose nie zapewnia sam:

* HA,
* backupu,
* bezpiecznych migracji,
* monitoringu,
* kontroli supply chain,
* poprawnego rollbacku.

## 7.1. Struktura katalogów

```
/srv/home-platform/ 
├── compose.yml 
├── compose.override.yml 
├── .env 
├── secrets/ 
├── config/ 
│ ├── caddy/ 
│ ├── paperless/ 
│ └── app/ 
├── data/ 
│ ├── core-postgres/ 
│ ├── paperless-postgres/ 
│ ├── paperless-media/ 
│ ├── paperless-data/ 
│ ├── paperless-consume/ 
│ ├── redis/ 
│ └── app-assets/ 
├── backups/ 
├── scripts/ 
└── releases/
```

Sekrety nie trafiają do Git.

***

# 8. Usługi

> **SUPERSEDED W ZAKRESIE BROKERA** - usluga `redis` -> `valkey`; katalog `data/redis/` -> `data/valkey/` (R-01).

Minimalny stack:

```
caddy 
web 
api 
worker 
core-postgres 
redis 
paperless 
stack 
paperless-postgres 
gotenberg
```

Opcjonalnie później:

```
clamav 
prometheus 
grafana 
loki 
alertmanager 
node-exporter 
cadvisor 
backup-runner
```

Paperless powinien być uruchamiany w strukturze wspieranej przez jego oficjalną dokumentację dla przypiętej wersji.

***

# 9. Sieci Docker

Proponowane sieci:

```
edge 
core 
documents 
observability
```

## Edge

* Caddy,
* web,
* API.

## Core

* API,
* worker,
* Core PostgreSQL,
* Redis.

## Documents

* API/Document Gateway *(nazwa historyczna — obowiązuje port `DocumentProvider` z implementacją `PaperlessAdapter`, patrz [`../glossary.md`](../glossary.md) §1)*,
* worker,
* Paperless,
* jego zależności,
* Gotenberg.

## Reguły

* PostgreSQL bez `ports`,
* Redis bez `ports`,
* Gotenberg bez `ports`,
* Paperless bez publicznego `ports`,
* sieci danych `internal: true`, gdzie możliwe,
* administracja przez `docker compose exec`,
* brak `network_mode: host`,
* brak automatycznego wystawiania kontenerów.

***

# 10. Reverse proxy

## Caddy

Zalety:

* prosty Caddyfile,
* dobry reverse proxy,
* automatyzacja TLS,
* niski koszt utrzymania.

Wady:

* lokalne CA wymaga dystrybucji zaufania,
* publiczny ACME wymaga domeny i dostępu do walidacji.

## Traefik

Zalety:

* Docker discovery,
* labels,
* dynamiczna konfiguracja.

Wady:

* większa złożoność,
* błędna etykieta może wystawić usługę,
* większa powierzchnia administracyjna.

## Nginx

Stabilny, ale wymaga więcej ręcznej konfiguracji.

### Rekomendacja

Caddy z jawnymi trasami.

Wymagania:

* limity uploadu,
* timeouty,
* nagłówki bezpieczeństwa,
* poprawny client IP,
* tylko web i `/api`,
* brak paneli pomocniczych,
* brak wildcard proxy do kontenerów.

***

# 11. DNS

Zalecana nazwa:

```
home.example.pl
```

lub prywatna strefa wewnętrzna.

Nie polegać na IP.

## Split DNS

Ta sama nazwa:

* w LAN wskazuje prywatny adres,
* przez VPN wskazuje prywatny adres,
* publicznie może nie istnieć.

Unikać `.local` jako własnej strefy, ponieważ jest związane z mDNS.

DNS może zapewnić router, Pi-hole, AdGuard Home lub własny serwer. Nie jest to część Core.

***

# 12. TLS

TLS obowiązuje także w LAN, ponieważ system zawiera:

* hasła,
* dokumenty medyczne,
* tokeny,
* dane rodzinne.

## Wariant A — domena + DNS-01

* publiczny certyfikat,
* brak publicznego portu,
* lokalny DNS,
* token API dostawcy DNS,
* okresowy dostęp wychodzący do odnowienia.

## Wariant B — własne CA

* pełna lokalność,
* ręczne zaufanie na każdym urządzeniu,
* ochrona klucza CA,
* własny proces odnawiania.

### Rekomendacja

Domena i DNS-01 dla wygody, bez publicznego wystawienia aplikacji.

Dla pełnego air-gap: własne CA.

***

# 13. Zdalny dostęp — jedna „cienka rurka”

Nie wystawiać aplikacji przez port forwarding.

Rekomendacja:

```
telefon → WireGuard → prywatna sieć → Caddy → aplikacja
```

## WireGuard

Plusy:

* pełna kontrola,
* mała powierzchnia,
* wysoka wydajność,
* brak publicznego panelu aplikacji.

Minusy:

* zarządzanie kluczami,
* NAT,
* konfiguracja klientów,
* procedura zgubionego telefonu.

## Tailscale

Łatwiejszy przez NAT, ale standardowo używa zewnętrznego control plane.

## Headscale

Self-hosted control plane, lecz dodaje kolejną usługę i utrzymanie.

### Decyzja MVP

* LAN jako podstawowy dostęp,
* samodzielny WireGuard jako jedyna droga dostępu zdalnego,
* aktywacja WireGuard może zostać pominięta dla instalacji wyłącznie lokalnej,
* ręczny klient w MVP; osadzony klient w późniejszej aplikacji natywnej,
* brak zewnętrznego control plane i relaya,
* brak publicznego endpointu aplikacji.

***

# 14. Dostęp do Internetu

Pełne odcięcie utrudnia:

* aktualizacje,
* certyfikaty,
* sygnatury ClamAV,
* obrazy kontenerów,
* e-mail,
* kalendarze,
* synchronizację czasu.

## Rekomendowany local-first

* brak niezamówionego ruchu przychodzącego,
* kontrolowany ruch wychodzący,
* okna aktualizacyjne,
* opcjonalna allowlista,
* możliwość czasowego wyłączenia egress.

## Air-gap

Wymaga:

* offline importu obrazów,
* checksum i podpisów,
* lokalnego registry,
* lokalnego CA,
* lokalnego czasu,
* ręcznych aktualizacji sygnatur,
* braku chmurowych integracji.

Air-gap znacznie zwiększa koszt operacyjny. Nie jest domyślnym MVP, chyba że stanowi twarde wymaganie.

***

# 15. Firewall

Host:

* default deny incoming,
* established allowed,
* SSH tylko z sieci administracyjnej/VPN,
* HTTPS tylko LAN/VPN,
* brak portów baz.

Router:

* brak UPnP dla serwera,
* brak przekierowań do aplikacji,
* tylko port VPN, jeśli niezbędny,
* później segmentacja IoT.

IPv6 musi być filtrowane równie świadomie jak IPv4.

***

# 16. Sekrety

Sekrety obejmują:

* hasła baz,
* token Paperless,
* klucz sesji,
* token DNS,
* klucze backupu,
* klucze VPN,
* klucze szyfrowania.

MVP:

* pliki poza repozytorium,
* prawa `0600`,
* Docker secrets/mounted files,
* brak sekretów w Compose, logach i obrazie,
* jawna procedura rotacji.

Później:

* SOPS + age,
* Vault tylko przy realnej potrzebie,
* TPM/HSM opcjonalnie.

***

# 17. Hardening hosta i kontenerów

Host:

* osobny użytkownik `homeapp`,
* SSH keys,
* wyłączone logowanie root,
* ograniczone sudo,
* aktualizacje bezpieczeństwa,
* audit zmian.

Kontenery:

* non-root, jeśli wspierane,
* `no-new-privileges`,
* `cap_drop: ALL`,
* read-only root filesystem tam, gdzie możliwe,
* jawne writable volumes,
* brak privileged,
* limity CPU/RAM,
* tmpfs dla danych tymczasowych.

Przykład:

```
read_only: true 
security_opt: 
  - no-new-privileges:true 
cap_drop: 
  - ALL 
tmpfs: 
  - /tmp
```

Nie stosować mechanicznie bez testu zgodności obrazu.

***

# 18. Wolumeny

Dane trwałe:

* Core PostgreSQL,
* Paperless PostgreSQL,
* Paperless media,
* Paperless data,
* consume,
* konfiguracja,
* assety Core,
* opcjonalna trwałość Redis.

Dane tymczasowe:

* kwarantanna,
* konwersje,
* cache,
* eksporty.

Dane tymczasowe mają:

* limit,
* automatyczne czyszczenie,
* osobny katalog,
* brak backupu bez potrzeby.

## Bind mounts

Rekomendowane dla ważnych danych, ponieważ dają czytelne ścieżki i prostszy backup.

Wymagają poprawnego UID/GID i praw.

***

# 19. System plików

Możliwe:

* ext4 — prostota,
* XFS — stabilność,
* ZFS/Btrfs — checksumming i snapshoty przy odpowiedniej wiedzy.

Zasady:

* SMART,
* scrub dla ZFS/Btrfs,
* UPS,
* bezpieczny shutdown,
* monitoring pojemności.

RAID nie jest backupem. Snapshot nie jest backupem. Synchronizacja nie jest backupem.

***

# 20. Upload i kwarantanna

Przepływ:

```
klient 
 → Caddy 
 → API stream 
 → quarantine 
 → walidacja
 → opcjonalny ClamAV
 → kolejka
 → Paperless
 → potwierdzenie
 → cleanup
```

Zasady:

* stream, nie cały plik w RAM,
* limit rozmiaru,
* checksum,
* losowa nazwa wewnętrzna,
* oryginalna nazwa jako metadana,
* timeout,
* czyszczenie porzuconych uploadów,
* brak wykonywania plików,
* audit.

***

# 21. Health checks

Każda usługa ma healthcheck.

Core raportuje osobno:

* proces,
* Core DB,
* Redis,
* migracje,
* Paperless,
* miejsce na dysku,
* backup.

Paperless niedostępny nie powinien automatycznie oznaczać, że cały system jest martwy. Aplikacja może działać w trybie zdegradowanym.

***

# 22. Tryby degradacji

> **SUPERSEDED W ZAKRESIE BROKERA** - Redis niedostepny -> Valkey niedostepny (R-01).
> Sekcja Paperless niedostepny pozostawia otwarta decyzje o zachowaniu uploadu - rozstrzyga ja **G4-06**
> (rekomendacja kierunkowa: ograniczona kwarantanna z limitem, retencja, alertem miejsca i mozliwoscia ponowienia;
> kontrolowane odrzucenie dopiero przy pelnej kwarantannie lub przekroczeniu bezpiecznego progu wolnego miejsca).

## Paperless niedostępny

Działa:

* logowanie,
* obiekty,
* relacje,
* tagi Core,
* odczyt projekcji,
* historia.

Nie działa:

* nowy OCR,
* pełna treść,
* pobranie pliku bez cache.

Upload może:

* trafić do ograniczonej kwarantanny,
* albo zostać kontrolowanie odrzucony.

## Redis niedostępny

* odczyt Core działa,
* zadania są zatrzymane,
* API nie udaje sukcesu,
* reconciliation po powrocie odbudowuje zadania.

## Gotenberg niedostępny

* PDF-y mogą działać,
* Office czeka w kolejce,
* retry z backoff.

## Internet niedostępny

Podstawowy segregator działa lokalnie.

***

# 23. Migracje

## Core

1. Backup.
2. Test migracji na kopii.
3. Maintenance/read-only, jeśli potrzebne.
4. Migracja.
5. Start kompatybilnego API.
6. Smoke tests.
7. Obserwacja.
8. Rollback aplikacji albo restore, jeśli migracja nieodwracalna.

## Paperless

* zgodnie z dokumentacją konkretnej wersji,
* backup przed migracją,
* staging,
* release notes,
* brak aktualizacji w ciemno.

***

# 24. Pinowanie wersji

Nie używać `latest`.

Stosować:

* konkretny tag,
* najlepiej digest,
* lockfile,
* manifest wydania.

Przykład:

```
paperless:<verified>@sha256:<digest> 
gotenberg:<verified>@sha256:<digest> 
postgres:<policy> 
redis:<verified>
```

Wersje są wybierane w procesie release i zapisywane w repozytorium deploymentu.

***

# 25. Aktualizacje

## Harmonogram

* krytyczne poprawki: po szybkiej weryfikacji,
* zwykłe aktualizacje: planowane okno,
* major DB: osobny projekt.

## Procedura

1. Release notes.
2. Licencje i breaking changes.
3. Pobranie obrazów.
4. Weryfikacja digest/SBOM.
5. Test staging.
6. Backup.
7. Aktualizacja.
8. Smoke tests.
9. Logi i metryki.
10. Dokumentacja wersji.
11. Rollback/restore przy błędzie.

Bezwarunkowy auto-update kontenerów z danymi nie jest rekomendowany.

Automatyzacja może wykrywać i testować wersję, ale produkcja wymaga kontrolowanej decyzji.

***

# 26. Środowiska

## Development

* dane testowe,
* hot reload,
* testowy Paperless,
* bez danych produkcyjnych.

## Integration

* prawdziwy PostgreSQL,
* prawdziwy Paperless,
* testowe dokumenty,
* contract tests.

## Staging

* oddzielny stack,
* oddzielne wolumeny,
* anonimizowane dane,
* test migracji.

## Production

* pinned versions,
* backup,
* TLS,
* health,
* brak debug,
* kontrolowany egress.

***

# 27. CI/CD

CI:

* lint,
* typecheck,
* unit,
* integration,
* migration test,
* contract test Paperless,
* build obrazów,
* vulnerability scan,
* SBOM,
* Compose smoke test,
* E2E.

CD:

* ręczne zatwierdzenie,
* minimalne klucze deploy,
* lokalny registry opcjonalnie,
* brak publicznego panelu CI na serwerze.

Offline:

* eksport OCI,
* checksum,
* podpis,
* transfer,
* import,
* manifest.

***

# 28. Backup

> **CZESCIOWO SUPERSEDED BY 05 §16 i 07 §22** - **Kopia** wypada z listy kandydatow (R-12).
> Krotka lista: **Restic lub Borg**, wybor przez wykonane **E3A (przenosnosc) i E3B (disaster recovery)** w Fazie 1,
> nie przez porownanie funkcji. Regula 3-2-1, harmonogram, spojnosc i szyfrowanie - aktualne.

Backup obejmuje:

* Core DB,
* Paperless DB,
* oryginały,
* archiwalne kopie,
* konfigurację,
* mapowania,
* manifest wersji,
* oddzielny, szyfrowany pakiet sekretów aplikacyjnych potrzebnych do odzyskania.

Hasło lub klucz otwierający repozytorium backupu oraz klucz pakietu odzyskiwania mają co najmniej dwie kopie **out-of-band**. Nie mogą istnieć wyłącznie wewnątrz zaszyfrowanego materiału, do którego są potrzebne.

## Reguła 3-2-1

* 3 kopie,
* 2 typy nośników,
* 1 poza głównym serwerem.

Dla najważniejszych danych:

* kopia offline lub immutable.

## Narzędzia

Kandydaci:

* Restic,
* BorgBackup,
* Kopia.

Wymagania:

* szyfrowanie,
* deduplikacja,
* retencja,
* weryfikacja,
* łatwy restore,
* wsparcie docelowego storage.

## Spójność

* dump obu baz,
* spójna kopia plików/snapshot,
* manifest czasu,
* koordynacja zapisu.

Zwykłe kopiowanie aktywnego katalogu PostgreSQL nie jest poprawnym backupem logicznym.

## Harmonogram

* bazy: codziennie,
* pliki: codzienny przyrostowy,
* config: po zmianie i codziennie,
* off-site: regularnie,
* test losowego dokumentu: częściej,
* pełny restore: co najmniej kwartalnie.

***

# 29. Restore

Kolejność:

1. Czysty host.
2. Zgodny Docker/Compose.
3. Config i sekrety.
4. Wolumeny dokumentów.
5. Paperless DB.
6. Core DB.
7. Zależności.
8. Paperless.
9. Core.
10. Reconciliation.
11. Liczniki obiektów i dokumentów.
12. Losowe pliki.
13. Checksum.
14. Raport.

## RPO

Propozycja MVP: maksymalnie 24 godziny utraty.

## RTO

Propozycja domowa: kilka godzin do jednego dnia.

Wartości należy świadomie zaakceptować.

***

# 30. Szyfrowanie backupu

* szyfrowanie przed wysłaniem,
* klucz poza repozytorium backupu,
* minimum dwie bezpieczne kopie klucza,
* test odszyfrowania,
* procedura awaryjna.

Utrata klucza oznacza utratę backupu.

***

# 31. Monitoring

> **ETAP 2 PO MVP** (R-18) - w MVP obowiazuje wylacznie etap 1: health endpoint, structured logs,
> alert miejsca, alert backupu, stan kolejki. Prometheus/Grafana/Loki/Alertmanager - po wejsciu realnych danych (05 §17).

Minimum:

* status usług,
* disk usage,
* CPU,
* RAM,
* stan backupu,
* failed queue,
* stare `processing`,
* certyfikat,
* błędy logowania,
* 5xx,
* SMART.

Etap 1:

* health endpoint,
* Docker health,
* logi JSON,
* skrypt statusu.

Etap 2:

* Prometheus,
* Grafana,
* Loki,
* Alertmanager,
* node\_exporter,
* cAdvisor.

***

# 32. Logi

Wymagania:

* JSON,
* UTC,
* service,
* environment,
* correlation ID,
* request/job ID,
* poziom,
* rotacja,
* retencja.

Zakazane w logach:

* hasła,
* tokeny,
* pełne dokumenty,
* dane medyczne,
* sekrety,
* niepotrzebne dane osobowe.

Audit domenowy nie może być wyłącznie logiem Docker.

***

# 33. Alerty

Krytyczne:

* backup failed,
* brak świeżego backupu,
* dysk > 85%,
* baza down,
* SMART,
* certyfikat,
* wiele błędów logowania,
* checksum mismatch.

Ostrzegawcze:

* długa kolejka,
* Gotenberg down,
* reconciliation mismatch,
* wysoki RAM,
* przetwarzanie zbyt długo.

Alert powinien zawierać instrukcję działania.

***

# 34. Czas

* system i kontenery używają UTC,
* UI prezentuje Europe/Warsaw,
* NTP,
* testy DST,
* logi mają offset lub UTC,
* przypomnienia nie mogą przesuwać się przy zmianie czasu.

Air-gap wymaga lokalnego wiarygodnego czasu.

***

# 35. Supply chain obrazów

* oficjalne registry,
* digest,
* vulnerability scan,
* SBOM,
* minimalne obrazy,
* regularny rebuild własnych obrazów,
* brak przypadkowych community images,
* sprawdzenie licencji,
* podpisy w przyszłości.

***

# 36. Ochrona przed ransomware

* offline/immutable backup,
* osobne konto backupowe,
* aplikacja nie usuwa historii backupów,
* retencja,
* kosz,
* opóźnione kasowanie,
* katalog danych nie jest zwykłym udziałem SMB do zapisu.

***

# 37. Host maintenance

* poprawki bezpieczeństwa,
* kontrolowany reboot,
* test po kernel update,
* monitoring `/var/lib/docker`,
* cleanup obrazów bez wolumenów,
* backup konfiguracji hosta.

Nigdy:

```
docker system prune --volumes
```

bez pełnego zrozumienia skutków.

***

# 38. UPS

Zalecenia:

* UPS,
* NUT/USB,
* automatyczny shutdown,
* test baterii,
* alert,
* autostart po powrocie,
* bezpieczne zamknięcie baz.

***

# 39. Start i shutdown

## Start

1. Storage.
2. Sieci.
3. Bazy.
4. Redis.
5. Gotenberg.
6. Paperless.
7. Migracje Core.
8. Worker.
9. API.
10. Web.
11. Caddy.
12. Health.
13. Reconciliation.

`depends_on` nie zastępuje readiness i retry.

## Shutdown

1. Wstrzymaj nowe requesty.
2. API kończy requesty.
3. Worker nie pobiera nowych zadań.
4. Zadania wracają bezpiecznie do retry.
5. Bazy kończą zapis.
6. Host zamyka się.

***

# 40. Scenariusze awarii

## Dysk danych

* wymiana,
* restore plików,
* restore baz,
* reconciliation,
* checksum.

## Utrata Core DB

* restore,
* połączenie z Paperless,
* reconciliation external ID,
* raport niepowiązanych dokumentów.

## Utrata Paperless DB

* restore bazy i media z tego samego punktu,
* uruchomienie,
* weryfikacja indeksów,
* reconciliation.

## Utrata tokenu

* wygeneruj nowy,
* zmień secret,
* test,
* unieważnij stary.

## Błędna aktualizacja

* zatrzymaj,
* oceń migrację,
* rollback obrazu, jeśli DB kompatybilna,
* inaczej restore,
* raport incydentu.

## Kompromitacja administratora

* odetnij VPN,
* unieważnij sesje,
* rotuj sekrety,
* przeanalizuj audit,
* ustal zakres,
* odzyskaj system,
* włącz dodatkowe zabezpieczenia.

***

# 41. Runbooki

Wymagane:

* instalacja,
* update Core,
* update Paperless,
* backup ręczny,
* pełny restore,
* restore pojedynczego dokumentu,
* rotacja sekretu,
* nowy klient VPN,
* zgubiony telefon,
* brak miejsca,
* awaria Redis,
* awaria Paperless,
* awaria DB,
* certyfikat,
* incydent bezpieczeństwa,
* migracja na nowy host.

***

# 42. Etapy wdrożenia

## Etap 0 — laboratorium

* testowa maszyna,
* dane przykładowe,
* brak remote,
* pionowy prototyp,
* pomiar CPU/RAM,
* ręczny backup i restore.

## Etap 1 — MVP

* host produkcyjny,
* Caddy,
* TLS,
* LAN,
* Core,
* Paperless,
* Gotenberg,
* Redis,
* backup na drugi nośnik,
* health.

## Etap 2 — telefon

* WireGuard,
* procedura urządzeń,
* test zgubienia telefonu,
* PWA.

## Etap 3 — hardening

* ClamAV,
* SOPS,
* monitoring,
* alerty,
* off-site backup,
* staging.

## Etap 4 — homelab

* VLAN,
* osobna VM,
* registry,
* centralne logi,
* oddzielny storage.

***

# 43. Czego nie robić

* Nie wystawiać Paperless.
* Nie wystawiać PostgreSQL.
* Nie przekazywać tokenu do frontendu.
* Nie używać `latest`.
* Nie aktualizować bez backupu.
* Nie trzymać jedynego backupu na tym samym serwerze.
* Nie traktować snapshotu jako backupu.
* Nie edytować media Paperless ręcznie.
* Nie czytać jego bazy.
* Nie wyłączać TLS w LAN.
* Nie uruchamiać privileged.
* Nie używać auto-update bez testu.
* Nie zakładać, że RAID chroni przed usunięciem.
* Nie wdrażać Kubernetes na zapas.

***

# 44. Checklist produkcyjny

## Host

* wspierany Linux,
* SMART,
* firewall,
* SSH keys,
* czas,
* aktualizacje,
* UPS lub zaakceptowane ryzyko.

## Compose

* pinned versions,
* digest,
* healthchecks,
* restart policy,
* resource limits,
* internal networks,
* brak publicznych portów.

## Dane

* wolumeny,
* prawa,
* miejsce,
* kosz,
* checksums.

## Bezpieczeństwo

* TLS,
* secrets,
* rate limiting,
* upload limits,
* audit,
* brak sekretów w logach.

## Backup

* obie bazy,
* dokumenty,
* konfiguracja,
* szyfrowanie,
* off-site,
* test restore.

## Operacje

* update runbook,
* restore runbook,
* disk alert,
* backup alert,
* version manifest,
* administrator odpowiedzialny.

***

# 45. Szkielet Compose

> **SUPERSEDED W ZAKRESIE BROKERA** - usluga `redis` w ponizszym szkielecie -> `valkey` (R-01).
> Szkielet nie jest konfiguracja produkcyjna; obowiazujacy stack: 05 §30.

To nie jest gotowa konfiguracja produkcyjna:

```
services: reverse-proxy: image: caddy:<PINNED> networks: [edge] ports: - "443:443" volumes: - ./config/caddy:/etc/caddy:ro - caddy_data:/data security_opt: - no-new-privileges:true web: image: home-platform-web:<PINNED> networks: [edge] expose: ["3000"] read_only: true api: image: home-platform-api:<PINNED> networks: [edge, core, documents] expose: ["3000"] secrets: - core_db_password - paperless_token worker: image: home-platform-worker:<PINNED> networks: [core, documents] secrets: - core_db_password - paperless_token core-postgres: image: postgres:<PINNED> networks: [core] volumes: - ./data/core-postgres:/var/lib/postgresql/data secrets: - core_db_password redis: image: redis:<PINNED> networks: [core] volumes: - ./data/redis:/data networks: edge: core: internal: true documents: internal: true secrets: core_db_password: file: ./secrets/core_db_password paperless_token: file: ./secrets/paperless_token volumes: caddy_data:
```

Paperless należy dołączyć na bazie oficjalnej konfiguracji kompatybilnej z przypiętą wersją.

***

# 46. Źródła

Oficjalne materiały:

* https://docs.docker.com/
* https://docs.docker.com/get-started/docker-overview/
* https://docs.paperless-ngx.com/setup/
* https://docs.paperless-ngx.com/administration/
* https://docs.paperless-ngx.com/configuration/
* https://docs.paperless-ngx.com/troubleshooting/
* https://gotenberg.dev/docs/getting-started/installation
* https://gotenberg.dev/docs/configuration
* https://docs.nestjs.com/techniques/queues

Każdą konfigurację należy ponownie sprawdzić z dokumentacją przypiętej wersji przed produkcją.

***

# 47. Decyzja końcowa

> **SUPERSEDED W ZAKRESIE BROKERA** - `Redis` -> `Valkey` (R-01).

Rekomendowany deployment:

```
Linux / opcjonalnie VM 
└── Docker Compose 
├── Caddy 
├── Next.js 
├── NestJS API 
├── NestJS Worker 
├── PostgreSQL Core 
├── Redis 
├── Paperless-ngx 
├── PostgreSQL Paperless 
└── Gotenberg
```

Dostęp:

```
LAN → HTTPS → Caddy → aplikacja 
telefon → WireGuard → HTTPS → Caddy → aplikacja
```

Najważniejsze wymagania:

1. jeden punkt wejścia,
2. brak publicznych usług wewnętrznych,
3. przypięte wersje,
4. backup poza hostem,
5. test restore,
6. monitoring dysku,
7. kontrolowane aktualizacje,
8. tryb zdegradowany,
9. sekrety poza repozytorium,
10. komplet runbooków.
