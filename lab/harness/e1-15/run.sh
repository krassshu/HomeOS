#!/usr/bin/env bash
# E1-15 — pełny harness BullMQ w dwóch wariantach topologii Valkey.
#
#   shared — BullMQ korzysta z tego samego brokera co Paperless, z własnym prefiksem
#   split  — BullMQ korzysta z osobnej, izolowanej instancji Valkey
#
# Wariant `split` używa tymczasowego kontenera z tym samym przypiętym obrazem,
# zamiast przełączać projekt source na `compose.valkey-split.yaml`. Dzięki temu
# konfiguracja source nie zmienia się ani na chwilę.
#
# Skrypt nie dotyka kluczy Paperless: pracuje wyłącznie we własnym prefiksie
# i na końcu go sprząta.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../e1/common.sh
source "$HERE/../e1/common.sh"

NODE_IMAGE="${NODE_IMAGE:-docker.io/library/node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d}"
VALKEY_IMAGE="${VALKEY_IMAGE:-valkey/valkey:9-alpine@sha256:ee91f7a174ac4d6a6b0685b3a60e321f0a9dbbb691f9b0e285be2ba1d1be8328}"
NETWORK="${E1_15_NETWORK:-${M3_PROJECT}_default}"
NODE_MODULES_VOLUME="${E1_15_NODE_MODULES:-homeos-m3-e1-15-node-modules}"
SPLIT_BROKER="${E1_15_SPLIT_BROKER:-homeos-m3-lab-e1-15-broker}"
QUEUE_PREFIX="${E1_15_PREFIX:-homeos-core}"
ENV_FILE="${M3_ENV_FILE:-${M3_LAB_DIR}/.env.${M3_TARGET}}"

usage() {
  cat <<'EOF'
Użycie: ./run.sh [--variant shared|split|both] [--raw-dir KATALOG]

Wykonuje scenariusze E1-15b i pomiary E1-15a/E1-15c.
Kody wyjścia: 0 PASS, 1 błąd, 2 błąd użycia, 3 warunek wstępny, 4 FAIL, 5 odmowa.
EOF
}

VARIANTS="both"
while [ $# -gt 0 ]; do
  case "$1" in
    --variant) VARIANTS="${2:?brak wartości}"; shift 2 ;;
    --raw-dir) M3_RAW_DIR="${2:?brak wartości}"; shift 2 ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done
case "$VARIANTS" in shared|split|both) ;; *) m3_die "$M3_EXIT_USAGE" "nieznany wariant: $VARIANTS" ;; esac

m3_require_cmds docker python3
m3_require_project
m3_mkdir "$M3_RAW_DIR"

[ -f "$ENV_FILE" ] || m3_die "$M3_EXIT_PRECONDITION" "brak pliku środowiska: $ENV_FILE"
# shellcheck disable=SC1090
CORE_DB_PASSWORD="$(grep '^CORE_FIXTURE_DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)"
[ -n "$CORE_DB_PASSWORD" ] || m3_die "$M3_EXIT_PRECONDITION" "brak CORE_FIXTURE_DB_PASSWORD"

FAILURES=0
check() { if [ "$2" = "yes" ]; then m3_log "  OK   $1"; else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); fi; }

cleanup() {
  local rc=$?
  trap - EXIT
  set +e
  m3_section "sprzątanie"
  docker rm -f "$SPLIT_BROKER" >/dev/null 2>&1 && m3_log "  usunięto tymczasowy broker $SPLIT_BROKER"
  # Klucze harnessu znikają z brokera źródła; klucze Paperless zostają nietknięte.
  local left
  left="$(docker exec "${M3_PROJECT}-broker-1" sh -c "valkey-cli --scan --pattern '${QUEUE_PREFIX}:*' | head -1" 2>/dev/null || true)"
  if [ -n "$left" ]; then
    docker exec "${M3_PROJECT}-broker-1" sh -c \
      "valkey-cli --scan --pattern '${QUEUE_PREFIX}:*' | xargs -r -n 100 valkey-cli DEL" >/dev/null 2>&1
    m3_log "  usunięto pozostałe klucze prefiksu ${QUEUE_PREFIX} z brokera źródła"
  fi
  exit "$rc"
}
trap cleanup EXIT

