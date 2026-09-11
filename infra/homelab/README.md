# infra/homelab — izolowany test M9 na VM

Cel: uruchomić Core PostgreSQL 18 + API na VM Debian 13 (Docker 29, Compose 5.x)
jako izolowany test milestone'u M9. To **nie jest produkcja**: brak Caddy,
WireGuard, systemd, autostartu. API jest dostępne wyłącznie lokalnie na
serwerze (`127.0.0.1:3100`), baza nie publikuje żadnego portu.

## Granica bezpieczeństwa wobec laboratorium M3

Na tej samej VM działa `homeos-m3-source` w `/srv/homeos`. Ten stack:

- używa własnego projektu `homeintelcore-dev` i własnej sieci bridge
  `homeintelcore-dev` (żadnego `external`, żadnego odwołania do
  `homeos-m3-source_default`),
- nie montuje niczego z `/srv/homeos` ani `/var/run/docker.sock`,
- ma własny wolumen `homeintelcore-dev-core-db-data`.

## Procedura dla operatora (na VM, w katalogu repo)

```sh
# 1. Repo: klon albo fast-forward
git clone <url> homeintelcore && cd homeintelcore      # pierwszy raz
git pull --ff-only                                       # kolejne razy

# 2. Sekret: losowe hasło, bez wypisywania na ekran
umask 077; printf 'HOMEINTELCORE_DB_USER=homeintelcore\nHOMEINTELCORE_DB_NAME=homeintelcore\nHOMEINTELCORE_DB_PASSWORD=%s\nLOG_LEVEL=info\n' "$(openssl rand -hex 24)" > infra/homelab/.env; chmod 600 infra/homelab/.env

# 3. Walidacja, pobranie obrazu bazy, build API, start
docker compose -f infra/homelab/compose.yaml --env-file infra/homelab/.env config --quiet
docker compose -f infra/homelab/compose.yaml --env-file infra/homelab/.env pull core-db
docker compose -f infra/homelab/compose.yaml --env-file infra/homelab/.env build api
docker compose -f infra/homelab/compose.yaml --env-file infra/homelab/.env up -d --wait
docker compose -f infra/homelab/compose.yaml --env-file infra/homelab/.env ps

# 4. Weryfikacja
curl --fail http://127.0.0.1:3100/api/v1/health/live
curl --fail http://127.0.0.1:3100/api/v1/health/ready
ss -lnt      # oczekiwane dla tego stacku: tylko 127.0.0.1:3100
```

Z Maca, przez tunel SSH (API nie wychodzi poza loopback VM):

```sh
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:3100:127.0.0.1:3100 homeoslab@<host>
curl --fail http://127.0.0.1:3100/api/v1/health/ready
```

## Zatrzymanie (wolumen zostaje)

```sh
docker compose -f infra/homelab/compose.yaml --env-file infra/homelab/.env stop
```

## Czego nie robić

- `down -v` ani ręczne usuwanie `homeintelcore-dev-core-db-data` — utrata danych,
- `docker system prune`, `docker volume prune`, `docker network prune`,
- dotykanie kontenerów, wolumenów i sieci `homeos-m3-source-*` / `/srv/homeos`,
- publikowanie portów na `0.0.0.0` ani dodawanie stacku do Caddy/WireGuard,
- commitowanie `infra/homelab/.env`.
