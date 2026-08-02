#!/usr/bin/env bash
# Wspólne helpery skryptów E1. Plik jest przeznaczony do `source`, nie do uruchamiania.
set -Eeuo pipefail

# Kody wyjścia wspólne dla wszystkich skryptów E1.
readonly M3_EXIT_OK=0
readonly M3_EXIT_ERROR=1
readonly M3_EXIT_USAGE=2
readonly M3_EXIT_PRECONDITION=3
readonly M3_EXIT_FAIL=4
readonly M3_EXIT_REFUSED=5

M3_PROJECT="${M3_PROJECT:-homeos-m3-source}"
M3_TARGET="${M3_TARGET:-source}"
M3_VALKEY="${M3_VALKEY:-shared}"
M3_WEBSERVER="${M3_WEBSERVER:-${M3_PROJECT}-webserver-1}"
M3_API="${M3_API:-http://127.0.0.1:8000/api}"
M3_API_VERSION="${M3_API_VERSION:-10}"
M3_RAW_DIR="${M3_RAW_DIR:-./raw}"
M3_HTTP_TIMEOUT="${M3_HTTP_TIMEOUT:-60}"

# Dokumenty, których skrypty nie wolno usuwać. Nadpisywalne, ale nigdy puste.
M3_PROTECTED_DOCS="${M3_PROTECTED_DOCS:-1 2 3 4 5 6 7 8 9}"

M3_LAB_DIR="${M3_LAB_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"

M3_CURL_CFG=""

m3_log() { printf '%s\n' "$*"; }
m3_section() { printf '\n=== %s ===\n' "$*"; }

m3_die() { # m3_die <kod> <komunikat>
  local code="$1"; shift
  printf 'BŁĄD: %s\n' "$*" >&2
  exit "$code"
}

m3_require_cmds() {
  local missing=()
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  [ ${#missing[@]} -eq 0 ] || m3_die "$M3_EXIT_PRECONDITION" "brak wymaganych poleceń: ${missing[*]}"
}

m3_mkdir() { install -d -m 700 "$@"; }

# Odmowa pracy na nieoczekiwanym projekcie Compose.
m3_require_project() {
  local expected="${M3_EXPECT_PROJECT:-homeos-m3-source}"
  [ "$M3_PROJECT" = "$expected" ] || m3_die "$M3_EXIT_REFUSED" \
    "odmowa: projekt Compose '$M3_PROJECT' różni się od oczekiwanego '$expected'. Ustaw M3_EXPECT_PROJECT świadomie."
  docker inspect "$M3_WEBSERVER" >/dev/null 2>&1 || m3_die "$M3_EXIT_PRECONDITION" \
    "kontener '$M3_WEBSERVER' nie istnieje"
  local actual
  actual="$(docker inspect "$M3_WEBSERVER" \
    --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  [ "$actual" = "$M3_PROJECT" ] || m3_die "$M3_EXIT_REFUSED" \
    "odmowa: kontener '$M3_WEBSERVER' należy do projektu '$actual', a nie '$M3_PROJECT'"
}

# Odmowa operacji destrukcyjnej na dokumencie chronionym.
m3_guard_protected() { # m3_guard_protected <id>
  local id="$1"
  [ -n "${M3_PROTECTED_DOCS// /}" ] || m3_die "$M3_EXIT_REFUSED" \
    "odmowa: lista dokumentów chronionych jest pusta"
  for p in $M3_PROTECTED_DOCS; do
    [ "$p" = "$id" ] && m3_die "$M3_EXIT_REFUSED" \
      "odmowa: dokument $id jest chroniony (M3_PROTECTED_DOCS)"
  done
  return 0
}

# Token nigdy nie trafia do argumentów ani logów: zawsze do pliku 0600 czytanego
# przez `curl -K`. Źródła w kolejności: zmienna środowiskowa, wskazany plik,
# opcjonalne jednorazowe pobranie z uruchomionej instancji laboratoryjnej.
m3_token_init() {
  M3_CURL_CFG="$(mktemp "${TMPDIR:-/tmp}/.m3-curlrc.XXXXXX")"
  chmod 600 "$M3_CURL_CFG"
  if [ -n "${PAPERLESS_API_TOKEN:-}" ]; then
    printf 'header = "Authorization: Token %s"\n' "$PAPERLESS_API_TOKEN" > "$M3_CURL_CFG"
  elif [ -n "${PAPERLESS_TOKEN_FILE:-}" ]; then
    [ -r "$PAPERLESS_TOKEN_FILE" ] || m3_die "$M3_EXIT_PRECONDITION" \
      "PAPERLESS_TOKEN_FILE nie jest czytelny"
    local perms; perms="$(stat -c %a "$PAPERLESS_TOKEN_FILE" 2>/dev/null || stat -f %Lp "$PAPERLESS_TOKEN_FILE")"
    [ "$perms" = "600" ] || m3_die "$M3_EXIT_PRECONDITION" \
      "PAPERLESS_TOKEN_FILE musi mieć uprawnienia 0600 (ma $perms)"
    printf 'header = "Authorization: Token %s"\n' "$(tr -d '\r\n' < "$PAPERLESS_TOKEN_FILE")" > "$M3_CURL_CFG"
  elif [ "${M3_ALLOW_CONTAINER_TOKEN:-0}" = "1" ]; then
    docker exec "$M3_WEBSERVER" python3 /usr/src/paperless/src/manage.py shell -c \
      "from rest_framework.authtoken.models import Token; print('header = \"Authorization: Token '+Token.objects.first().key+'\"')" \
      2>/dev/null | tail -1 > "$M3_CURL_CFG"
    grep -q '^header = "Authorization: Token ' "$M3_CURL_CFG" || m3_die "$M3_EXIT_PRECONDITION" \
      "nie udało się pobrać tokenu z kontenera"
  else
    m3_die "$M3_EXIT_PRECONDITION" \
      "brak tokenu: ustaw PAPERLESS_API_TOKEN, PAPERLESS_TOKEN_FILE albo M3_ALLOW_CONTAINER_TOKEN=1"
  fi
}

m3_token_cleanup() {
  [ -n "$M3_CURL_CFG" ] || return 0
  shred -u "$M3_CURL_CFG" 2>/dev/null || rm -f "$M3_CURL_CFG"
  M3_CURL_CFG=""
}

m3_accept() { printf 'Accept: application/json; version=%s' "${1:-$M3_API_VERSION}"; }

# Wywołanie API. Token pochodzi wyłącznie z pliku konfiguracyjnego curl.
m3_curl_accept() { # m3_curl_accept <wartość Accept> <argumenty curl...>
  local accept="$1"; shift
  [ -n "$M3_CURL_CFG" ] || m3_die "$M3_EXIT_ERROR" "m3_token_init nie zostało wywołane"
  curl -sS -K "$M3_CURL_CFG" -H "Accept: $accept" --max-time "$M3_HTTP_TIMEOUT" "$@"
}

m3_curl() { # m3_curl <argumenty curl...>
  m3_curl_accept "application/json; version=$M3_API_VERSION" "$@"
}

m3_curl_version() { # m3_curl_version <wersja_api> <argumenty curl...>
  local v="$1"; shift
  m3_curl_accept "application/json; version=$v" "$@"
}

m3_doc_count() {
  m3_curl "$M3_API/documents/?page_size=1" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])'
}

