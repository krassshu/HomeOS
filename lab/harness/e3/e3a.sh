#!/usr/bin/env bash
# E3A — przenośność aplikacyjna Paperless dla Restic i Borg.
#
# Jeden eksport `document_exporter` jest zabezpieczany przez obu kandydatów,
# odtwarzany na każdorazowo czysty projekt `homeos-m3-restore` i importowany
# przez `document_importer` na pustej instancji 3.0.4 o tym samym digeście.
#
# Skrypt NIE dotyka wolumenów źródła: czyta je tylko przez eksporter Paperless.
# Jedynym środowiskiem usuwanym i odtwarzanym jest projekt restore.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common-e3.sh
source "${HERE}/common-e3.sh"

RESTORE_PROJECT="homeos-m3-restore"
RESTORE_API="${E3_RESTORE_API:-http://127.0.0.1:8100/api}"
RESTORE_WEBSERVER="${RESTORE_PROJECT}-webserver-1"
SOURCE_EXPORT_DIR="${E3_WORKSPACE}/lab-data/m3-source/export"
RESTORE_EXPORT_DIR="${E3_WORKSPACE}/lab-data/m3-restore/export"
MANIFEST_DIR="${E3_MANIFEST_DIR:-${E3_ROOT}/manifest}"
INTERRUPT_PAYLOAD="${E3_ROOT}/interrupt-payload"
INTERRUPT_MB="${E3_INTERRUPT_MB:-400}"

usage() {
  cat <<'EOF'
Użycie: ./e3a.sh [--candidates "restic borg"] [--reuse-export] [--keep-target]

Wykonuje pełny tor E3A dla wskazanych kandydatów. Domyślnie obaj.
  --reuse-export   użyj istniejącego eksportu zamiast tworzyć nowy
  --keep-target    nie usuwaj projektu restore po ostatnim kandydacie

Kody wyjścia: 0 PASS, 1 błąd, 2 użycie, 3 warunek wstępny, 4 FAIL, 5 odmowa.
EOF
}

CANDIDATES="restic borg"
REUSE_EXPORT=0
KEEP_TARGET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --candidates) CANDIDATES="${2:?brak wartości}"; shift 2 ;;
    --reuse-export) REUSE_EXPORT=1; shift ;;
    --keep-target) KEEP_TARGET=1; shift ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

m3_require_cmds docker python3 sha256sum curl timeout realpath
m3_require_project
e3_require_tools
e3_require_recovery_material
install -d -m 700 "$E3_RESULTS" "$E3_RESTORE_STAGING"

FAILURES=0
RESULT_LINES=()
check() {
  if [ "$2" = "yes" ]; then m3_log "  OK   $1"; RESULT_LINES+=("OK|$1")
  else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); RESULT_LINES+=("FAIL|$1"); fi
}

TARGET_CFG=""
SOURCE_STOPPED=0
SOURCE_DOCS_BEFORE=""
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
    m3_section "rollback: przywrócenie webservera źródła (rc=$rc)"
    m3_compose up -d webserver 2>&1 | sed 's/^/    /'
    if m3_wait_healthy 420; then
      SOURCE_STOPPED=0
    else
      m3_log "  webserver_healthy=NIE — WYMAGANA INTERWENCJA RĘCZNA"
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

# --- API celu restore ------------------------------------------------------
target_curl() {
  [ -n "$TARGET_CFG" ] || m3_die "$M3_EXIT_ERROR" "brak tokenu celu"
  curl -sS -K "$TARGET_CFG" -H "Accept: application/json; version=$M3_API_VERSION" \
    --max-time "$M3_HTTP_TIMEOUT" "$@"
}
target_curl_accept() {
  local accept="$1"; shift
  curl -sS -K "$TARGET_CFG" -H "Accept: $accept" --max-time "$M3_HTTP_TIMEOUT" "$@"
}
target_count() { # target_count <zasób>
  target_curl "$RESTORE_API/$1/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])'
}

# Nowy token celu. Tokeny przeniesione eksportem są kasowane, żeby dowieść,
# że cel działa bez materiału uwierzytelniającego ze źródła.
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
  grep -q '^header = "Authorization: Token ' "$TARGET_CFG" || return 1
  return 0
}

restore_compose() {
  M3_TARGET=restore M3_PROJECT="$RESTORE_PROJECT" M3_ENV_FILE="${M3_LAB_DIR}/.env.restore" \
    docker compose --env-file "${M3_LAB_DIR}/.env.restore" \
      -f "${M3_LAB_DIR}/compose.baseline.yaml" \
      -f "${M3_LAB_DIR}/compose.override.yaml" \
      -f "${M3_LAB_DIR}/compose.restore.yaml" \
      -f "${M3_LAB_DIR}/compose.valkey-shared.yaml" "$@"
}

