# HomeIntelCore (dawniej HomeOS) — Dokumentacja projektu

**Repozytorium dokumentacji** · M0–M2 zamknięte · M3 w toku · M4 w szkicu · M9 foundation: pierwszy wycinek zweryfikowany · Ostatnia aktualizacja: 2026-09-11

Domowy segregator: lokalna, samodzielnie hostowana platforma, w której obiekty (osoby, rzeczy, miejsca, usługi) są opisane dynamicznymi polami, połączone relacjami i wzbogacone o dokumenty z automatycznym OCR.

---

## 1. Źródła prawdy

```
07 — kolejność, milestone'y i bramy
08 — zakres MVP
accepted ADR — konkretne decyzje architektoniczne
06 — zachowanie i workflow
05 — komponenty OSS i granice integracji
04 → 03 → 02 → 01 — szczegóły operacyjne, techniczne i domenowe
```

Dokumenty **05, 06 i 07 są nadrzędne** wobec starszych dokumentów 01–04 w zakresie technologii, architektury, workflow, integracji i kolejności realizacji. `08-MVP-Scope.md` jest wiążący dla zakresu. Zaakceptowany ADR jest wiążący dla konkretnej decyzji, której dotyczy. Dokumenty **01–04** pozostają źródłem prawdy dla wizji, domeny, modelu obiektowego i warstwy operacyjnej w zakresie niezmienionym przez nowsze źródło.

W razie sprzeczności najpierw ustala się obszar decyzji, a następnie właściwe źródło. Rozstrzygnięcia starszych dokumentów są zapisane w [`architecture/discrepancy-register.md`](architecture/discrepancy-register.md). Nowa zmiana decyzji przyjętej w ADR wymaga kolejnego ADR.

---

## 2. Indeks dokumentów

### Poziom nadrzędny

| Dokument | Rola | Status |
|---|---|---|
| [`00-Analiza-i-Mapa-Realizacji.md`](00-Analiza-i-Mapa-Realizacji.md) | Rekonstrukcja obrazu projektu, granice systemów, moduły, fazy 0–8, ścieżka krytyczna, ryzyka | `accepted` |
| [`07-Product-and-Delivery-Roadmap.md`](07-Product-and-Delivery-Roadmap.md) | Roadmapa wykonawcza M0–M22, bramy, Definition of Ready i Done | `accepted` |
| [`08-MVP-Scope.md`](08-MVP-Scope.md) | Zamrożony zakres MVP, non-goals, deferred list, decyzje G1 | `accepted` |
| [`10-Conceptual-Data-Model.md`](10-Conceptual-Data-Model.md) | Roboczy model pojęciowy M4: encje, relacje, lifecycle, invariants, retencja i gate procesów | `draft` |
| [`glossary.md`](glossary.md) | Słownik pojęć domenowych — jedyne miejsce definiujące terminy | `accepted` |
| [`CHANGELOG.md`](CHANGELOG.md) | Historia zmian dokumentacji | — |

### `architecture/`

| Dokument | Rola | Status |
|---|---|---|
| [`03-Technology-Architecture.md`](architecture/03-Technology-Architecture.md) | Stos technologiczny, granice własnego kodu, integracja z Paperless | `accepted z wyjątkami` |
| [`05-Open-Source-Architecture.md`](architecture/05-Open-Source-Architecture.md) | Komponenty OSS, właściciele danych, porty, licencje, bramy OS-1…OS-4 | `accepted` |
| [`discrepancy-register.md`](architecture/discrepancy-register.md) | Rejestr 21 rozbieżności i rozstrzygnięć | `accepted` |

### `domain/`

| Dokument | Rola | Status |
|---|---|---|
| [`01-Core-Domain-Model.md`](domain/01-Core-Domain-Model.md) | Wizja, problem, obiekt jako jednostka centralna, Workspace, role | `accepted` (domena) / `deprecated` (technologia) |
| [`02-Object-Model.md`](domain/02-Object-Model.md) | Pełna specyfikacja Object Engine | `accepted` |

