#!/usr/bin/env bash
# E3B — disaster recovery baz, mediów, assetów i konfiguracji.
#
# Najpierw powstaje JEDEN niezmienny zestaw DR (logiczne dumpy PostgreSQL,
# media Paperless, assety Core, konfiguracja bez sekretów, manifest). Ten sam
# zestaw zabezpieczają obaj kandydaci i z niego odtwarzany jest czysty projekt
# restore.
#
# Zamrożenie zapisów zatrzymuje WYŁĄCZNIE usługę webserver źródła. Trap
# przywraca ją także po błędzie; nieudane przywrócenie kończy się niezerowym
# kodem i komunikatem o wymaganej interwencji.
#
# Nigdy nie kopiujemy aktywnych plików danych PostgreSQL — tylko logiczne dumpy.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common-e3.sh
source "${HERE}/common-e3.sh"

RESTORE_PROJECT="homeos-m3-restore"
RESTORE_API="${E3_RESTORE_API:-http://127.0.0.1:8100/api}"
RESTORE_WEBSERVER="${RESTORE_PROJECT}-webserver-1"
MANIFEST_DIR="${E3_MANIFEST_DIR:-${E3_ROOT}/manifest}"
INTERRUPT_PAYLOAD="${E3_ROOT}/interrupt-payload-e3b"
INTERRUPT_MB="${E3_INTERRUPT_MB:-400}"
# Obraz pomocniczy do pakowania wolumenów: już przypięty w laboratorium.
HELPER_IMAGE="${E3_HELPER_IMAGE:-valkey/valkey:9-alpine@sha256:ee91f7a174ac4d6a6b0685b3a60e321f0a9dbbb691f9b0e285be2ba1d1be8328}"

SOURCE_MEDIA_VOLUME="homeos-m3-source-paperless-media"
SOURCE_ASSETS_VOLUME="homeos-m3-source-core-assets"
RESTORE_MEDIA_VOLUME="homeos-m3-restore-paperless-media"
RESTORE_ASSETS_VOLUME="homeos-m3-restore-core-assets"

usage() {
  cat <<'EOF'
Użycie: ./e3b.sh [--candidates "restic borg"] [--reuse-dataset] [--keep-target]

Buduje zestaw DR i wykonuje pełny tor E3B dla wskazanych kandydatów.
Kody wyjścia: 0 PASS, 1 błąd lub nieudany rollback, 2 użycie, 3 warunek
wstępny, 4 FAIL, 5 odmowa.
EOF
}

CANDIDATES="restic borg"
REUSE_DATASET=0
KEEP_TARGET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --candidates) CANDIDATES="${2:?brak wartości}"; shift 2 ;;
    --reuse-dataset) REUSE_DATASET=1; shift ;;
    --keep-target) KEEP_TARGET=1; shift ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

m3_require_cmds docker python3 sha256sum curl timeout realpath
m3_require_project
e3_require_tools
e3_require_recovery_material
install -d -m 700 "$E3_RESULTS"

FAILURES=0
RESULT_LINES=()
check() {
  if [ "$2" = "yes" ]; then m3_log "  OK   $1"; RESULT_LINES+=("OK|$1")
  else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); RESULT_LINES+=("FAIL|$1"); fi
}

SOURCE_STOPPED=0
DOCS_BEFORE=""
TARGET_CFG=""

target_token_cleanup() {
  [ -n "$TARGET_CFG" ] || return 0
  shred -u "$TARGET_CFG" 2>/dev/null || rm -f "$TARGET_CFG"
  TARGET_CFG=""
}

cleanup() {
  local rc=$?
  trap - EXIT
  trap '' INT TERM HUP
  set +e
  local rollback_failed=0

  if [ "$SOURCE_STOPPED" -eq 1 ]; then
    m3_section "rollback: przywrócenie usług źródła (rc=$rc)"
    m3_compose up -d webserver 2>&1 | sed 's/^/    /'
    if m3_wait_healthy 420; then
      m3_log "  webserver_healthy=yes"
      SOURCE_STOPPED=0
    else
      m3_log "  webserver_healthy=NIE — WYMAGANA INTERWENCJA RĘCZNA"
      m3_log "  sprawdź: docker logs $M3_WEBSERVER"
      rollback_failed=1
    fi
  fi

  if [ -n "$DOCS_BEFORE" ] && [ "$rollback_failed" -eq 0 ]; then
    local after; after="$(m3_doc_count 2>/dev/null || echo '?')"
    m3_log "  dokumentów przed=$DOCS_BEFORE po=$after"
    if [ "$after" != "?" ] && [ "$after" -lt "$DOCS_BEFORE" ]; then
      m3_log "  UBYŁO DOKUMENTÓW — WYMAGANA INTERWENCJA RĘCZNA"
      rollback_failed=1
    fi
  fi

  target_token_cleanup
  m3_token_cleanup
  if [ "$rollback_failed" -ne 0 ] && [ "$rc" -eq 0 ]; then rc="$M3_EXIT_ERROR"; fi
  exit "$rc"
}
trap cleanup EXIT

m3_token_init

target_curl() {
  curl -sS -K "$TARGET_CFG" -H "Accept: application/json; version=$M3_API_VERSION" \
    --max-time "$M3_HTTP_TIMEOUT" "$@"
}
target_count() {
  target_curl "$RESTORE_API/$1/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])'
}
target_new_token() {
  target_token_cleanup
  TARGET_CFG="$(mktemp "${TMPDIR:-/tmp}/.m3-target-curlrc.XXXXXX")"
  chmod 600 "$TARGET_CFG"
  docker exec "$RESTORE_WEBSERVER" python3 /usr/src/paperless/src/manage.py shell -c "
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token
User = get_user_model()
Token.objects.all().delete()
user = User.objects.filter(is_superuser=True).first() or User.objects.first()
token = Token.objects.create(user=user)
print('header = \"Authorization: Token ' + token.key + '\"')
" 2>/dev/null | tail -1 > "$TARGET_CFG"
  grep -q '^header = "Authorization: Token ' "$TARGET_CFG"
}