# Usuwa WYŁĄCZNIE projekt restore. Nazwa jest sprawdzana dwukrotnie.
reset_restore_target() {
  [ "$RESTORE_PROJECT" = "homeos-m3-restore" ] || m3_die "$M3_EXIT_REFUSED" \
    "odmowa: nieoczekiwany projekt restore '$RESTORE_PROJECT'"
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
  install -d -m 700 "${E3_WORKSPACE}/lab-data/m3-restore" "$RESTORE_EXPORT_DIR" \
    "${E3_WORKSPACE}/lab-data/m3-restore/consume"
}

wait_target_healthy() { # wait_target_healthy [timeout]
  local max="${1:-420}" t=0
  while [ "$t" -lt "$max" ]; do
    [ "$(docker inspect "$RESTORE_WEBSERVER" --format '{{.State.Health.Status}}' 2>/dev/null)" = "healthy" ] && return 0
    sleep 3; t=$((t + 3))
  done
  return 1
}

###########################################################################
m3_section "0. Warunki wstępne — brak aktywnych zadań"
###########################################################################
ACTIVE="$(docker exec "$M3_WEBSERVER" celery -A paperless inspect active 2>/dev/null | grep -c '^\s*\*' || true)"
RESERVED="$(docker exec "$M3_WEBSERVER" celery -A paperless inspect reserved 2>/dev/null | grep -c '^\s*\*' || true)"
SOURCE_DOCS_BEFORE="$(m3_doc_count)"
m3_curl "$M3_API/tasks/?page_size=200" -o "${E3_RESULTS}/e3a-tasks-before.json"
ORPHANS="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
r = d["results"] if isinstance(d, dict) and "results" in d else d
stuck = [t["task_id"] for t in r if str(t.get("status", "")).lower() in ("started", "pending", "received", "retry")]
print(" ".join(stuck))' "${E3_RESULTS}/e3a-tasks-before.json")"
m3_log "  celery_active=$ACTIVE celery_reserved=$RESERVED"
m3_log "  zadania_nieterminalne_w_api=${ORPHANS:-<brak>}"
check "worker Celery nie wykonuje aktywnego zadania" \
  "$([ "$ACTIVE" -eq 0 ] && [ "$RESERVED" -eq 0 ] && echo yes || echo no)"
if [ -n "$ORPHANS" ]; then
  m3_log "  UWAGA: powyższe wpisy to osierocone zadania po próbie E1-13."
  m3_log "  Worker ich nie przetwarza; eksport obejmuje dokumenty, nie rekordy zadań."
fi

###########################################################################
m3_section "1. Pełny document_exporter 3.0.4 z kontrolą checksum"
###########################################################################
install -d -m 700 "$SOURCE_EXPORT_DIR"
if [ "$REUSE_EXPORT" -eq 1 ] && [ -s "${SOURCE_EXPORT_DIR}/manifest.json" ]; then
  [ -s "${E3_RESULTS}/e3a-export-freeze.txt" ] \
    || m3_die "$M3_EXIT_PRECONDITION" "brak dowodu kontrolowanego zamrożenia eksportu — wykonaj E3A bez --reuse-export"
  grep -q '^freeze_enforced=yes$' "${E3_RESULTS}/e3a-export-freeze.txt" \
    || m3_die "$M3_EXIT_PRECONDITION" "poprzedni eksport nie ma potwierdzonego punktu spójności"
  m3_log "  używam istniejącego eksportu"