### `workflows/`

| Dokument | Rola | Status |
|---|---|---|
| [`06-System-Workflows.md`](workflows/06-System-Workflows.md) | Kontrakt zachowania: procesy, stany, idempotencja, reconciliation, błędy | `accepted` |

### `operations/`

| Dokument | Rola | Status |
|---|---|---|
| [`04-Deployment-and-Infrastructure.md`](operations/04-Deployment-and-Infrastructure.md) | Wdrożenie, sieci, TLS, sekrety, hardening, backup, restore, runbooki | `accepted z wyjątkami` |
| [`spike-plan.md`](operations/spike-plan.md) | Plan wykonawczy Fazy 1 — E1, E2, E3A (przenośność) i E3B (DR) | `accepted` |
| [`lab-manifest.md`](operations/lab-manifest.md) | Baseline Paperless 3.0.4, digesty i wymagania środowiska laboratoryjnego | `accepted — konfiguracja zweryfikowana statycznie` |
| [`spike-data-policy.md`](operations/spike-data-policy.md) | Zasady ochrony dokumentów testowych, sekretów i artefaktów | `accepted` |
| [`M9-PostgreSQL-Prisma-CC-Runbook.md`](operations/M9-PostgreSQL-Prisma-CC-Runbook.md) | Wykonawczy runbook CC dla lokalnego PostgreSQL 18, Prisma, readiness i testów pierwszego wycinka M9 | `accepted for execution` |

### `adr/`

| Dokument | Rola | Status |
|---|---|---|
| [`09-Architecture-Decisions-Index.md`](adr/09-Architecture-Decisions-Index.md) | Indeks 20 ADR-ów ze statusami | `accepted` |
| [`ADR-TEMPLATE.md`](adr/ADR-TEMPLATE.md) | Obowiązujący szablon ADR | `accepted` |
| `ADR-001` … `ADR-020` | Decyzje architektoniczne | 16 × `accepted`, 3 × `proposed`, 1 × `deprecated` |

### `security/`, `api/`, `ux/`

Katalogi utworzone, dokumenty powstaną just-in-time przed odpowiadającym milestone. Szczegóły w `README.md` każdego katalogu.

---

## 3. Statusy dokumentów

| Status | Znaczenie |
|---|---|
| `draft` | Szkic roboczy. Nie stanowi podstawy do implementacji. |
| `proposed` | Propozycja czekająca na rozstrzygnięcie. Ma zapisany warunek lub eksperyment rozstrzygający. |
| `accepted` | Obowiązuje. Zmiana wymaga nowego ADR lub nowej wersji dokumentu. |
| `deprecated` | Zastąpione. Zachowane jako zapis historyczny z jawnym wskazaniem następcy. |

Każdy dokument 01–07 zawiera blok **Status dokumentu** określający, w jakim zakresie obowiązuje, a w jakim został zastąpiony.

---

## 4. Zasada aktualizacji dokumentacji

> **Dokumentacja zmienia się razem z kodem.**

1. Zmiana zachowania systemu wymaga aktualizacji odpowiedniego dokumentu w tej samej zmianie.
2. Zmiana decyzji o wysokim koszcie odwrócenia wymaga **nowego ADR**, nie edycji starego. Stary ADR otrzymuje status `deprecated` i wskazanie następcy.
3. Nowe pojęcie domenowe trafia najpierw do [`glossary.md`](glossary.md), potem do kodu.
4. Nowa rozbieżność między dokumentami trafia do [`discrepancy-register.md`](architecture/discrepancy-register.md) — nie jest rozstrzygana milcząco w kodzie.
5. Dokumenty szczegółowe powstają **just-in-time przed odpowiadającym milestone**, nie wszystkie naraz.
6. Każda zmiana odnotowana w [`CHANGELOG.md`](CHANGELOG.md).

---

## 5. Gdzie zacząć

