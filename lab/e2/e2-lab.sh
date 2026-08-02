#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LAB_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
REPO_DIR=$(cd -- "${LAB_DIR}/.." && pwd)
DATA_DIR="${E2_DATA_DIR:-${REPO_DIR}/lab-data/e2}"
ENV_FILE="${E2_ENV_FILE:-${LAB_DIR}/.env.source}"

NODE_IMAGE='docker.io/library/node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d'
COMPOSE_PROJECT="${E2_COMPOSE_PROJECT:-homeos-m3-source}"
COMPOSE_NETWORK="${E2_COMPOSE_NETWORK:-homeos-m3-source_default}"
DB_USER="${E2_DB_USER:-core_fixture}"
NODE_MODULES_VOLUME="${E2_NODE_MODULES_VOLUME:-homeos-m3-e2-node-modules}"

usage() {
  cat <<'EOF'
Użycie:
  ./e2-lab.sh prepare   pobiera zależności i generuje klienta Prisma
  ./e2-lab.sh config    sprawdza środowisko bez zmiany baz
  ./e2-lab.sh run       odtwarza cztery bazy E2 i wykonuje E2-01…E2-07
  ./e2-lab.sh results   wyświetla skrót ostatnich wyników

Polecenie run usuwa wyłącznie bazy homeos_e2_* należące do laboratorium.
EOF
}

die() {
  printf 'BŁĄD: %s\n' "$*" >&2
  exit 1
}

load_environment() {
  if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
  fi
  [[ -n "${CORE_FIXTURE_DB_PASSWORD:-}" ]] ||
    die "Brak CORE_FIXTURE_DB_PASSWORD w środowisku albo ${ENV_FILE}."
  [[ "${CORE_FIXTURE_DB_PASSWORD}" =~ ^[A-Za-z0-9._~-]+$ ]] ||
    die "Hasło fixture musi być URL-safe; generator hex użyty w M3 spełnia ten warunek."
}

db_container() {
  docker ps \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}" \
    --filter 'label=com.docker.compose.service=core_fixture_db' \
    --format '{{.ID}}' |
    head -n 1
}

require_runtime() {
  command -v docker >/dev/null || die "Docker nie jest dostępny."
  docker network inspect "${COMPOSE_NETWORK}" >/dev/null 2>&1 ||
    die "Sieć ${COMPOSE_NETWORK} nie istnieje. Uruchom wcześniej source/shared."
  DB_CONTAINER=$(db_container)
  [[ -n "${DB_CONTAINER}" ]] || die "Kontener core_fixture_db nie działa."
  export DB_CONTAINER
}

database_url() {
  local database_name=$1
  printf 'postgresql://%s:%s@core_fixture_db:5432/%s' \
    "${DB_USER}" "${CORE_FIXTURE_DB_PASSWORD}" "${database_name}"
}

node_run() {
  local database_name=$1
  local mode=$2
  local result_name=$3
  shift 3

  docker run --rm \
    --network "${COMPOSE_NETWORK}" \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,src=${SCRIPT_DIR},dst=/workspace,readonly" \
    --mount "type=volume,src=${NODE_MODULES_VOLUME},dst=/workspace/node_modules" \
    --mount "type=bind,src=${DATA_DIR}/results,dst=/results" \
    --workdir /workspace \
    --env HOME=/tmp/e2-home \
    --env NPM_CONFIG_CACHE=/tmp/e2-npm-cache \
    --env "DATABASE_URL=$(database_url "${database_name}")" \
    --env "E2_MODE=${mode}" \
    --env "E2_RESULT_PATH=/results/${result_name}" \
    "${NODE_IMAGE}" "$@"
}