else
  # Katalog eksportu to dane pochodne w lab-data, nie wolumen źródła.
  find "$SOURCE_EXPORT_DIR" -mindepth 1 -delete 2>/dev/null || true
  FREEZE_START="$(date +%s)"
  # Oryginalny webserver (API, consumer, worker) zostaje zatrzymany. Eksporter
  # działa w jednorazowym kontenerze tej samej usługi bez publikowania portów.
  # Flaga jest ustawiona przed `stop`, aby trap próbował rollbacku także po
  # częściowym błędzie polecenia.
  SOURCE_STOPPED=1
  m3_compose stop webserver 2>&1 | sed 's/^/    /'
  # Punkt spójności potwierdzamy stanem kontenera, a nie samym kodem `stop`.
  STOPPED_STATE="$(docker inspect "$M3_WEBSERVER" --format '{{.State.Status}}' 2>/dev/null || echo brak)"
  m3_log "  stan_webservera_źródła_podczas_eksportu=$STOPPED_STATE"
  [ "$STOPPED_STATE" = "exited" ] \
    || m3_die "$M3_EXIT_FAIL" "webserver źródła nie jest jednoznacznie zatrzymany (stan: $STOPPED_STATE)"
  EXPORT_START="$(date +%s)"
  # Obraz 3.0.4 startuje przez s6-overlay (`/init`). Przekazanie `document_exporter`
  # jako CMD nie uruchamia eksportera, tylko cały stack usług razem z workerem i
  # consumerem — czyli drugiego pisarza na danych źródła. Dlatego wołamy polecenie
  # administracyjne wprost, jako użytkownik `paperless`, w katalogu roboczym obrazu.
  # Bez `--service-ports` kontener jednorazowy nie publikuje żadnego portu hosta.
  #
  # `--skip-checks` jest tu konieczne: pakiet języka OCR `pol` instaluje dopiero
  # init obrazu, więc w kontenerze bez `/init` kontrola systemowa Django zgłasza
  # brak języka. Eksport czyta bazę i kopiuje pliki — OCR nie jest mu potrzebny.
  m3_compose run --rm --no-deps --entrypoint /command/s6-setuidgid webserver \
    paperless python3 manage.py document_exporter --skip-checks ../export --compare-checksums \
    > "${E3_RESULTS}/e3a-export.log" 2>&1
  EXPORT_END="$(date +%s)"
  m3_log "  czas_eksportu=$((EXPORT_END - EXPORT_START))s"
  tail -3 "${E3_RESULTS}/e3a-export.log" | sed 's/^/    /'
  EXPORT_LEFTOVERS="$(docker ps -a \
    --filter "label=com.docker.compose.project=${M3_PROJECT}" \
    --filter 'label=com.docker.compose.service=webserver' \
    --format '{{.Names}}' | grep -c -- '-webserver-run-' || true)"
  m3_log "  pozostawionych_kontenerów_exportera=$EXPORT_LEFTOVERS"
  [ "$EXPORT_LEFTOVERS" -eq 0 ] \
    || m3_die "$M3_EXIT_FAIL" "jednorazowy kontener exportera nie został usunięty"
  m3_compose up -d webserver 2>&1 | sed 's/^/    /'
  m3_wait_healthy 420 \
    || m3_die "$M3_EXIT_ERROR" "webserver źródła nie wrócił do stanu healthy po eksporcie"
  SOURCE_STOPPED=0
  FREEZE_END="$(date +%s)"
  SOURCE_DOCS_AFTER="$(m3_doc_count)"
  [ "$SOURCE_DOCS_AFTER" = "$SOURCE_DOCS_BEFORE" ] \
    || m3_die "$M3_EXIT_FAIL" "liczba dokumentów zmieniła się w oknie eksportu (${SOURCE_DOCS_BEFORE} -> ${SOURCE_DOCS_AFTER})"
  {
    echo "freeze_enforced=yes"
    echo "source_webserver_stopped=yes"
    echo "exporter_one_shot_without_service_ports=yes"
    echo "source_webserver_state_during_export=${STOPPED_STATE}"
    echo "exporter_container_leftovers=${EXPORT_LEFTOVERS}"
    echo "freeze_seconds=$((FREEZE_END - FREEZE_START))"
    echo "documents_before=${SOURCE_DOCS_BEFORE}"
    echo "documents_after=${SOURCE_DOCS_AFTER}"
  } > "${E3_RESULTS}/e3a-export-freeze.txt"
fi

EXPORT_FILES="$(find "$SOURCE_EXPORT_DIR" -type f | wc -l)"
EXPORT_BYTES="$(e3_bytes "$SOURCE_EXPORT_DIR")"
EXPORT_TREE_SHA="$(e3_sha256_dir "$SOURCE_EXPORT_DIR")"
m3_log "  plików=$EXPORT_FILES rozmiar=$EXPORT_BYTES B"
m3_log "  checksum_drzewa_eksportu=$EXPORT_TREE_SHA"
check "eksport zawiera manifest.json" \
  "$([ -s "${SOURCE_EXPORT_DIR}/manifest.json" ] && echo yes || echo no)"
check "eksport zawiera pliki oryginałów" \
  "$([ -d "${SOURCE_EXPORT_DIR}/originals" ] || find "$SOURCE_EXPORT_DIR" -name '*.pdf' -o -name '*.xlsx' -o -name '*.png' -o -name '*.docx' | head -1 | grep -q . && echo yes || echo no)"