m3_section "0. Przygotowanie zależności Node"
docker volume create "$NODE_MODULES_VOLUME" >/dev/null
docker run --rm \
  -v "$HERE:/harness:ro" \
  -v "$NODE_MODULES_VOLUME:/work/node_modules" \
  -w /work \
  "$NODE_IMAGE" \
  sh -c 'cp /harness/package.json /work/ && npm install --no-audit --no-fund --silent && node -e "console.log(\"bullmq\", require(\"bullmq/package.json\").version, \"pg\", require(\"pg/package.json\").version)"' \
  | sed 's/^/  /'

# Liczba kluczy pasujących do wzorca w danym brokerze.
count_keys() { # count_keys <kontener> <wzorzec>
  docker exec "$1" sh -c "valkey-cli --scan --pattern '$2' | wc -l" 2>/dev/null | tr -d '\r'
}
used_memory() { # used_memory <kontener>
  docker exec "$1" valkey-cli INFO memory 2>/dev/null | tr -d '\r' | sed -n 's/^used_memory://p'
}

run_variant() { # run_variant <shared|split>
  local variant="$1" broker_container broker_host
  m3_section "Wariant ${variant}"

  if [ "$variant" = "shared" ]; then
    broker_container="${M3_PROJECT}-broker-1"
    broker_host="broker"
  else
    docker rm -f "$SPLIT_BROKER" >/dev/null 2>&1 || true
    docker run -d --name "$SPLIT_BROKER" --network "$NETWORK" \
      "$VALKEY_IMAGE" valkey-server --save "" --appendonly no >/dev/null
    for _ in $(seq 1 30); do
      docker exec "$SPLIT_BROKER" valkey-cli PING 2>/dev/null | grep -q PONG && break
      sleep 1
    done
    broker_container="$SPLIT_BROKER"
    broker_host="$SPLIT_BROKER"
  fi

  local paperless_before harness_before mem_before
  paperless_before="$(count_keys "${M3_PROJECT}-broker-1" '*')"
  harness_before="$(count_keys "$broker_container" "${QUEUE_PREFIX}:*")"
  mem_before="$(used_memory "$broker_container")"
  m3_log "  broker=${broker_host} (kontener ${broker_container})"
  m3_log "  kluczy_w_brokerze_paperless_przed=${paperless_before}"
  m3_log "  kluczy_prefiksu_harnessu_przed=${harness_before}"
  m3_log "  used_memory_przed=${mem_before}"

  local out_json="$M3_RAW_DIR/e1-15-${variant}.json"
  local started ended
  started="$(date +%s)"
  set +e
  docker run --rm \
    --network "$NETWORK" \
    -v "$HERE:/harness:ro" \
    -v "$NODE_MODULES_VOLUME:/work/node_modules" \
    -w /work \
    -e VALKEY_HOST="$broker_host" \
    -e VALKEY_PORT=6379 \
    -e QUEUE_PREFIX="$QUEUE_PREFIX" \
    -e VARIANT="$variant" \
    -e DATABASE_URL="postgresql://core_fixture:${CORE_DB_PASSWORD}@core_fixture_db:5432/core_fixture" \
    "$NODE_IMAGE" \
    sh -c 'cp /harness/*.mjs /harness/package.json /work/ && node scenarios.mjs' \
    > "$out_json" 2> "$M3_RAW_DIR/e1-15-${variant}.err"
  local rc=$?
  set -e
  ended="$(date +%s)"

  if [ "$rc" -ne 0 ] && [ ! -s "$out_json" ]; then
    m3_log "  BŁĄD uruchomienia scenariuszy (rc=$rc):"
    tail -15 "$M3_RAW_DIR/e1-15-${variant}.err" | sed 's/^/    /'
    FAILURES=$((FAILURES + 1))
    [ "$variant" = "split" ] && docker rm -f "$SPLIT_BROKER" >/dev/null 2>&1
    return 0
  fi

  python3 - "$out_json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for key, value in d["scenariusze"].items():
    mark = "OK  " if value["pass"] else "FAIL"
    print(f"  {mark} {key}: {value['opis']}")
    for field, fv in value.items():
        if field in ("opis", "pass"):
            continue
        print(f"         {field}={fv}")
PY

  local paperless_after harness_after mem_after
  paperless_after="$(count_keys "${M3_PROJECT}-broker-1" '*')"
  harness_after="$(count_keys "$broker_container" "${QUEUE_PREFIX}:*")"
  mem_after="$(used_memory "$broker_container")"
  m3_log "  czas_scenariuszy=$((ended - started))s"
  m3_log "  kluczy_w_brokerze_paperless_po=${paperless_after}"
  m3_log "  kluczy_prefiksu_harnessu_po=${harness_after}"
  m3_log "  used_memory_po=${mem_after}"
  m3_log "  przyrost_pamięci_B=$((mem_after - mem_before))"

  local variant_pass
  variant_pass="$(python3 -c '
import json,sys
print("yes" if json.load(open(sys.argv[1]))["pass"] else "no")' "$out_json")"
  check "wszystkie scenariusze wariantu ${variant} przeszły" "$variant_pass"

  # Kolizja prefiksów: harness nie może dotknąć kluczy Paperless.
  local celery_keys
  celery_keys="$(count_keys "${M3_PROJECT}-broker-1" 'celery*')"
  m3_log "  kluczy_celery_paperless=${celery_keys}"
  check "harness nie zmniejszył liczby kluczy Paperless (${paperless_before} → ${paperless_after})" \
    "$([ "$paperless_after" -ge "$paperless_before" ] && echo yes || echo no)"
  if [ "$variant" = "shared" ]; then
    check "prefiks harnessu i klucze Paperless są rozłączne" \
      "$([ "$(count_keys "${M3_PROJECT}-broker-1" "${QUEUE_PREFIX}:celery*")" = "0" ] && echo yes || echo no)"
  else
    check "broker Paperless nie zawiera kluczy harnessu" \
      "$([ "$(count_keys "${M3_PROJECT}-broker-1" "${QUEUE_PREFIX}:*")" = "0" ] && echo yes || echo no)"
  fi

  {
    echo "wariant=${variant}"
    echo "broker=${broker_host}"
    echo "czas_s=$((ended - started))"
    echo "used_memory_przed=${mem_before}"
    echo "used_memory_po=${mem_after}"
    echo "przyrost_pamięci_B=$((mem_after - mem_before))"
    echo "kluczy_paperless_przed=${paperless_before}"
    echo "kluczy_paperless_po=${paperless_after}"
    echo "kluczy_harnessu_po=${harness_after}"
    echo "kluczy_celery=${celery_keys}"
  } > "$M3_RAW_DIR/e1-15-${variant}-measurements.txt"

  if [ "$variant" = "split" ]; then
    docker rm -f "$SPLIT_BROKER" >/dev/null 2>&1 || true
    m3_log "  tymczasowy broker usunięty"
  fi
}

m3_section "1. Pomiar bazowy Paperless (E1-15a)"
BASE_KEYS="$(count_keys "${M3_PROJECT}-broker-1" '*')"
BASE_MEM="$(used_memory "${M3_PROJECT}-broker-1")"
m3_log "  kluczy_paperless=${BASE_KEYS}"
m3_log "  used_memory_paperless=${BASE_MEM}"
{
  echo "kluczy_paperless=${BASE_KEYS}"
  echo "used_memory_paperless=${BASE_MEM}"
} > "$M3_RAW_DIR/e1-15a-baseline.txt"

case "$VARIANTS" in
  shared) run_variant shared ;;
  split)  run_variant split ;;
  both)   run_variant shared; run_variant split ;;
esac

m3_section "Podsumowanie E1-15"
m3_log "  kontroli nieudanych: $FAILURES"
m3_log "  wyniki: $M3_RAW_DIR"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
