# infra/dev — lokalna baza Core PostgreSQL 18

Jedna usługa `core-db` (obraz `postgres:18` przypięty digestem) dla developmentu
na laptopie. Projekt Compose nazywa się `homeintelcore-local`.

## Uruchamianie

Wszystkie komendy z root repo, ze zmiennymi z `.env` (tworzy je `pnpm dev:setup`):

```sh
docker compose --env-file .env -f infra/dev/compose.yaml config --quiet
docker compose --env-file .env -f infra/dev/compose.yaml up -d --wait
docker compose --env-file .env -f infra/dev/compose.yaml ps
docker compose --env-file .env -f infra/dev/compose.yaml logs --tail 100 core-db
```

Port bazy jest publikowany wyłącznie na `127.0.0.1:${HOMEINTELCORE_DB_PORT:-55432}`;
z sieci lokalnej baza nie jest widoczna.

## Dane

Dane leżą w nazwanym wolumenie Dockera `homeintelcore-local-core-db-data`
(montowanym w `/var/lib/postgresql` kontenera). Wolumen przeżywa `stop` i `down`.

## Zatrzymanie bez utraty danych

```sh
docker compose --env-file .env -f infra/dev/compose.yaml stop
# albo usunięcie kontenera z zachowaniem wolumenu:
docker compose --env-file .env -f infra/dev/compose.yaml down
```

Nie używaj `down -v`. Reset bazy (usunięcie wolumenu) to osobny, jawnie
potwierdzany skrypt koordynatora `pnpm db:reset` — operacja nieodwracalna.

Baza ma `restart: "no"`: po restarcie laptopa trzeba ją uruchomić ponownie.