restore_compose() {
  docker compose --env-file "${M3_LAB_DIR}/.env.restore" \
    -f "${M3_LAB_DIR}/compose.baseline.yaml" \
    -f "${M3_LAB_DIR}/compose.override.yaml" \
    -f "${M3_LAB_DIR}/compose.restore.yaml" \
    -f "${M3_LAB_DIR}/compose.valkey-shared.yaml" "$@"
}

reset_restore_target() {
  [ "$RESTORE_PROJECT" = "homeos-m3-restore" ] || m3_die "$M3_EXIT_REFUSED" "nieoczekiwany projekt restore"
  restore_compose down --volumes --remove-orphans >/dev/null 2>&1 || true
  for volume in $(docker volume ls -q --filter "name=${RESTORE_PROJECT}-"); do
    case "$volume" in
      homeos-m3-restore-*) docker volume rm "$volume" >/dev/null 2>&1 || true ;;
      *) m3_die "$M3_EXIT_REFUSED" "odmowa usunięcia wolumenu spoza celu: $volume" ;;
    esac
  done
  case "${E3_WORKSPACE}/lab-data/m3-restore" in
    */lab-data/m3-restore) rm -rf "${E3_WORKSPACE}/lab-data/m3-restore" ;;
    *) m3_die "$M3_EXIT_REFUSED" "odmowa czyszczenia nieoczekiwanej ścieżki" ;;
  esac
  install -d -m 700 "${E3_WORKSPACE}/lab-data/m3-restore" \
    "${E3_WORKSPACE}/lab-data/m3-restore/export" "${E3_WORKSPACE}/lab-data/m3-restore/consume"
}

wait_target_healthy() {
  local max="${1:-420}" t=0
  while [ "$t" -lt "$max" ]; do
    [ "$(docker inspect "$RESTORE_WEBSERVER" --format '{{.State.Health.Status}}' 2>/dev/null)" = "healthy" ] && return 0
    sleep 3; t=$((t + 3))
  done
  return 1
}

# Checksum zestawu DR liczony po stabilnym zbiorze plików. Pomijamy dwa pliki
# opisujące sam zestaw: `CHECKSUMS.sha256` oraz plik z tą właśnie sumą — inaczej
# wartość zależałaby od momentu jej zapisania i nie dałaby się porównać po restore.
e3b_dataset_sha() { # e3b_dataset_sha <katalog>
  ( cd "$1" && find . -type f \
      ! -name CHECKSUMS.sha256 \
      ! -path './meta/dataset-tree-sha256.txt' -print0 \
    | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1 )
}

wait_pg_ready() { # wait_pg_ready <kontener> <użytkownik>
  local c="$1" u="$2" t=0
  while [ "$t" -lt 120 ]; do
    docker exec "$c" pg_isready -U "$u" >/dev/null 2>&1 && return 0
    sleep 2; t=$((t + 2))
  done
  return 1
}