EXPORT_DOCS="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(sum(1 for e in d if e.get("model") == "documents.document"))' "${SOURCE_EXPORT_DIR}/manifest.json")"
SRC_DOCS="$(m3_doc_count)"
SRC_TRASH="$(m3_curl "$M3_API/trash/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
# document_exporter 3.0.4 eksportuje również pozycje kosza, dlatego odniesieniem
# jest suma dokumentów aktywnych i w koszu, a nie samo `count` z /documents/.
EXPECTED_EXPORT_DOCS=$((SRC_DOCS + SRC_TRASH))
m3_log "  dokumentów w manifeście eksportu=$EXPORT_DOCS"
m3_log "  źródło: aktywne=$SRC_DOCS kosz=$SRC_TRASH razem=$EXPECTED_EXPORT_DOCS"
check "eksport zawiera wszystkie dokumenty źródła wraz z koszem ($EXPORT_DOCS/$EXPECTED_EXPORT_DOCS)" \
  "$([ "$EXPORT_DOCS" = "$EXPECTED_EXPORT_DOCS" ] && echo yes || echo no)"

# Manifest eksportu: lista plików i sum kontrolnych, bez tytułów.
( cd "$SOURCE_EXPORT_DIR" && find . -type f -print0 | sort -z | xargs -0 sha256sum ) \
  > "${E3_RESULTS}/e3a-export-checksums.txt"
chmod 600 "${E3_RESULTS}/e3a-export-checksums.txt"
{
  echo "checksum_drzewa=$EXPORT_TREE_SHA"
  echo "plikow=$EXPORT_FILES"
  echo "bajtow=$EXPORT_BYTES"
  echo "dokumentow=$EXPORT_DOCS"
} > "${E3_RESULTS}/e3a-export-manifest.txt"

###########################################################################
m3_section "2. Materiał do kontrolowanego przerwania backupu"
###########################################################################
# Materiał musi być NOWY przy każdej próbie: dane już obecne w repozytorium
# zostałyby zdeduplikowane i backup skończyłby się przed przerwaniem.
refresh_interrupt_payload() {
  e3_recreate_dir "$INTERRUPT_PAYLOAD"
  for i in $(seq 1 4); do
    dd if=/dev/urandom of="${INTERRUPT_PAYLOAD}/blob-${i}.bin" \
      bs=1M count=$((INTERRUPT_MB / 4)) status=none
  done
}
refresh_interrupt_payload
m3_log "  rozmiar_materiału_przerwania=$(e3_bytes "$INTERRUPT_PAYLOAD") B (dane losowe, nieściśliwe)"