prepare_dependencies() {
  install -d -m 700 \
    "${DATA_DIR}/results" \
    "${DATA_DIR}/dumps"

  docker volume create "${NODE_MODULES_VOLUME}" >/dev/null
  docker run --rm \
    --mount "type=volume,src=${NODE_MODULES_VOLUME},dst=/workspace/node_modules" \
    "${NODE_IMAGE}" \
    chown -R "$(id -u):$(id -g)" /workspace/node_modules

  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,src=${SCRIPT_DIR},dst=/workspace,readonly" \
    --mount "type=volume,src=${NODE_MODULES_VOLUME},dst=/workspace/node_modules" \
    --workdir /workspace \
    --env HOME=/tmp/e2-home \
    --env NPM_CONFIG_CACHE=/tmp/e2-npm-cache \
    "${NODE_IMAGE}" \
    npm ci --ignore-scripts

  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,src=${SCRIPT_DIR},dst=/workspace,readonly" \
    --mount "type=volume,src=${NODE_MODULES_VOLUME},dst=/workspace/node_modules" \
    --workdir /workspace \
    --env HOME=/tmp/e2-home \
    --env NPM_CONFIG_CACHE=/tmp/e2-npm-cache \
    --env "DATABASE_URL=$(database_url homeos_e2_prisma)" \
    "${NODE_IMAGE}" \
    npm run generate:prisma
}

recreate_database() {
  local database_name=$1
  docker exec "${DB_CONTAINER}" \
    dropdb --if-exists --force --username "${DB_USER}" "${database_name}"
  docker exec "${DB_CONTAINER}" \
    createdb --username "${DB_USER}" --owner "${DB_USER}" "${database_name}"
}

dump_and_restore() {
  local candidate=$1
  local source_database="homeos_e2_${candidate}"
  local restore_database="${source_database}_restore"
  local dump_path="${DATA_DIR}/dumps/${candidate}.dump"

  docker exec "${DB_CONTAINER}" \
    pg_dump --username "${DB_USER}" --format=custom "${source_database}" \
    >"${dump_path}"

  recreate_database "${restore_database}"
  docker exec -i "${DB_CONTAINER}" \
    pg_restore \
      --username "${DB_USER}" \
      --dbname "${restore_database}" \
      --exit-on-error \
    <"${dump_path}"
}

run_candidate() {
  local candidate=$1
  local database_name="homeos_e2_${candidate}"

  recreate_database "${database_name}"
  node_run "${database_name}" fresh "${candidate}-fresh.json" \
    npm run "migrate:${candidate}"
  node_run "${database_name}" fresh "${candidate}-fresh.json" \
    npm run "run:${candidate}"

  dump_and_restore "${candidate}"
  node_run "${database_name}_restore" restore "${candidate}-restore.json" \
    npm run "run:${candidate}"
}

show_results() {
  local result
  for result in "${DATA_DIR}"/results/*.json; do
    [[ -e "${result}" ]] || continue
    jq -r '
      "\(.candidate)/\(.mode): " +
      (if .passed then "PASS" else "FAIL" end) +
      " [" + ([.trials[].id] | join(", ")) + "]"
    ' "${result}"
  done
}

command=${1:-}
case "${command}" in
  prepare)
    require_runtime
    load_environment
    prepare_dependencies
    ;;
  config)
    require_runtime
    load_environment
    docker image inspect "${NODE_IMAGE}" \
      --format 'Node image={{index .RepoDigests 0}} arch={{.Architecture}}' ||
      die "Przypięty obraz Node nie jest pobrany."
    printf 'PostgreSQL: '
    docker exec "${DB_CONTAINER}" postgres --version
    printf 'Sieć=%s DB container=%s\n' "${COMPOSE_NETWORK}" "${DB_CONTAINER}"
    ;;
  run)
    require_runtime
    load_environment
    prepare_dependencies
    node_run "homeos_e2_drizzle" fresh unused.json npm run typecheck
    run_candidate drizzle
    run_candidate prisma
    show_results
    ;;
  results)
    command -v jq >/dev/null || die "Do odczytu wyników wymagany jest jq."
    show_results
    ;;
  *)
    usage
    exit 2
    ;;
esac