###########################################################################
# CZĘŚĆ 1 — jeden niezmienny zestaw DR
###########################################################################
build_dataset() {
  m3_section "1. Zamrożenie zapisów i zestaw DR"

  DOCS_BEFORE="$(m3_doc_count)"
  local trash_before tags_before
  trash_before="$(m3_curl "$M3_API/trash/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
  m3_log "  dokumentów przed=$DOCS_BEFORE kosz=$trash_before"

  # 1.1 oczekiwanie na zakończenie zadań
  local waited=0
  while [ "$waited" -lt 300 ]; do
    local active reserved
    active="$(docker exec "$M3_WEBSERVER" celery -A paperless inspect active 2>/dev/null | grep -c '^\s*\*' || true)"
    reserved="$(docker exec "$M3_WEBSERVER" celery -A paperless inspect reserved 2>/dev/null | grep -c '^\s*\*' || true)"
    [ "$active" -eq 0 ] && [ "$reserved" -eq 0 ] && break
    sleep 5; waited=$((waited + 5))
  done
  m3_log "  czekanie_na_zadania=${waited}s"
  check "brak aktywnych zadań przed zamrożeniem" \
    "$([ "$waited" -lt 300 ] && echo yes || echo no)"

  # 1.2 zatrzymanie usługi zapisującej — webserver zawiera API, consumer i worker
  local freeze_start freeze_end
  freeze_start="$(date +%s)"
  # Flaga jest ustawiana przed poleceniem: nawet częściowo nieudany `stop`
  # uruchomi w trapie próbę przywrócenia źródła.
  SOURCE_STOPPED=1
  m3_compose stop webserver 2>&1 | sed 's/^/    /'
  m3_log "  webserver zatrzymany (punkt spójności)"

  e3_recreate_dir "$E3_DR_DIR"
  install -d -m 700 "$E3_DR_DIR/postgres" "$E3_DR_DIR/media" \
    "$E3_DR_DIR/assets" "$E3_DR_DIR/config" "$E3_DR_DIR/meta"

  # 1.3 logiczne dumpy — nigdy kopia aktywnych plików danych
  docker exec "${M3_PROJECT}-db-1" pg_dump -U paperless -d paperless -Fc \
    > "$E3_DR_DIR/postgres/paperless.dump"
  docker exec "${M3_PROJECT}-core_fixture_db-1" pg_dump -U core_fixture -d core_fixture -Fc \
    > "$E3_DR_DIR/postgres/core_fixture.dump"
  m3_log "  dump paperless=$(stat -c %s "$E3_DR_DIR/postgres/paperless.dump") B"
  m3_log "  dump core_fixture=$(stat -c %s "$E3_DR_DIR/postgres/core_fixture.dump") B"
  check "logiczny dump Paperless nie jest pusty" \
    "$([ "$(stat -c %s "$E3_DR_DIR/postgres/paperless.dump")" -gt 1000 ] && echo yes || echo no)"
  check "logiczny dump core_fixture nie jest pusty" \
    "$([ "$(stat -c %s "$E3_DR_DIR/postgres/core_fixture.dump")" -gt 500 ] && echo yes || echo no)"

  # 1.4 media Paperless i assety Core
  docker run --rm -v "${SOURCE_MEDIA_VOLUME}:/src:ro" "$HELPER_IMAGE" \
    tar -C /src -cf - . > "$E3_DR_DIR/media/paperless-media.tar"
  docker run --rm -v "${SOURCE_ASSETS_VOLUME}:/src:ro" "$HELPER_IMAGE" \
    tar -C /src -cf - . > "$E3_DR_DIR/assets/core-assets.tar"
  m3_log "  media=$(stat -c %s "$E3_DR_DIR/media/paperless-media.tar") B"
  m3_log "  assety=$(stat -c %s "$E3_DR_DIR/assets/core-assets.tar") B"
  check "archiwum mediów zawiera pliki" \
    "$([ "$(stat -c %s "$E3_DR_DIR/media/paperless-media.tar")" -gt 10000 ] && echo yes || echo no)"
  check "archiwum assetów zawiera pliki" \
    "$([ "$(stat -c %s "$E3_DR_DIR/assets/core-assets.tar")" -gt 1000 ] && echo yes || echo no)"

  # 1.5 konfiguracja bez sekretów
  local raw_cfg; raw_cfg="$(mktemp)"; chmod 600 "$raw_cfg"
  "${M3_LAB_DIR}/m3-lab.sh" source shared config > "$raw_cfg" 2>/dev/null
  python3 -c '
import re, sys
SECRET = re.compile(r"(?i)(password|passwd|secret|token|api_key|_key)$")
for line in sys.stdin:
    line = line.rstrip("\n")
    m = re.match(r"^(\s*)([A-Za-z0-9_.-]+)(:\s+|=)(.+?)\s*$", line)
    if m and SECRET.search(m.group(2)):
        v = m.group(4).strip().strip("\"'"'"'")
        if v and not v.startswith("${"):
            print(f"{m.group(1)}{m.group(2)}{m.group(3)}<zredagowano:{len(v)} znaków>")
            continue
    print(line)
' < "$raw_cfg" > "$E3_DR_DIR/config/compose-source-shared.yaml"
  shred -u "$raw_cfg" 2>/dev/null || rm -f "$raw_cfg"
  cp "${M3_LAB_DIR}/compose.baseline.yaml" "${M3_LAB_DIR}/compose.override.yaml" \
     "${M3_LAB_DIR}/compose.source.yaml" "${M3_LAB_DIR}/compose.restore.yaml" \
     "${M3_LAB_DIR}/compose.valkey-shared.yaml" "${M3_LAB_DIR}/compose.valkey-split.yaml" \
     "$E3_DR_DIR/config/"
  local secret_hits
  # Brak dopasowań to wynik pożądany, a `grep` sygnalizuje go kodem 1 — przy
  # `pipefail` przerwałoby to skrypt, dlatego kod jest tu świadomie pochłaniany.
  secret_hits="$( { grep -rEc '(password|secret)[[:space:]]*[:=][[:space:]]*[^<$[:space:]]{8,}' \
    "$E3_DR_DIR/config/" 2>/dev/null || true; } | awk -F: '{s+=$2} END {print s+0}')"
  m3_log "  potencjalnych sekretów w konfiguracji=$secret_hits"
  check "konfiguracja w zestawie DR nie zawiera wartości sekretów" \
    "$([ "$secret_hits" -eq 0 ] && echo yes || echo no)"

  # 1.6 wersje narzędzi i manifest
  {
    echo "paperless=3.0.4"
    echo "paperless_digest=$(docker image inspect "$(docker inspect "$M3_WEBSERVER" --format '{{.Image}}')" --format '{{range .RepoDigests}}{{.}}{{end}}')"
    echo "postgres=$(docker exec "${M3_PROJECT}-db-1" postgres --version)"
    echo "pg_dump=$(docker exec "${M3_PROJECT}-db-1" pg_dump --version)"
    echo "valkey=$(docker exec "${M3_PROJECT}-broker-1" valkey-server --version | cut -d' ' -f1-3)"
    echo "docker=$(docker version --format '{{.Server.Version}}')"
    echo "compose=$(docker compose version --short)"
    echo "restic=$("$E3_RESTIC" version | head -1)"
    echo "borg=$("$E3_BORG" --version)"
    echo "utworzono_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$E3_DR_DIR/meta/tool-versions.txt"
  cp "${MANIFEST_DIR}/source-manifest.json" "$E3_DR_DIR/meta/source-manifest.json"
  cp "${MANIFEST_DIR}/source-manifest.sha256" "$E3_DR_DIR/meta/source-manifest.sha256"

  # 1.7 checksum kompletnego zestawu
  ( cd "$E3_DR_DIR" && find . -type f ! -name CHECKSUMS.sha256 -print0 | sort -z \
      | xargs -0 sha256sum ) > "$E3_DR_DIR/CHECKSUMS.sha256"
  DR_TREE_SHA="$(e3b_dataset_sha "$E3_DR_DIR")"
  DR_BYTES="$(e3_bytes "$E3_DR_DIR")"
  m3_log "  plików w zestawie DR=$(find "$E3_DR_DIR" -type f | wc -l)"
  m3_log "  rozmiar zestawu DR=${DR_BYTES} B"
  m3_log "  checksum_zestawu_DR=$DR_TREE_SHA"
  printf '%s\n' "$DR_TREE_SHA" > "$E3_DR_DIR/meta/dataset-tree-sha256.txt"

  # 1.8 przywrócenie usług źródła
  m3_compose up -d webserver 2>&1 | sed 's/^/    /'
  if m3_wait_healthy 420; then SOURCE_STOPPED=0; fi
  freeze_end="$(date +%s)"
  FREEZE_SECONDS=$((freeze_end - freeze_start))
  m3_log "  czas_zamrożenia_zapisów=${FREEZE_SECONDS}s"
  check "webserver źródła wrócił do stanu healthy" \
    "$([ "$SOURCE_STOPPED" -eq 0 ] && echo yes || echo no)"

  docker exec "$M3_WEBSERVER" document_sanity_checker \
    > "${E3_RESULTS}/e3b-source-sanity.log" 2>&1 || true
  check "sanity checker źródła po odmrożeniu bez uwag" \
    "$(grep -q 'No issues detected' "${E3_RESULTS}/e3b-source-sanity.log" && echo yes || echo no)"
  local docs_after; docs_after="$(m3_doc_count)"
  m3_log "  dokumentów po odmrożeniu=$docs_after"
  check "liczba dokumentów źródła niezmieniona ($docs_after/$DOCS_BEFORE)" \
    "$([ "$docs_after" = "$DOCS_BEFORE" ] && echo yes || echo no)"

  {
    echo "czas_zamrozenia_s=${FREEZE_SECONDS}"
    echo "checksum_zestawu=${DR_TREE_SHA}"
    echo "rozmiar_B=${DR_BYTES}"
    echo "plikow=$(find "$E3_DR_DIR" -type f | wc -l)"
    echo "dokumenty_zrodlo=${DOCS_BEFORE}"
  } > "${E3_RESULTS}/e3b-dataset.txt"
}

###########################################################################
# CZĘŚĆ 2 — odtworzenie zestawu DR przez kandydata
###########################################################################
run_candidate() {
  local cand="$1"
  local staging="${E3_RESTORE_STAGING}/e3b-${cand}"
  local t0 t1 backup_s restore_s repo_bytes snaps_before snaps_after
  local needed_break_lock=no needed_unlock=no

  m3_section "=== E3B kandydat: ${cand} ==="

  # --- backup zestawu DR ---------------------------------------------------
  t0="$(date +%s)"
  if [ "$cand" = "restic" ]; then
    [ -n "$(e3_restic list locks 2>/dev/null | head -1)" ] && { e3_restic unlock >/dev/null 2>&1; needed_unlock=yes; }
    e3_restic backup "$E3_DR_DIR" --tag e3b --tag dr-set \
      > "${E3_RESULTS}/e3b-${cand}-backup.log" 2>&1
    snaps_before="$(e3_restic snapshots --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  else
    e3_borg create --stats --compression zstd "::e3b-dr-{now:%Y%m%dT%H%M%S}" "$E3_DR_DIR" \
      > "${E3_RESULTS}/e3b-${cand}-backup.log" 2>&1
    snaps_before="$(e3_borg list --format '{archive}{NL}' | grep -c . || true)"
  fi
  t1="$(date +%s)"; backup_s=$((t1 - t0))
  m3_log "  czas_backupu=${backup_s}s snapshotów=${snaps_before}"
  check "${cand}: zestaw DR zabezpieczony" "$([ "$snaps_before" -ge 1 ] && echo yes || echo no)"

  # --- pełna kontrola integralności ---------------------------------------
  if [ "$cand" = "restic" ]; then
    e3_restic check --read-data > "${E3_RESULTS}/e3b-${cand}-check.log" 2>&1 \
      && check "restic: check --read-data bez błędów" yes \
      || check "restic: check --read-data bez błędów" no
  else
    e3_borg check --verify-data > "${E3_RESULTS}/e3b-${cand}-check.log" 2>&1 \
      && check "borg: check --verify-data bez błędów" yes \
      || check "borg: check --verify-data bez błędów" no
  fi

  # --- przerwanie i bezpieczne ponowienie ---------------------------------
  e3_recreate_dir "$INTERRUPT_PAYLOAD"
  for i in $(seq 1 4); do
    dd if=/dev/urandom of="${INTERRUPT_PAYLOAD}/blob-${i}.bin" \
      bs=1M count=$((INTERRUPT_MB / 4)) status=none
  done
  set +e
  if [ "$cand" = "restic" ]; then
    timeout -s KILL 2 env RESTIC_PASSWORD_FILE="$E3_RESTIC_PASSWORD_A" \
      RESTIC_REPOSITORY="$E3_RESTIC_REPO" "$E3_RESTIC" backup "$INTERRUPT_PAYLOAD" --tag e3b-interrupted \
      > "${E3_RESULTS}/e3b-${cand}-interrupted.log" 2>&1
  else
    timeout -s KILL 2 env BORG_PASSCOMMAND="cat ${E3_BORG_PASSPHRASE_A}" \
      BORG_REPO="$E3_BORG_REPO" "$E3_BORG" create "::e3b-interrupted-{now:%Y%m%dT%H%M%S}" "$INTERRUPT_PAYLOAD" \
      > "${E3_RESULTS}/e3b-${cand}-interrupted.log" 2>&1
  fi
  local interrupt_rc=$?
  set -e
  check "${cand}: przerwany backup zakończył się niezerowym kodem (${interrupt_rc})" \
    "$([ "$interrupt_rc" -ne 0 ] && echo yes || echo no)"

  if [ "$cand" = "borg" ]; then
    e3_borg list >/dev/null 2>&1 || { needed_break_lock=yes; e3_borg break-lock >/dev/null 2>&1 || true; }
  else
    [ -n "$(e3_restic list locks 2>/dev/null | head -1)" ] && { needed_unlock=yes; e3_restic unlock >/dev/null 2>&1 || true; }
  fi

  if [ "$cand" = "restic" ]; then
    snaps_after="$(e3_restic snapshots --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  else
    snaps_after="$(e3_borg list --format '{archive}{NL}' | grep -c . || true)"
  fi
  check "${cand}: wcześniejszy restore point zestawu DR pozostał dostępny" \
    "$([ "$snaps_after" -ge "$snaps_before" ] && echo yes || echo no)"

  set +e
  if [ "$cand" = "restic" ]; then
    e3_restic backup "$INTERRUPT_PAYLOAD" --tag e3b-retry > "${E3_RESULTS}/e3b-${cand}-retry.log" 2>&1
  else
    e3_borg create --compression zstd "::e3b-retry-{now:%Y%m%dT%H%M%S}" "$INTERRUPT_PAYLOAD" \
      > "${E3_RESULTS}/e3b-${cand}-retry.log" 2>&1
  fi
  local retry_rc=$?
  set -e
  check "${cand}: ponowienie po przerwaniu powiodło się" \
    "$([ "$retry_rc" -eq 0 ] && echo yes || echo no)"

  # --- odtworzenie zestawu -------------------------------------------------
  e3_recreate_dir "$staging"
  t0="$(date +%s)"
  if [ "$cand" = "restic" ]; then
    local snap
    snap="$(e3_restic snapshots --json --tag dr-set | python3 -c 'import json,sys; print(json.load(sys.stdin)[-1]["id"])')"
    e3_restic restore "$snap" --target "$staging" > "${E3_RESULTS}/e3b-${cand}-restore.log" 2>&1
  else
    local archive
    archive="$(e3_borg list --format '{archive}{NL}' | grep '^e3b-dr-' | tail -1)"
    ( cd "$staging" && BORG_PASSCOMMAND="cat ${E3_BORG_PASSPHRASE_A}" BORG_REPO="$E3_BORG_REPO" \
        "$E3_BORG" extract "::${archive}" ) > "${E3_RESULTS}/e3b-${cand}-restore.log" 2>&1
  fi
  t1="$(date +%s)"; restore_s=$((t1 - t0))
  local dr_root
  dr_root="$(dirname "$(find "$staging" -name CHECKSUMS.sha256 -type f | head -1)")"
  [ -n "$dr_root" ] || m3_die "$M3_EXIT_FAIL" "${cand}: nie znaleziono zestawu DR w stagingu"
  local restored_sha; restored_sha="$(e3b_dataset_sha "$dr_root")"
  m3_log "  czas_restore=${restore_s}s"
  m3_log "  checksum_odtworzonego_zestawu=$restored_sha"
  check "${cand}: odtworzony zestaw DR jest identyczny z zamrożonym" \
    "$([ "$restored_sha" = "$DR_TREE_SHA" ] && echo yes || echo no)"

  if [ "$cand" = "restic" ]; then repo_bytes="$(e3_bytes "$E3_RESTIC_REPO")"; else repo_bytes="$(e3_bytes "$E3_BORG_REPO")"; fi

  # --- czysty cel: najpierw bazy, potem aplikacja -------------------------
  m3_log "  czyszczenie projektu ${RESTORE_PROJECT}"
  reset_restore_target
  restore_compose up -d db core_fixture_db broker > "${E3_RESULTS}/e3b-${cand}-up-db.log" 2>&1
  wait_pg_ready "${RESTORE_PROJECT}-db-1" paperless \
    || m3_die "$M3_EXIT_FAIL" "${cand}: PostgreSQL celu nie wystartował"
  wait_pg_ready "${RESTORE_PROJECT}-core_fixture_db-1" core_fixture \
    || m3_die "$M3_EXIT_FAIL" "${cand}: core_fixture celu nie wystartował"

  # Logiczne odtworzenie obu baz na świeżo utworzone bazy danych.
  docker exec "${RESTORE_PROJECT}-db-1" psql -U paperless -d postgres -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS paperless;" -c "CREATE DATABASE paperless OWNER paperless;" \
    > "${E3_RESULTS}/e3b-${cand}-db-prepare.log" 2>&1
  docker exec -i "${RESTORE_PROJECT}-db-1" pg_restore -U paperless -d paperless --no-owner \
    < "${dr_root}/postgres/paperless.dump" > "${E3_RESULTS}/e3b-${cand}-pgrestore.log" 2>&1
  local pg_rc=$?
  docker exec "${RESTORE_PROJECT}-core_fixture_db-1" psql -U core_fixture -d postgres -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS core_fixture;" -c "CREATE DATABASE core_fixture OWNER core_fixture;" \
    >> "${E3_RESULTS}/e3b-${cand}-db-prepare.log" 2>&1
  docker exec -i "${RESTORE_PROJECT}-core_fixture_db-1" pg_restore -U core_fixture -d core_fixture --no-owner \
    < "${dr_root}/postgres/core_fixture.dump" >> "${E3_RESULTS}/e3b-${cand}-pgrestore.log" 2>&1
  m3_log "  pg_restore kod=${pg_rc}"
  local paperless_docs_db core_links core_assets_rows
  paperless_docs_db="$(docker exec "${RESTORE_PROJECT}-db-1" psql -U paperless -d paperless -tAc \
    'SELECT count(*) FROM documents_document;' 2>/dev/null || echo 0)"
  core_links="$(docker exec "${RESTORE_PROJECT}-core_fixture_db-1" psql -U core_fixture -d core_fixture -tAc \
    'SELECT count(*) FROM document_link;' 2>/dev/null || echo 0)"
  core_assets_rows="$(docker exec "${RESTORE_PROJECT}-core_fixture_db-1" psql -U core_fixture -d core_fixture -tAc \
    'SELECT count(*) FROM asset;' 2>/dev/null || echo 0)"
  m3_log "  w bazie celu: dokumenty=${paperless_docs_db} document_link=${core_links} asset=${core_assets_rows}"
  check "${cand}: baza Paperless odtworzona logicznie" \
    "$([ "$paperless_docs_db" -gt 0 ] && echo yes || echo no)"
  check "${cand}: baza core_fixture odtworzona logicznie" \
    "$([ "$core_links" -gt 0 ] && echo yes || echo no)"

  # --- media i assety ------------------------------------------------------
  docker volume create "$RESTORE_MEDIA_VOLUME" >/dev/null
  docker volume create "$RESTORE_ASSETS_VOLUME" >/dev/null
  docker run --rm -i -v "${RESTORE_MEDIA_VOLUME}:/dst" "$HELPER_IMAGE" \
    tar -C /dst -xf - < "${dr_root}/media/paperless-media.tar"
  docker run --rm -i -v "${RESTORE_ASSETS_VOLUME}:/dst" "$HELPER_IMAGE" \
    tar -C /dst -xf - < "${dr_root}/assets/core-assets.tar"
  local media_files
  media_files="$(docker run --rm -v "${RESTORE_MEDIA_VOLUME}:/dst:ro" "$HELPER_IMAGE" \
    sh -c 'find /dst -type f | wc -l')"
  m3_log "  plików w mediach celu=${media_files}"
  check "${cand}: media odtworzone" "$([ "$media_files" -gt 0 ] && echo yes || echo no)"

  # --- start aplikacji -----------------------------------------------------
  restore_compose up -d > "${E3_RESULTS}/e3b-${cand}-up.log" 2>&1
  if wait_target_healthy 420; then
    check "${cand}: Paperless 3.0.4 wystartował na odtworzonych danych" yes
  else
    check "${cand}: Paperless 3.0.4 wystartował na odtworzonych danych" no
    docker logs "$RESTORE_WEBSERVER" --tail 25 2>&1 | sed 's/^/    /'
    return 0
  fi
  local target_digest
  target_digest="$(docker image inspect "$(docker inspect "$RESTORE_WEBSERVER" --format '{{.Image}}')" \
    --format '{{range .RepoDigests}}{{.}}{{end}}')"
  check "${cand}: cel używa tego samego digestu 3.0.4" \
    "$(printf '%s' "$target_digest" | grep -q '3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582' && echo yes || echo no)"

  local shared_mounts
  shared_mounts="$(docker inspect "$RESTORE_WEBSERVER" "${RESTORE_PROJECT}-db-1" \
    "${RESTORE_PROJECT}-core_fixture_db-1" --format '{{range .Mounts}}{{.Name}}{{.Source}} {{end}}' \
    | tr ' ' '\n' | grep -c 'homeos-m3-source' || true)"
  check "${cand}: cel nie używa wolumenów ani katalogów źródła" \
    "$([ "$shared_mounts" -eq 0 ] && echo yes || echo no)"

  target_new_token || { check "${cand}: token celu" no; return 0; }

  # --- indeks: przebudowa tylko jeżeli wymagana ---------------------------
  local phrase="SYGNATURA DUPLIKATU ALFA BRAVO 2026"
  target_curl --get --data-urlencode "query=\"$phrase\"" "$RESTORE_API/documents/" \
    -o "${E3_RESULTS}/e3b-${cand}-search-before.json" || true
  local hits_before reindex_needed=no
  hits_before="$(python3 -c '
import json,sys
try: print(json.load(open(sys.argv[1]))["count"])
except Exception: print(0)' "${E3_RESULTS}/e3b-${cand}-search-before.json")"
  m3_log "  trafienia OCR przed ewentualną przebudową indeksu=${hits_before}"
  if [ "$hits_before" -eq 0 ]; then
    reindex_needed=yes
    m3_log "  indeks wymaga przebudowy — zestaw DR nie zawiera katalogu data"
    docker exec "$RESTORE_WEBSERVER" document_index reindex \
      > "${E3_RESULTS}/e3b-${cand}-reindex.log" 2>&1 || true
  fi
  m3_log "  przebudowa_indeksu_wymagana=${reindex_needed}"

  # --- sanity checker ------------------------------------------------------
  docker exec "$RESTORE_WEBSERVER" document_sanity_checker \
    > "${E3_RESULTS}/e3b-${cand}-sanity.log" 2>&1 || true
  tail -4 "${E3_RESULTS}/e3b-${cand}-sanity.log" | sed 's/^/    /'
  check "${cand}: sanity checker nie zgłasza problemów" \
    "$(grep -q 'No issues detected' "${E3_RESULTS}/e3b-${cand}-sanity.log" && echo yes || echo no)"

  # --- liczniki ------------------------------------------------------------
  local t_docs t_tags t_corr t_types t_trash
  t_docs="$(target_count documents)"; t_tags="$(target_count tags)"
  t_corr="$(target_count correspondents)"; t_types="$(target_count document_types)"
  t_trash="$(target_count trash)"
  m3_log "  cel: dokumenty=$t_docs tagi=$t_tags korespondenci=$t_corr typy=$t_types kosz=$t_trash"
  check "${cand}: liczba dokumentów zgodna ($t_docs/$DOCS_BEFORE)" \
    "$([ "$t_docs" = "$DOCS_BEFORE" ] && echo yes || echo no)"

  # --- reconciliation Core <-> Paperless i external IDs -------------------
  target_curl "$RESTORE_API/documents/?page_size=1000&ordering=id" \
    -o "${E3_RESULTS}/e3b-${cand}-documents.json"
  docker exec "${RESTORE_PROJECT}-core_fixture_db-1" psql -U core_fixture -d core_fixture -tAF$'\t' \
    -c 'SELECT external_id, checksum_sha256 FROM document_link ORDER BY external_id;' \
    > "${E3_RESULTS}/e3b-${cand}-links.tsv" 2>/dev/null

  python3 - "${E3_RESULTS}/e3b-${cand}-links.tsv" "${E3_RESULTS}/e3b-${cand}-documents.json" \
      "$RESTORE_API" "$TARGET_CFG" > "${E3_RESULTS}/e3b-${cand}-reconciliation.txt" <<'PY'
import json, subprocess, sys

links_path, docs_path, api, cfg = sys.argv[1:5]
links = []
with open(links_path, encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if line:
            external_id, checksum = line.split("\t")
            links.append((external_id, checksum))

docs = json.load(open(docs_path))["results"]
by_id = {}
for row in docs:
    out = subprocess.run(
        ["curl", "-sS", "-K", cfg, "-H", "Accept: application/json; version=10",
         f"{api}/documents/{row['id']}/metadata/"],
        capture_output=True, text=True).stdout
    try:
        by_id[row["id"]] = json.loads(out).get("original_checksum")
    except Exception:
        by_id[row["id"]] = None

checksums = set(by_id.values())
matched = mismatched = missing_doc = 0
for external_id, checksum in links:
    # external_id ma postać `paperless:<id>` — sprawdzamy obie strony powiązania.
    try:
        doc_id = int(external_id.split(":", 1)[1])
    except (IndexError, ValueError):
        mismatched += 1
        print(f"  BŁĘDNY external_id: {external_id}")
        continue
    if doc_id not in by_id:
        missing_doc += 1
        print(f"  brak dokumentu dla {external_id}")
    elif by_id[doc_id] != checksum:
        mismatched += 1
        if checksum in checksums:
            print(f"  {external_id}: wskazuje istniejący dokument, ale checksum należy do innego ID")
        else:
            print(f"  {external_id}: checksum niezgodny")
    else:
        matched += 1

print(f"__POWIAZAN__={len(links)}")
print(f"__ZGODNYCH__={matched}")
print(f"__NIEZGODNYCH__={mismatched}")
print(f"__BRAKUJACYCH__={missing_doc}")
PY
  grep -v '^__' "${E3_RESULTS}/e3b-${cand}-reconciliation.txt" | head -10 | sed 's/^/    /' || true
  local rec_total rec_ok rec_bad rec_missing
  rec_total="$(sed -n 's/^__POWIAZAN__=//p' "${E3_RESULTS}/e3b-${cand}-reconciliation.txt")"
  rec_ok="$(sed -n 's/^__ZGODNYCH__=//p' "${E3_RESULTS}/e3b-${cand}-reconciliation.txt")"
  rec_bad="$(sed -n 's/^__NIEZGODNYCH__=//p' "${E3_RESULTS}/e3b-${cand}-reconciliation.txt")"
  rec_missing="$(sed -n 's/^__BRAKUJACYCH__=//p' "${E3_RESULTS}/e3b-${cand}-reconciliation.txt")"
  m3_log "  reconciliation: powiązań=${rec_total} zgodnych=${rec_ok} niezgodnych=${rec_bad} brakujących=${rec_missing}"
  check "${cand}: reconciliation Core↔Paperless bez rozjazdu" \
    "$([ "$rec_bad" = "0" ] && [ "$rec_missing" = "0" ] && echo yes || echo no)"
  check "${cand}: wszystkie external IDs wskazują istniejące dokumenty" \
    "$([ "$rec_ok" = "$rec_total" ] && echo yes || echo no)"

  # --- checksumy assetów ---------------------------------------------------
  docker run --rm -v "${RESTORE_ASSETS_VOLUME}:/dst:ro" "$HELPER_IMAGE" \
    sh -c 'cd /dst && sha256sum *.txt' > "${E3_RESULTS}/e3b-${cand}-assets.txt" 2>/dev/null || true
  local asset_mismatch
  asset_mismatch="$(python3 - "${E3_RESULTS}/e3b-${cand}-assets.txt" "${MANIFEST_DIR}/source-manifest.json" <<'PY'
import json, sys
restored = {}
for line in open(sys.argv[1], encoding="utf-8"):
    parts = line.split()
    if len(parts) == 2:
        restored[parts[1]] = parts[0]
manifest = json.load(open(sys.argv[2]))
bad = 0
for asset in manifest["assety"]:
    name = asset["path"].rsplit("/", 1)[-1]
    if restored.get(name) != asset["checksum_sha256"]:
        bad += 1
print(bad)
PY
)"
  m3_log "  assetów o niezgodnej sumie=${asset_mismatch}"
  check "${cand}: checksumy assetów zgodne z manifestem" \
    "$([ "$asset_mismatch" = "0" ] && echo yes || echo no)"

  # --- otwieranie dokumentów, preview, OCR search -------------------------
  local first_id orig_code prev_code orig_bytes
  first_id="$(python3 -c '
import json,sys; print(json.load(open(sys.argv[1]))["results"][0]["id"])' "${E3_RESULTS}/e3b-${cand}-documents.json")"
  orig_code="$(curl -sS -K "$TARGET_CFG" -H "Accept: application/json; version=10" \
    "$RESTORE_API/documents/$first_id/download/?original=true" \
    -o "${E3_RESULTS}/e3b-${cand}-original.bin" -w '%{http_code}')"
  prev_code="$(curl -sS -K "$TARGET_CFG" -H "Accept: application/json; version=10" \
    "$RESTORE_API/documents/$first_id/preview/" \
    -o "${E3_RESULTS}/e3b-${cand}-preview.bin" -w '%{http_code}')"
  orig_bytes="$(wc -c < "${E3_RESULTS}/e3b-${cand}-original.bin")"
  m3_log "  dokument $first_id: original http=$orig_code (${orig_bytes} B) preview http=$prev_code"
  check "${cand}: oryginał otwiera się przez API" \
    "$([ "$orig_code" = "200" ] && [ "$orig_bytes" -gt 1000 ] && echo yes || echo no)"
  check "${cand}: preview otwiera się przez API" "$([ "$prev_code" = "200" ] && echo yes || echo no)"

  target_curl --get --data-urlencode "query=\"$phrase\"" "$RESTORE_API/documents/" \
    -o "${E3_RESULTS}/e3b-${cand}-search.json"
  local hits
  hits="$(python3 -c '
import json,sys; print(json.load(open(sys.argv[1]))["count"])' "${E3_RESULTS}/e3b-${cand}-search.json")"
  m3_log "  wyszukiwanie OCR: trafień=${hits}"
  check "${cand}: wyszukiwanie pełnotekstowe OCR działa po DR" \
    "$([ "$hits" -ge 1 ] && echo yes || echo no)"

  {
    echo "kandydat=${cand}"
    echo "czas_backupu_s=${backup_s}"
    echo "czas_restore_s=${restore_s}"
    echo "rozmiar_repozytorium_B=${repo_bytes}"
    echo "kod_przerwanego_backupu=${interrupt_rc}"
    echo "wymagane_break_lock=${needed_break_lock}"
    echo "wymagane_unlock=${needed_unlock}"
    echo "checksum_zestawu_zgodny=$([ "$restored_sha" = "$DR_TREE_SHA" ] && echo tak || echo nie)"
    echo "dokumenty_cel=${t_docs}"
    echo "document_link_cel=${core_links}"
    echo "asset_cel=${core_assets_rows}"
    echo "przebudowa_indeksu_wymagana=${reindex_needed}"
    echo "reconciliation_zgodnych=${rec_ok}/${rec_total}"
    echo "assety_niezgodne=${asset_mismatch}"
    echo "ocr_search_trafien=${hits}"
  } > "${E3_RESULTS}/e3b-${cand}-summary.txt"

  target_token_cleanup
  m3_log "  wynik zapisany: ${E3_RESULTS}/e3b-${cand}-summary.txt"
}

###########################################################################
DR_TREE_SHA=""
FREEZE_SECONDS=0
if [ "$REUSE_DATASET" -eq 1 ] && [ -s "${E3_DR_DIR}/CHECKSUMS.sha256" ]; then
  # Przeliczamy sumę zamiast czytać zapisaną: gwarantuje tę samą podstawę porównania.
  DR_TREE_SHA="$(e3b_dataset_sha "$E3_DR_DIR")"
  printf '%s\n' "$DR_TREE_SHA" > "${E3_DR_DIR}/meta/dataset-tree-sha256.txt"
  DOCS_BEFORE="$(m3_doc_count)"
  m3_log "Używam istniejącego zestawu DR: $DR_TREE_SHA"
else
  build_dataset
fi

for candidate in $CANDIDATES; do
  case "$candidate" in restic|borg) ;; *) m3_die "$M3_EXIT_USAGE" "nieznany kandydat: $candidate" ;; esac
  run_candidate "$candidate"
  if [ "$KEEP_TARGET" -eq 1 ] && [ "$candidate" = "${CANDIDATES##* }" ]; then
    m3_log "  pozostawiam cel restore (--keep-target)"
  else
    m3_section "Usunięcie celu restore po kandydacie ${candidate}"
    reset_restore_target
    m3_log "  cel restore usunięty i odtworzony od zera"
  fi
done

m3_section "Kontrola końcowa źródła"
m3_log "  dokumentów=$(m3_doc_count) (przed E3B=$DOCS_BEFORE)"
check "źródło ma niezmienioną liczbę dokumentów" \
  "$([ "$(m3_doc_count)" = "$DOCS_BEFORE" ] && echo yes || echo no)"
check "wolumeny źródła nadal istnieją" \
  "$([ "$(docker volume ls -q --filter 'name=homeos-m3-source-' | wc -l)" -ge 6 ] && echo yes || echo no)"

m3_section "Podsumowanie E3B"
printf '%s\n' "${RESULT_LINES[@]}" > "${E3_RESULTS}/e3b-checks.txt"
m3_log "  czas_zamrożenia_zapisów=${FREEZE_SECONDS}s"
m3_log "  kontroli nieudanych: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