###########################################################################
run_candidate() { # run_candidate <restic|borg>
  local cand="$1"
  local staging="${E3_RESTORE_STAGING}/${cand}"
  local t0 t1 backup_s restore_s repo_bytes snapshots_before snapshots_after

  m3_section "=== Kandydat: ${cand} ==="

  local needed_unlock=no

  # --- inicjalizacja repozytorium -----------------------------------------
  if [ "$cand" = "restic" ]; then
    if ! e3_restic cat config >/dev/null 2>&1; then
      e3_restic init 2>&1 | sed 's/^/    /'
    fi
    # Blokada po wcześniejszym zabitym backupie uniemożliwiłaby kontrolę.
    if [ -n "$(e3_restic list locks 2>/dev/null | head -1)" ]; then
      needed_unlock=yes
      e3_restic unlock 2>&1 | sed 's/^/    /'
      m3_log "  usunięto zaległą blokadę repozytorium restic"
    fi
    m3_log "  repozytorium=$E3_RESTIC_REPO"
  else
    # Przerwana inicjalizacja zostawia katalog bez manifestu. Taki pusty,
    # nieużywalny katalog laboratoryjny odtwarzamy; repozytorium z danymi nigdy.
    if [ -f "${E3_BORG_REPO}/config" ] && ! e3_borg info >/dev/null 2>&1; then
      if [ -z "$(find "${E3_BORG_REPO}/data" -type f 2>/dev/null | head -1)" ]; then
        case "$E3_BORG_REPO" in
          */lab-data/e3/repositories/borg)
            m3_log "  wykryto niedokończoną inicjalizację repozytorium borg — odtwarzam pusty katalog"
            e3_assert_safe_path "$E3_BORG_REPO"
            rm -rf "${E3_BORG_REPO:?}"/* ;;
          *) m3_die "$M3_EXIT_REFUSED" "odmowa czyszczenia nieoczekiwanej ścieżki repozytorium" ;;
        esac
      else
        m3_die "$M3_EXIT_PRECONDITION" \
          "repozytorium borg zawiera dane, ale jest nieczytelne — wymagana ręczna diagnoza"
      fi
    fi
    if ! e3_borg info >/dev/null 2>&1; then
      e3_borg init --encryption=repokey-blake2 2>&1 | sed 's/^/    /'
      # Klucz repokey mieszka w repozytorium — eksport daje drugi, niezależny egzemplarz.
      e3_borg key export :: "$E3_BORG_KEY_A" 2>&1 | sed 's/^/    /'
      cp "$E3_BORG_KEY_A" "$E3_BORG_KEY_B"
      chmod 600 "$E3_BORG_KEY_A" "$E3_BORG_KEY_B"
      m3_log "  klucz repozytorium wyeksportowany do obu kopii odzyskiwania"
    fi
    m3_log "  repozytorium=$E3_BORG_REPO"
  fi

  # --- backup eksportu -----------------------------------------------------
  t0="$(date +%s)"
  if [ "$cand" = "restic" ]; then
    e3_restic backup "$SOURCE_EXPORT_DIR" --tag e3a --tag export \
      > "${E3_RESULTS}/e3a-${cand}-backup.log" 2>&1
  else
    e3_borg create --stats --compression zstd "::e3a-export-{now:%Y%m%dT%H%M%S}" "$SOURCE_EXPORT_DIR" \
      > "${E3_RESULTS}/e3a-${cand}-backup.log" 2>&1
  fi
  t1="$(date +%s)"; backup_s=$((t1 - t0))
  m3_log "  czas_backupu=${backup_s}s"
  tail -4 "${E3_RESULTS}/e3a-${cand}-backup.log" | sed 's/^/    /'

  if [ "$cand" = "restic" ]; then
    snapshots_before="$(e3_restic snapshots --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  else
    snapshots_before="$(e3_borg list --format '{archive}{NL}' | grep -c . || true)"
  fi
  m3_log "  snapshotów_po_backupie=$snapshots_before"
  check "${cand}: backup eksportu utworzył restore point" \
    "$([ "$snapshots_before" -ge 1 ] && echo yes || echo no)"

  # --- pełna kontrola integralności ---------------------------------------
  if [ "$cand" = "restic" ]; then
    if e3_restic check --read-data > "${E3_RESULTS}/e3a-${cand}-check.log" 2>&1; then
      check "restic: check --read-data bez błędów" yes
    else
      check "restic: check --read-data bez błędów" no
    fi
  else
    if e3_borg check --verify-data > "${E3_RESULTS}/e3a-${cand}-check.log" 2>&1; then
      check "borg: check --verify-data bez błędów" yes
    else
      check "borg: check --verify-data bez błędów" no
    fi
  fi
  tail -3 "${E3_RESULTS}/e3a-${cand}-check.log" | sed 's/^/    /'

  # --- kontrolowane przerwanie dodatkowego backupu ------------------------
  m3_log "  przerwanie dodatkowego backupu po 2 s (SIGKILL)"
  set +e
  if [ "$cand" = "restic" ]; then
    timeout -s KILL 2 env RESTIC_PASSWORD_FILE="$E3_RESTIC_PASSWORD_A" \
      RESTIC_REPOSITORY="$E3_RESTIC_REPO" "$E3_RESTIC" backup "$INTERRUPT_PAYLOAD" --tag interrupted \
      > "${E3_RESULTS}/e3a-${cand}-interrupted.log" 2>&1
  else
    timeout -s KILL 2 env BORG_PASSCOMMAND="cat ${E3_BORG_PASSPHRASE_A}" \
      BORG_REPO="$E3_BORG_REPO" "$E3_BORG" create "::interrupted-{now:%Y%m%dT%H%M%S}" "$INTERRUPT_PAYLOAD" \
      > "${E3_RESULTS}/e3a-${cand}-interrupted.log" 2>&1
  fi
  local interrupt_rc=$?
  set -e
  m3_log "  kod_wyjścia_przerwanego_backupu=$interrupt_rc"
  check "${cand}: przerwany backup zakończył się niezerowym kodem" \
    "$([ "$interrupt_rc" -ne 0 ] && echo yes || echo no)"

  # Obaj kandydaci zostawiają po SIGKILL blokadę, którą trzeba zdjąć ręcznie.
  # Liczba takich kroków jest częścią oceny diagnostyki i runbooka.
  local needed_break_lock=no
  if [ "$cand" = "borg" ]; then
    if ! e3_borg list >/dev/null 2>&1; then
      needed_break_lock=yes
      e3_borg break-lock 2>&1 | sed 's/^/    /' || true
    fi
  else
    if [ -n "$(e3_restic list locks 2>/dev/null | head -1)" ]; then
      needed_unlock=yes
      e3_restic unlock 2>&1 | sed 's/^/    /' || true
    fi
  fi
  m3_log "  wymagane_break_lock=$needed_break_lock wymagane_unlock=$needed_unlock"

  # --- wcześniejszy restore point nadal dostępny ---------------------------
  if [ "$cand" = "restic" ]; then
    snapshots_after="$(e3_restic snapshots --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  else
    snapshots_after="$(e3_borg list --format '{archive}{NL}' | grep -c . || true)"
  fi
  m3_log "  snapshotów_po_przerwaniu=$snapshots_after"
  check "${cand}: poprzedni poprawny restore point pozostał dostępny" \
    "$([ "$snapshots_after" -ge "$snapshots_before" ] && echo yes || echo no)"

  # --- bezpieczne ponowienie ----------------------------------------------
  set +e
  if [ "$cand" = "restic" ]; then
    e3_restic backup "$INTERRUPT_PAYLOAD" --tag retry \
      > "${E3_RESULTS}/e3a-${cand}-retry.log" 2>&1
  else
    e3_borg create --compression zstd "::retry-{now:%Y%m%dT%H%M%S}" "$INTERRUPT_PAYLOAD" \
      > "${E3_RESULTS}/e3a-${cand}-retry.log" 2>&1
  fi
  local retry_rc=$?
  set -e
  check "${cand}: ponowienie backupu po przerwaniu powiodło się" \
    "$([ "$retry_rc" -eq 0 ] && echo yes || echo no)"

  if [ "$cand" = "restic" ]; then
    repo_bytes="$(e3_bytes "$E3_RESTIC_REPO")"
  else
    repo_bytes="$(e3_bytes "$E3_BORG_REPO")"
  fi
  m3_log "  rozmiar_repozytorium=${repo_bytes} B"

  # --- restore eksportu do stagingu ---------------------------------------
  e3_recreate_dir "$staging"
  t0="$(date +%s)"
  if [ "$cand" = "restic" ]; then
    local snap_id
    snap_id="$(e3_restic snapshots --json --tag export \
      | python3 -c 'import json,sys; s=json.load(sys.stdin); print(s[-1]["id"])')"
    e3_restic restore "$snap_id" --target "$staging" \
      > "${E3_RESULTS}/e3a-${cand}-restore.log" 2>&1
  else
    local archive
    archive="$(e3_borg list --format '{archive}{NL}' | grep '^e3a-export-' | tail -1)"
    ( cd "$staging" && BORG_PASSCOMMAND="cat ${E3_BORG_PASSPHRASE_A}" BORG_REPO="$E3_BORG_REPO" \
        "$E3_BORG" extract "::${archive}" ) > "${E3_RESULTS}/e3a-${cand}-restore.log" 2>&1
  fi
  t1="$(date +%s)"; restore_s=$((t1 - t0))
  m3_log "  czas_restore=${restore_s}s"

  local restored_root
  restored_root="$(dirname "$(find "$staging" -name manifest.json -type f | head -1)")"
  [ -n "$restored_root" ] || m3_die "$M3_EXIT_FAIL" "${cand}: nie znaleziono manifest.json w odtworzonym eksporcie"
  local restored_sha; restored_sha="$(e3_sha256_dir "$restored_root")"
  m3_log "  checksum_drzewa_odtworzonego=$restored_sha"
  check "${cand}: odtworzony eksport jest bajtowo identyczny z oryginałem" \
    "$([ "$restored_sha" = "$EXPORT_TREE_SHA" ] && echo yes || echo no)"

  # --- czysty cel restore --------------------------------------------------
  m3_log "  czyszczenie i odtworzenie projektu ${RESTORE_PROJECT}"
  reset_restore_target
  cp -a "${restored_root}/." "${RESTORE_EXPORT_DIR}/"
  m3_log "  plików w katalogu importu=$(find "$RESTORE_EXPORT_DIR" -type f | wc -l)"

  restore_compose up -d > "${E3_RESULTS}/e3a-${cand}-up.log" 2>&1
  if wait_target_healthy 420; then
    check "${cand}: pusta instancja 3.0.4 wystartowała" yes
  else
    check "${cand}: pusta instancja 3.0.4 wystartowała" no
    docker logs "$RESTORE_WEBSERVER" --tail 20 2>&1 | sed 's/^/    /'
    return 0
  fi

  local target_digest
  target_digest="$(docker image inspect "$(docker inspect "$RESTORE_WEBSERVER" --format '{{.Image}}')" \
    --format '{{range .RepoDigests}}{{.}}{{end}}')"
  m3_log "  digest_celu=$target_digest"
  check "${cand}: cel używa tego samego digestu 3.0.4" \
    "$(printf '%s' "$target_digest" | grep -q '3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582' && echo yes || echo no)"

  # --- izolacja od źródła --------------------------------------------------
  local target_mounts shared_mounts
  target_mounts="$(docker inspect "$RESTORE_WEBSERVER" "${RESTORE_PROJECT}-db-1" \
    "${RESTORE_PROJECT}-broker-1" --format '{{range .Mounts}}{{.Name}}{{.Source}} {{end}}')"
  shared_mounts="$(printf '%s' "$target_mounts" | tr ' ' '\n' | grep -c 'homeos-m3-source' || true)"
  m3_log "  odwołań_do_zasobów_source=$shared_mounts"
  check "${cand}: cel nie używa wolumenów ani katalogów źródła" \
    "$([ "$shared_mounts" -eq 0 ] && echo yes || echo no)"

  # --- import --------------------------------------------------------------
  t0="$(date +%s)"
  set +e
  restore_compose exec -T webserver document_importer ../export \
    > "${E3_RESULTS}/e3a-${cand}-import.log" 2>&1
  local import_rc=$?
  set -e
  t1="$(date +%s)"
  m3_log "  czas_importu=$((t1 - t0))s kod=$import_rc"
  tail -4 "${E3_RESULTS}/e3a-${cand}-import.log" | sed 's/^/    /'
  check "${cand}: document_importer zakończył się sukcesem" \
    "$([ "$import_rc" -eq 0 ] && echo yes || echo no)"

  # --- nowy token celu -----------------------------------------------------
  if target_new_token; then
    check "${cand}: wygenerowano nowy token celu (bez tokenu źródła)" yes
  else
    check "${cand}: wygenerowano nowy token celu (bez tokenu źródła)" no
    return 0
  fi

  # --- sanity checker ------------------------------------------------------
  set +e
  docker exec "$RESTORE_WEBSERVER" document_sanity_checker \
    > "${E3_RESULTS}/e3a-${cand}-sanity.log" 2>&1
  set -e
  tail -4 "${E3_RESULTS}/e3a-${cand}-sanity.log" | sed 's/^/    /'
  check "${cand}: sanity checker nie zgłasza problemów" \
    "$(grep -q 'No issues detected' "${E3_RESULTS}/e3a-${cand}-sanity.log" && echo yes || echo no)"

  # --- liczniki i metadane -------------------------------------------------
  local t_docs t_tags t_corr t_types t_trash
  t_docs="$(target_count documents)"; t_tags="$(target_count tags)"
  t_corr="$(target_count correspondents)"; t_types="$(target_count document_types)"
  t_trash="$(target_count trash)"
  local s_tags s_corr s_types s_trash
  s_tags="$(m3_curl "$M3_API/tags/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
  s_corr="$(m3_curl "$M3_API/correspondents/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
  s_types="$(m3_curl "$M3_API/document_types/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
  s_trash="$(m3_curl "$M3_API/trash/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
  m3_log "  cel: dokumenty=$t_docs tagi=$t_tags korespondenci=$t_corr typy=$t_types kosz=$t_trash"
  m3_log "  źródło: dokumenty=$SRC_DOCS tagi=$s_tags korespondenci=$s_corr typy=$s_types kosz=$s_trash"
  check "${cand}: liczba dokumentów zgodna ($t_docs/$SRC_DOCS)" \
    "$([ "$t_docs" = "$SRC_DOCS" ] && echo yes || echo no)"
  check "${cand}: liczba tagów zgodna ($t_tags/$s_tags)" \
    "$([ "$t_tags" = "$s_tags" ] && echo yes || echo no)"
  check "${cand}: liczba korespondentów zgodna ($t_corr/$s_corr)" \
    "$([ "$t_corr" = "$s_corr" ] && echo yes || echo no)"
  check "${cand}: liczba typów zgodna ($t_types/$s_types)" \
    "$([ "$t_types" = "$s_types" ] && echo yes || echo no)"

  # --- checksumy dokumentów wobec manifestu źródłowego --------------------
  target_curl "$RESTORE_API/documents/?page_size=1000&ordering=id" \
    -o "${E3_RESULTS}/e3a-${cand}-documents.json"
  local mismatch
  mismatch="$(python3 - "${MANIFEST_DIR}/source-manifest.json" "${E3_RESULTS}/e3a-${cand}-documents.json" \
      "$RESTORE_API" "$TARGET_CFG" <<'PY'
import json, subprocess, sys
manifest = json.load(open(sys.argv[1]))
target = json.load(open(sys.argv[2]))
api, cfg = sys.argv[3], sys.argv[4]
expected = {d["original_checksum_sha256"] for d in manifest["dokumenty"]}
found = set()
for row in target["results"]:
    out = subprocess.run(
        ["curl", "-sS", "-K", cfg, "-H", "Accept: application/json; version=10",
         f"{api}/documents/{row['id']}/metadata/"],
        capture_output=True, text=True).stdout
    try:
        found.add(json.loads(out).get("original_checksum"))
    except Exception:
        pass
missing = expected - found
print(len(missing))
PY
)"
  m3_log "  checksumy z manifestu nieodnalezione w celu=$mismatch"
  check "${cand}: wszystkie checksumy dokumentów odtworzone" \
    "$([ "$mismatch" = "0" ] && echo yes || echo no)"

  # --- otwarcie oryginału i preview przez API -----------------------------
  local first_id orig_code prev_code orig_bytes
  first_id="$(python3 -c '
import json,sys; print(json.load(open(sys.argv[1]))["results"][0]["id"])' "${E3_RESULTS}/e3a-${cand}-documents.json")"
  orig_code="$(target_curl_accept "application/json; version=$M3_API_VERSION" \
    "$RESTORE_API/documents/$first_id/download/?original=true" \
    -o "${E3_RESULTS}/e3a-${cand}-original.bin" -w '%{http_code}')"
  prev_code="$(target_curl_accept "application/json; version=$M3_API_VERSION" \
    "$RESTORE_API/documents/$first_id/preview/" \
    -o "${E3_RESULTS}/e3a-${cand}-preview.bin" -w '%{http_code}')"
  orig_bytes="$(wc -c < "${E3_RESULTS}/e3a-${cand}-original.bin")"
  m3_log "  dokument $first_id: original http=$orig_code (${orig_bytes} B), preview http=$prev_code"
  check "${cand}: oryginał otwiera się przez API" \
    "$([ "$orig_code" = "200" ] && [ "$orig_bytes" -gt 1000 ] && echo yes || echo no)"
  check "${cand}: preview otwiera się przez API" \
    "$([ "$prev_code" = "200" ] && echo yes || echo no)"

  # --- OCR search ----------------------------------------------------------
  local phrase="SYGNATURA DUPLIKATU ALFA BRAVO 2026"
  target_curl --get --data-urlencode "query=\"$phrase\"" "$RESTORE_API/documents/" \
    -o "${E3_RESULTS}/e3a-${cand}-search.json"
  local hits
  hits="$(python3 -c '
import json,sys; print(json.load(open(sys.argv[1]))["count"])' "${E3_RESULTS}/e3a-${cand}-search.json")"
  m3_log "  wyszukiwanie OCR \"$phrase\": trafień=$hits"
  check "${cand}: wyszukiwanie pełnotekstowe OCR działa w celu" \
    "$([ "$hits" -ge 1 ] && echo yes || echo no)"

  {
    echo "kandydat=${cand}"
    echo "czas_backupu_s=${backup_s}"
    echo "czas_restore_s=${restore_s}"
    echo "rozmiar_repozytorium_B=${repo_bytes}"
    echo "snapshotow_przed_przerwaniem=${snapshots_before}"
    echo "snapshotow_po_przerwaniu=${snapshots_after}"
    echo "kod_przerwanego_backupu=${interrupt_rc}"
    echo "wymagane_break_lock=${needed_break_lock}"
    echo "wymagane_unlock=${needed_unlock}"
    echo "checksum_drzewa_zgodny=$([ "$restored_sha" = "$EXPORT_TREE_SHA" ] && echo tak || echo nie)"
    echo "dokumenty_cel=${t_docs}"
    echo "tagi_cel=${t_tags}"
    echo "korespondenci_cel=${t_corr}"
    echo "typy_cel=${t_types}"
    echo "kosz_cel=${t_trash}"
    echo "checksumy_nieodnalezione=${mismatch}"
    echo "ocr_search_trafien=${hits}"
  } > "${E3_RESULTS}/e3a-${cand}-summary.txt"

  target_token_cleanup
  m3_log "  wynik kandydata zapisany: ${E3_RESULTS}/e3a-${cand}-summary.txt"
}
###########################################################################

for candidate in $CANDIDATES; do
  case "$candidate" in restic|borg) ;; *) m3_die "$M3_EXIT_USAGE" "nieznany kandydat: $candidate" ;; esac
  run_candidate "$candidate"
  m3_section "Usunięcie celu restore po kandydacie ${candidate}"
  if [ "$KEEP_TARGET" -eq 1 ] && [ "$candidate" = "${CANDIDATES##* }" ]; then
    m3_log "  pozostawiam cel restore (--keep-target)"
  else
    reset_restore_target
    m3_log "  cel restore usunięty i odtworzony od zera"
  fi
done

m3_section "Kontrola końcowa źródła"
m3_log "  dokumentów w źródle=$(m3_doc_count) (przed E3A=$SRC_DOCS)"
check "źródło ma niezmienioną liczbę dokumentów" \
  "$([ "$(m3_doc_count)" = "$SRC_DOCS" ] && echo yes || echo no)"
check "wolumeny źródła nadal istnieją" \
  "$([ "$(docker volume ls -q --filter 'name=homeos-m3-source-' | wc -l)" -ge 6 ] && echo yes || echo no)"

m3_section "Podsumowanie E3A"
printf '%s\n' "${RESULT_LINES[@]}" > "${E3_RESULTS}/e3a-checks.txt"
m3_log "  kontroli nieudanych: $FAILURES"
m3_log "  wyniki: $E3_RESULTS"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