| Cel | Dokument |
|---|---|
| Zrozumieć, co budujemy i dlaczego | [`domain/01-Core-Domain-Model.md`](domain/01-Core-Domain-Model.md) |
| Zobaczyć całą mapę realizacji | [`00-Analiza-i-Mapa-Realizacji.md`](00-Analiza-i-Mapa-Realizacji.md) |
| Sprawdzić, co wchodzi do MVP | [`08-MVP-Scope.md`](08-MVP-Scope.md) |
| Sprawdzić obowiązującą decyzję techniczną | [`adr/09-Architecture-Decisions-Index.md`](adr/09-Architecture-Decisions-Index.md) |
| Zacząć pracę wykonawczą | [`operations/spike-plan.md`](operations/spike-plan.md) |

---

## 6. Stan projektu

**Zamknięte dokumentacyjnie:** M0 (repozytorium dokumentacji), M1 (zamrożenie MVP Scope), M2 (ADR Foundation).

**Stan M3:** rewalidacja Paperless 3.0.4, E2, E3A, E3B, OS-3-LAB i porównanie topologii Valkey zostały wykonane. **Gate OS-2-LAB jest zamknięty w zakresie laboratoryjnym** — E3A powtórzono z wymuszonym punktem spójności i przeszedł dla Restica i Borga. Gate OS-1 nadal czeka na potwierdzenie OCR na rzeczywistych skanach. ADR-015 pozostaje `proposed`, dopóki Restic i Borg nie zostaną sprawdzone na docelowym storage 4 TB. Wynik FAIL E1-13 jest obowiązkowym wymaganiem odporności integracji, ale nie krytycznym ograniczeniem według 08 §G1-02. Szczegóły: [`operations/spike-results/10-decisions-and-gates.md`](operations/spike-results/10-decisions-and-gates.md).

**Stan M4:** rozpoczęto roboczy [`10-Conceptual-Data-Model.md`](10-Conceptual-Data-Model.md). Szkic zapisuje uzgodnienia domenowe, ale nie zamyka bramy M4 i nie stanowi podstawy implementacji przed formalnym domknięciem wymaganych bram.

Konfiguracja laboratorium jest oparta na oficjalnej strukturze Compose v3.0.4, ma przypięte tagi i digesty oraz osobne warianty source/restore i Valkey. OpenAPI i zachowanie runtime zostały pobrane oraz sprawdzone na uruchomionej instancji 3.0.4; wynik nie dziedziczy założeń z 2.x.

**Stan M9:** zgodnie z 07 §14 fundament inżynieryjny powstał świadomie przed zamknięciem bram M3 i M4, bez kodu domenowego. Zweryfikowano lokalnie (2026-09-11): Core API NestJS z walidacją konfiguracji, logowaniem pino i correlation id; lokalny PostgreSQL 18 w Dockerze (`infra/dev`, uuidv7 potwierdzone); Prisma 7.9.1 ze schematem bez modeli, importowana wyłącznie w `infrastructure/persistence`; liveness i readiness (200/503 bez ujawniania sekretów); 63 testy jednostkowe i 12 integracyjnych z prawdziwą bazą (Testcontainers); Dockerfile, polityka zależności, SBOM i skan sekretów. Zdefiniowano workflow CI (pierwsze uruchomienie po pierwszym pushu) oraz izolowany Compose homelab (`infra/homelab`). Czego nie ma: tabel, modeli i migracji domenowych, branch/release policy poza notą w 07, pełnego katalogu health z 04 §21 — **M9 nie jest zamknięty**. Runbook: [`operations/M9-PostgreSQL-Prisma-CC-Runbook.md`](operations/M9-PostgreSQL-Prisma-CC-Runbook.md).

**Kod domenowy (M10) nadal czeka na M4–M8 oraz na zamknięcie M3: Gate OS-1, Gate OS-2-LAB, Gate OS-3-LAB i przyjęte rozstrzygnięcia ADR-014, ADR-015 i ADR-016. Paperless nie jest połączony z Core, WireGuard (ADR-020) jest planowany, nie skonfigurowany. Pełny Gate OS-2 produktu jest bramą M17, a Gate OS-3-RELEASE — bramą M22.**