m3_docs_by_checksum() { # m3_docs_by_checksum <sha256> — wypisuje ID oddzielone spacją
  m3_curl --get --data-urlencode "checksum__iexact=$1" --data-urlencode "page_size=1000" \
    "$M3_API/documents/" \
    | python3 -c 'import json,sys; print(" ".join(str(v) for v in sorted(r["id"] for r in json.load(sys.stdin).get("results",[]))))'
}

# Stany nieterminalne zadania Celery w obu reprezentacjach API.
m3_task_nonterminal() { # m3_task_nonterminal <status>
  case "$1" in
    pending|started|received|retry|queued|absent) return 0 ;;
    PENDING|STARTED|RECEIVED|RETRY|QUEUED) return 0 ;;
    *) return 1 ;;
  esac
}

# Odpytywanie do stanu końcowego bez zakładania, że będzie to `success`.
m3_poll_task() { # m3_poll_task <uuid> <plik_wyjściowy> [maks_prób] — wypisuje status końcowy
  local uuid="$1" out="$2" max="${3:-90}" status=absent i
  for ((i = 1; i <= max; i++)); do
    m3_curl "$M3_API/tasks/?task_id=$uuid" -o "$out"
    status="$(python3 - "$out" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
r = d["results"] if isinstance(d, dict) and "results" in d else d
print(r[0]["status"] if r else "absent")
PY
)"
    m3_task_nonterminal "$status" || break
    sleep 1
  done
  printf '%s\n' "$status"
}

m3_health() { docker inspect "$M3_WEBSERVER" --format '{{.State.Health.Status}}' 2>/dev/null || echo unknown; }

m3_wait_healthy() { # m3_wait_healthy [timeout_s]
  local max="${1:-180}" t=0
  while [ "$t" -lt "$max" ]; do
    [ "$(m3_health)" = "healthy" ] && return 0
    sleep 2; t=$((t + 2))
  done
  return 1
}

m3_status_summary() { # m3_status_summary <plik_json>
  python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); t = d["tasks"]
print(f"  pngx_version={d['pngx_version']} db={d['database']['status']} "
      f"redis={t['redis_status']} celery={t['celery_status']} index={t['index_status']}")
PY
}

# Zestaw plików Compose wariantu <target>/<valkey>. Bez `down`, `reset`
# i bez jakichkolwiek operacji na wolumenach.
m3_compose() {
  local env_file="${M3_ENV_FILE:-${M3_LAB_DIR}/.env.${M3_TARGET}}"
  [ -f "$env_file" ] || m3_die "$M3_EXIT_PRECONDITION" "brak pliku środowiska: $env_file"
  docker compose --env-file "$env_file" \
    -f "${M3_LAB_DIR}/compose.baseline.yaml" \
    -f "${M3_LAB_DIR}/compose.override.yaml" \
    -f "${M3_LAB_DIR}/compose.${M3_TARGET}.yaml" \
    -f "${M3_LAB_DIR}/compose.valkey-${M3_VALKEY}.yaml" "$@"
}
