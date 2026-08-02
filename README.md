# HomeOS

Repozytorium dokumentacji, laboratorium i kodu projektu domowego segregatora.

## Stan

- M0–M2 są zamknięte dokumentacyjnie.
- Baseline M3 to Paperless-ngx 3.0.4 z przypiętym digestem.
- Laboratorium Paperless 3.0.4 działało na Debianie 13; E1, E2, E3A i E3B zostały wykonane. E3A powtórzono z wymuszonym punktem spójności i przeszedł dla Restica i Borga, co zamyka Gate OS-2-LAB w zakresie laboratoryjnym.
- M3 pozostaje otwarty: Gate OS-1 czeka na rzeczywiste skany, a ADR-015 na test docelowego storage 4 TB.
- Rozpoczęto M9 Engineering Foundation. Pierwszym workspace jest minimalne
  NestJS Core API w `apps/api` z endpointem liveness.

Zacznij od [`Docs/README.md`](Docs/README.md). Aktualny stan bram i czynności użytkownika opisują [`Docs/operations/spike-results/10-decisions-and-gates.md`](Docs/operations/spike-results/10-decisions-and-gates.md) oraz [`Docs/operations/spike-results/12-user-checklist.md`](Docs/operations/spike-results/12-user-checklist.md).

Katalog `lab/` jest jednorazowym środowiskiem E1, E2, E3A i E3B. Nie jest fundamentem przyszłego monorepo ani konfiguracją produkcyjną.

Walidacja dokumentacji:

```sh
node scripts/validate-docs.mjs
```

## Narzędzia projektu

- Node.js 24 LTS; wersję referencyjną zapisuje `.node-version`.
- pnpm 11.18.0 i jeden `pnpm-lock.yaml` dla całego monorepo.
- Pakiety są pobierane z `https://registry.npmjs.org/` zgodnie z `.npmrc`.
- pnpm workspaces bez Turborepo i Nx.

Nie używaj `npm install`, Yarn ani globalnego Nest CLI. Dokładna wersja pnpm
jest zapisana w `packageManager` głównego `package.json`.

## Pierwsze uruchomienie po sklonowaniu

Sprawdź wersje:

```sh
node --version
pnpm --version
```

Na macOS, jeżeli pnpm został zainstalowany przez Homebrew i ma inną wersję:

```sh
brew upgrade pnpm
```

Na hoście bez osobnej instalacji pnpm użyj Corepack:

```sh
corepack enable
corepack install --global pnpm@11.18.0
```

Po instalacji `pnpm --version` musi zwrócić `11.18.0`; inna wersja zostanie
celowo odrzucona przed uruchomieniem skryptów projektu.

Zainstaluj dokładnie zależności z lockfile i uruchom wszystkie kontrole:

```sh
pnpm install --frozen-lockfile
pnpm check
```

Uruchom Core API w trybie developerskim:

```sh
pnpm dev
```

API nasłuchuje domyślnie wyłącznie lokalnie. Test liveness:

```sh
curl http://127.0.0.1:3000/api/v1/health/live
```

Oczekiwana odpowiedź:

```json
{"service":"homeos-api","status":"ok"}
```

## Dodawanie zależności

Zależność konkretnej aplikacji dodawaj do jej workspace:

```sh
pnpm --filter @homeos/api add nazwa-pakietu
pnpm --filter @homeos/api add --save-dev nazwa-narzędzia
```

Narzędzie wspólne dla całego repo dodawaj świadomie do root:

```sh
pnpm add --workspace-root --save-dev nazwa-narzędzia
```

Każda zmiana zależności musi aktualizować i zachować `pnpm-lock.yaml`.
`node_modules`, buildy, coverage, lokalne `.env`, dane laboratorium, sekrety i
pliki IDE są ignorowane i nie mogą trafić do Git.
