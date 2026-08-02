# 09 — Architecture Decisions Index

**Status:** `accepted` · **Milestone:** M2 · **Data:** 2026-07-28

Indeks decyzji architektonicznych. `07-Product-and-Delivery-Roadmap.md` §7 określa 18 ADR-ów minimalnych; ADR-019 doprecyzowuje granicę operacyjną odkrytą podczas audytu gotowości.

Szablon: [`ADR-TEMPLATE.md`](ADR-TEMPLATE.md)

---

## 1. Stan

| Status | Liczba | Znaczenie |
|---|---|---|
| `accepted` | **16** | Obowiązuje. Zmiana wymaga nowego ADR. |
| `proposed` | **3** | Ma zapisany warunek lub eksperyment rozstrzygający. |
| `deprecated` | **1** | Zastąpiony nowszym ADR. |

---

## 2. Indeks

| ADR | Tytuł | Status | Rozstrzyga / rozstrzygnięty przez | Brama |
|---|---|---|---|---|
| [ADR-001](ADR-001-monolit-modularny.md) | Monolit modułowy | `accepted` | Decyzja z 01 §33.15, 03 §5, 05 §14, 07 §7 | M2 |
| [ADR-002](ADR-002-nestjs-core-api.md) | NestJS jako Core API | `accepted` | Decyzja z 03 §7, 05 §14, 07 §7 | M2 |
| [ADR-003](ADR-003-nextjs-web-pwa.md) | Next.js jako web/PWA | `accepted` | Decyzja z 03 §6, 05 §13, 07 §7 | M2 |
| [ADR-004](ADR-004-postgresql-core.md) | PostgreSQL jako baza Core | `accepted` | Decyzja z 03 §9, 05 §6, 07 §7 | M2 |
| [ADR-005](ADR-005-paperless-bounded-context.md) | Paperless-ngx jako Document Bounded Context | `accepted` | Decyzja z 03 §12, 05 §5, 07 §7 | M2 |
| [ADR-006](ADR-006-paperless-wlascicielem-binariow.md) | Paperless właścicielem binariów na MVP | `accepted` | Decyzja z 03 §12.1, 05 §28, 07 §7 | M2 |
| [ADR-007](ADR-007-api-only-integration.md) | Integracja aplikacyjna wyłącznie przez API | `accepted` | Decyzja z 03 §13, 05 §5.4, 07 §7; granica utrzymaniowa w ADR-019 | M2 |
| [ADR-008](ADR-008-valkey-bullmq.md) | Valkey + BullMQ | `accepted` | Decyzja z 05 §7–§8, 07 §7. **Zastępuje Redis z 03 i 04** (R-01) | M2 |
| [ADR-009](ADR-009-postgresql-fts.md) | PostgreSQL FTS przed osobnym silnikiem wyszukiwania | `accepted` | Decyzja z 03 §19, 05 §19, 07 §7 | M2 |
| [ADR-010](ADR-010-caddy-gateway.md) | Caddy jako jedyny gateway | `accepted` | Decyzja z 04 §10, 05 §11, 07 §7 | M2 |
| [ADR-011](ADR-011-wireguard-remote-access.md) | Opcjonalny WireGuard | `deprecated` | Zastąpiony przez ADR-020 | M2 |
| [ADR-012](ADR-012-model-auth-mvp.md) | Model auth MVP | `accepted` | Decyzja z 03 §21, 05 §20, 07 §7 | M2 |
| [ADR-013](ADR-013-storage-provider.md) | Storage provider | `accepted` | Lokalny filesystem za portem; decyzja niezależna od Paperless | M2 |
| [ADR-014](ADR-014-orm.md) | ORM | `accepted` | **Prisma**; oba PoC przeszły, decyzja uwzględnia LTS i wieloletnie utrzymanie | M3/M9 |
| [ADR-015](ADR-015-narzedzie-backupu.md) | Narzędzie backupu | **`proposed`** | **E3A + E3B wykonane 2026-07-31** — oba kandydaty PASS; rekomendacja wstępna Restic. Blokuje ocena docelowego storage 4 TB | M3/M17 |
| [ADR-016](ADR-016-polityka-licencyjna.md) | Polityka licencyjna | `accepted` | Gate OS-3-LAB przeszedł 2026-07-31; OS-3-RELEASE pozostaje bramą M22 | M3/M22 |
| [ADR-017](ADR-017-state-machines-reconciliation.md) | State machines i reconciliation | **`proposed`** | Domknięcie w M4 (model danych) i M6 (kontrakt integracji) | M4 |
| [ADR-018](ADR-018-audit-policy.md) | Audit policy | **`proposed`** | Domknięcie w M5 (uprawnienia i prywatność) | M5 |
| [ADR-019](ADR-019-paperless-maintenance-interface.md) | Interfejs utrzymaniowy Paperless | `accepted` | REST w `DocumentProvider`; exporter/importer wyłącznie operacyjnie | M2 |
| [ADR-020](ADR-020-self-hosted-wireguard-access.md) | Samodzielny WireGuard jako jedyna droga dostępu zdalnego | `accepted` | Zastępuje opcjonalność ADR-011; LAN najpierw, manualny klient w MVP, natywna aplikacja później | M4/M18 |

---

## 3. ADR-y i uzupełnienia rozstrzygane w Fazie 1

To rozróżnienie jest istotne wykonawczo. **Nie jest to jeden eksperyment o trzech aspektach.**

| ADR | Eksperyment | Na czym polega | Czego NIE rozstrzyga |
|---|---|---|---|
| **ADR-014** ORM | **E2 — zakończony** | Prisma wybrana po identycznym PoC i przeglądzie ryzyka utrzymania: dynamiczne pola, transakcje, audit, FTS, migracja i restore. **Bez udziału Paperless** | Eksperyment Paperless — ORM nie ma z nim styku |
| **ADR-015** Backup | **E3A + E3B** | Dla Restic i Borg: importer/exporter oraz osobny restore dumpów baz i plików, z integralnością, przerwaniem, kluczami i retencją | Porównanie funkcji na papierze ani uznanie samego importu za disaster recovery |
| **ADR-008** Valkey | **E1** | Uzupełnienie topologii na podstawie pomiaru Paperless i osobnego harnessu BullMQ | Wybór biblioteki kolejki |
| **ADR-016** Licencje | **OS-3-LAB** | Inwentarz źródeł, wersji/digestów i licencji komponentów laboratorium; akceptacja prywatnego modelu użycia | Pełna zgodność dystrybucyjna produktu — wraca jako OS-3-RELEASE w M22 |

ADR-013 jest już `accepted`; E3B jedynie potwierdza odtwarzalność lokalnego katalogu assetów na fixture laboratoryjnym.

Plan wykonawczy: [`../operations/spike-plan.md`](../operations/spike-plan.md)

---

## 4. Decyzje otwarte poza ADR

Nie każda otwarta decyzja wymaga ADR. Pełny rejestr 38 decyzji blokujących w podziale na grupy bram **G1–G6** znajduje się w [`../00-Analiza-i-Mapa-Realizacji.md`](../00-Analiza-i-Mapa-Realizacji.md) §15.

| Grupa | Blokuje bramę | Decyzje wymagające ADR |
|---|---|---|
| **G1** | M3 — spike | — (zapisane w `08-MVP-Scope.md` §5) |
| **G2** | M9 — fundament | ADR-014 (ORM), uzupełnienie ADR-008 (topologia Valkey) |
| **G3** | M10 — domena | ADR-012 (polityka sesji), ADR-018 (audit policy) |
| **G4** | M12 — upload | **Nowy ADR: zachowanie uploadu przy awarii Paperless (G4-06)** |
| **G5** | M13/M14 — search | ADR-018 (dziedziczenie dostępu), część w `11-Permissions-and-Privacy.md` |
| **G6** | M17 — backup i infrastruktura | ADR-015 (narzędzie), ADR-020 (hardening i provisioning WireGuard) |

---

## 5. Zasada

1. **Treść decyzji w przyjętym ADR nie jest zmieniana.** Korekta językowa, link, doprecyzowanie zakresu już wynikającego z nowszego ADR lub opis weryfikacji są dozwolone i trafiają do changelogu. Zmiana wyboru, jego skutków albo granic = nowy ADR + `deprecated` na starym.
2. **Status `proposed` bez zapisanego warunku rozstrzygającego jest błędem.**
3. Nowy komponent technologiczny wymaga ADR **oraz** przejścia 16-krokowego procesu z `../architecture/05-Open-Source-Architecture.md` §24.
4. Decyzja sprzeczna z obowiązującym ADR **nie wchodzi do kodu** — najpierw zmienia się ADR.
