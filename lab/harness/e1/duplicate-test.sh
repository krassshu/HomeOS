#!/usr/bin/env bash
# E1-11c/E1-11d — zachowanie Paperless przy ponownym przesłaniu tego samego pliku.
#
# Wariant `reject` zmienia PAPERLESS_CONSUMER_DELETE_DUPLICATES na `true`
# i odtwarza WYŁĄCZNIE usługę webserver. Pierwotny plik środowiska jest
# przywracany w trapie EXIT, więc rollback wykonuje się także po błędzie testu.
# Skrypt nigdy nie używa `down`, `reset` ani operacji na wolumenach.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$HERE/common.sh"

usage() {
  cat <<'EOF'
Użycie: ./duplicate-test.sh --file PLIK [opcje]

Wysyła kopię wskazanego pliku, który jest już w Paperless, i zapisuje pełny
kontrakt zadania w API v10 oraz v9. Nie tworzy ani nie usuwa dokumentów poza
tym, co zrobi sam Paperless.

Wymagane:
  --file PLIK             fixture, którego dokument bazowy już istnieje

Opcje:
  --mode TRYB             current (domyślnie) | keep | reject
                            current — nie zmienia konfiguracji
                            keep    — wymusza DELETE_DUPLICATES=false
                            reject  — wymusza DELETE_DUPLICATES=true
                          keep i reject odtwarzają kontener webserver
                          i przywracają pierwotną konfigurację na końcu
  --expect-doc ID         ID dokumentu bazowego oczekiwanego w odpowiedzi
  --title TYTUŁ           tytuł przesyłanej kopii
  --raw-dir KATALOG       katalog wyników surowych (domyślnie $M3_RAW_DIR)
  --timeout SEKUNDY       oczekiwanie na stan healthy (domyślnie 180)
  -h, --help              ta pomoc

Token: PAPERLESS_API_TOKEN, PAPERLESS_TOKEN_FILE (0600)
       albo M3_ALLOW_CONTAINER_TOKEN=1.

Kody wyjścia: 0 PASS, 1 błąd, 2 błąd użycia, 3 niespełniony warunek wstępny,
4 FAIL kontroli, 5 odmowa.
EOF
}

FILE=""; MODE="current"; EXPECT_DOC=""; TITLE=""; HEALTH_TIMEOUT=180
KEY=PAPERLESS_CONSUMER_DELETE_DUPLICATES

while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2:?brak wartości dla --file}"; shift 2 ;;
    --mode) MODE="${2:?brak wartości dla --mode}"; shift 2 ;;
    --expect-doc) EXPECT_DOC="${2:?brak wartości dla --expect-doc}"; shift 2 ;;
    --title) TITLE="${2:?brak wartości dla --title}"; shift 2 ;;
    --raw-dir) M3_RAW_DIR="${2:?brak wartości dla --raw-dir}"; shift 2 ;;
    --timeout) HEALTH_TIMEOUT="${2:?brak wartości dla --timeout}"; shift 2 ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

[ -n "$FILE" ] || { usage >&2; m3_die "$M3_EXIT_USAGE" "wymagane --file"; }
[ -r "$FILE" ] || m3_die "$M3_EXIT_PRECONDITION" "plik nieczytelny: $FILE"
case "$MODE" in current|keep|reject) ;; *) m3_die "$M3_EXIT_USAGE" "nieznany tryb: $MODE" ;; esac
[[ "$HEALTH_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || m3_die "$M3_EXIT_USAGE" "--timeout musi być dodatnią liczbą całkowitą"

m3_require_cmds docker curl python3 sha256sum cmp
m3_require_project
m3_mkdir "$M3_RAW_DIR"

ENV_FILE="${M3_ENV_FILE:-${M3_LAB_DIR}/.env.${M3_TARGET}}"
ENV_BACKUP=""; ENV_SHA=""; TMP_DIR=""; CONFIG_CHANGED=0; CLEANED=0
FAILURES=0

check() { if [ "$2" = "yes" ]; then m3_log "  OK   $1"; else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); fi; }

recreate_webserver() {
  m3_compose up -d --no-deps --force-recreate webserver 2>&1 | sed 's/^/    /'
  m3_wait_healthy "$HEALTH_TIMEOUT"
}

cleanup() {
  local rc=$?
  trap - EXIT
  trap '' INT TERM HUP
  set +e
  [ "$CLEANED" -eq 1 ] && exit "$rc"
  CLEANED=1
  local rollback_failed=0
  if [ "$CONFIG_CHANGED" -eq 1 ] && [ -n "$ENV_BACKUP" ] && [ -f "$ENV_BACKUP" ]; then
    # Rollback ma pierwszeństwo przed zbieraniem wyników.
    m3_section "rollback konfiguracji (rc=$rc)"
    if cp -p "$ENV_BACKUP" "$ENV_FILE" && chmod 600 "$ENV_FILE"; then
      local now; now="$(sha256sum "$ENV_FILE" | cut -d' ' -f1)"
      if [ "$now" = "$ENV_SHA" ]; then
        m3_log "  plik_środowiska_przywrócony=yes"
        m3_log "  $KEY=$(grep "^$KEY=" "$ENV_FILE" | cut -d= -f2- || echo '<brak>')"
        if recreate_webserver; then
          m3_log "  webserver_healthy=yes"
        else
          m3_log "  webserver_healthy=NIE — WYMAGANA INTERWENCJA RĘCZNA"
          rollback_failed=1
        fi
      else
        m3_log "  plik_środowiska_przywrócony=NIE — NIE ODTWARZAM KONTENERA"
        rollback_failed=1
      fi
    else
      m3_log "  plik_środowiska_przywrócony=NIE — WYMAGANA INTERWENCJA RĘCZNA"
      rollback_failed=1
    fi
    docker inspect "$M3_WEBSERVER" --format '  image={{.Config.Image}}
  restart_count={{.RestartCount}}
  health={{.State.Health.Status}}' || true
    m3_log "  port=$(docker port "$M3_WEBSERVER" | tr '\n' ' ')"
  fi
  if [ -n "$ENV_BACKUP" ]; then shred -u "$ENV_BACKUP" 2>/dev/null || rm -f "$ENV_BACKUP"; fi
  if [ -n "$TMP_DIR" ]; then rm -rf "$TMP_DIR"; fi
  m3_token_cleanup
  if [ "$rollback_failed" -ne 0 ] && [ "$rc" -eq 0 ]; then rc="$M3_EXIT_ERROR"; fi
  exit "$rc"
}
trap cleanup EXIT

# --- zmiana konfiguracji tylko dla trybów keep i reject ---
if [ "$MODE" != "current" ]; then
  [ -f "$ENV_FILE" ] || m3_die "$M3_EXIT_PRECONDITION" "brak pliku środowiska: $ENV_FILE"
  WANT_VALUE="false"; [ "$MODE" = "reject" ] && WANT_VALUE="true"
  ENV_BACKUP="$(mktemp "${TMPDIR:-/tmp}/.m3-env-backup.XXXXXX")"
  chmod 600 "$ENV_BACKUP"
  cp -p "$ENV_FILE" "$ENV_BACKUP"
  ENV_SHA="$(sha256sum "$ENV_BACKUP" | cut -d' ' -f1)"

  m3_section "konfiguracja: $KEY=$WANT_VALUE"
  KEY_COUNT="$(grep -c "^$KEY=" "$ENV_FILE" || true)"
  [ "$KEY_COUNT" -le 1 ] || m3_die "$M3_EXIT_REFUSED" \
    "odmowa: $ENV_FILE zawiera $KEY_COUNT wystąpienia $KEY"
  if [ "$KEY_COUNT" -eq 1 ]; then
    # Podmiana wartości istniejącego klucza; bez dodawania drugiego wystąpienia.
    sed -i.bak "s|^$KEY=.*|$KEY=$WANT_VALUE|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  else
    printf '%s=%s\n' "$KEY" "$WANT_VALUE" >> "$ENV_FILE"
  fi
  chmod 600 "$ENV_FILE"
  CONFIG_CHANGED=1
  m3_log "  wystąpień_klucza=$(grep -c "^$KEY=" "$ENV_FILE")"

  m3_section "odtworzenie wyłącznie usługi webserver"
  START_TS="$(date +%s)"
  recreate_webserver || m3_die "$M3_EXIT_PRECONDITION" \
    "webserver nie osiągnął stanu healthy w ${HEALTH_TIMEOUT}s — trap wykonuje rollback"
  m3_log "  czas_do_healthy=$(( $(date +%s) - START_TS ))s"
  m3_log "  wartość_w_kontenerze=$(docker exec "$M3_WEBSERVER" printenv "$KEY")"
fi

m3_token_init

m3_section "stan przed próbą"
m3_curl "$M3_API/status/" -o "$M3_RAW_DIR/dup-status-before.json" >/dev/null
m3_status_summary "$M3_RAW_DIR/dup-status-before.json"
SRC_SHA="$(sha256sum "$FILE" | cut -d' ' -f1)"
BEFORE_COUNT="$(m3_doc_count)"
BEFORE_IDS="$(m3_docs_by_checksum "$SRC_SHA")"
m3_log "  sha256_wejścia=$SRC_SHA"
m3_log "  dokumentów_łącznie=$BEFORE_COUNT"
m3_log "  dokumenty_o_tej_sumie=${BEFORE_IDS:-<brak>}"
[ -n "$BEFORE_IDS" ] || m3_die "$M3_EXIT_PRECONDITION" \
  "w instancji nie ma dokumentu o sumie $SRC_SHA — najpierw wyślij dokument bazowy"

m3_section "przygotowanie kopii testowej"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/.m3-dup.XXXXXX")"
COPY="$TMP_DIR/$(basename "${FILE%.*}")-DUP-$MODE.${FILE##*.}"
cp "$FILE" "$COPY"; chmod 600 "$COPY"
m3_log "  kopia=$(basename "$COPY") uprawnienia=$(stat -c %a "$COPY" 2>/dev/null || stat -f %Lp "$COPY")"
check "kopia ma identyczną sumę SHA-256" \
  "$([ "$(sha256sum "$COPY" | cut -d' ' -f1)" = "$SRC_SHA" ] && echo yes || echo no)"
check "kopia identyczna bajtowo (cmp)" "$(cmp -s "$FILE" "$COPY" && echo yes || echo no)"

m3_section "upload kopii"
UPLOAD_ARGS=(-F "document=@$COPY")
[ -n "$TITLE" ] && UPLOAD_ARGS+=(-F "title=$TITLE")
UPLOAD_CODE="$(m3_curl "${UPLOAD_ARGS[@]}" \
  -D "$M3_RAW_DIR/dup-upload.headers" -o "$M3_RAW_DIR/dup-upload.json" -w '%{http_code}' \
  "$M3_API/documents/post_document/")"
  m3_log "  upload_http=$UPLOAD_CODE"
  check "upload zwrócił 200 (otrzymano $UPLOAD_CODE)" \
    "$([ "$UPLOAD_CODE" = "200" ] && echo yes || echo no)"
  [ "$UPLOAD_CODE" = "200" ] || m3_die "$M3_EXIT_FAIL" \
    "upload nie zwrócił UUID zadania"
  TASK="$(python3 -c '
import json, re, sys
v = json.load(open(sys.argv[1]))
if not isinstance(v, str) or not re.fullmatch(r"[0-9a-fA-F-]{36}", v):
    raise SystemExit(1)
print(v)' "$M3_RAW_DIR/dup-upload.json")" || m3_die "$M3_EXIT_FAIL" \
    "odpowiedź uploadu nie zawiera poprawnego UUID zadania"
m3_log "  task_uuid=$TASK"

STATUS="$(m3_poll_task "$TASK" "$M3_RAW_DIR/dup-task.json")"
m3_log "  status_końcowy=$STATUS"
check "zadanie osiągnęło stan końcowy" "$(m3_task_nonterminal "$STATUS" && echo no || echo yes)"

for v in 10 9; do
  m3_section "kontrakt zadania — API v$v"
  m3_curl_version "$v" "$M3_API/tasks/?task_id=$TASK" \
    -D "$M3_RAW_DIR/dup-task-v$v.headers" -o "$M3_RAW_DIR/dup-task-v$v.json"
  grep -iE '^(x-api-version|x-version):' "$M3_RAW_DIR/dup-task-v$v.headers" \
    | tr -d '\r' | sed 's/^/  /' || true
  python3 - "$M3_RAW_DIR/dup-task-v$v.json" "$v" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); version = sys.argv[2]
records = d if isinstance(d, list) else (d.get("results") or [])
print(f"  kształt={'lista JSON' if isinstance(d, list) else 'obiekt stronicowany count/results'}")
if not records:
    print("  BRAK REKORDU ZADANIA")
    raise SystemExit
t = records[0]
print("  klucze:", ", ".join(sorted(t.keys())))
for key in ("status", "task_type", "task_name", "type", "trigger_source",
            "wait_time_seconds", "duration_seconds",
            "related_document", "related_document_ids", "duplicate_documents",
            "duplicate_of", "duplicate_in_trash"):
    print(f"  {key}: "
          + (json.dumps(t[key], ensure_ascii=False) if key in t else "<pole nieobecne>"))
result = t.get("result_data")
if isinstance(result, dict):
    safe = {k: (f"<traceback {len(str(v))} znaków>" if k == "traceback" else v)
            for k, v in result.items()}
    print("  result_data:", json.dumps(safe, ensure_ascii=False))
    for key in ("document_id", "duplicate_of", "duplicate_in_trash",
                "error_type", "error_message"):
        print(f"  result_data.{key}: "
              + (json.dumps(result[key], ensure_ascii=False) if key in result else "<pole nieobecne>"))
elif "result" in t:
    text = t["result"]
    print("  result:", text if not isinstance(text, str) or len(text) <= 200
          else f"<{len(text)} znaków, prawdopodobny traceback>")
PY
done

m3_section "stan po próbie"
AFTER_COUNT="$(m3_doc_count)"
AFTER_IDS="$(m3_docs_by_checksum "$SRC_SHA")"
DELTA=$((AFTER_COUNT - BEFORE_COUNT))
m3_log "  dokumentów_łącznie=$AFTER_COUNT (delta=$DELTA)"
m3_log "  dokumenty_o_tej_sumie=${AFTER_IDS:-<brak>}"
for id in $BEFORE_IDS; do
  m3_log "  dokument_$id http=$(m3_curl -o /dev/null -w '%{http_code}' "$M3_API/documents/$id/")"
done

m3_section "log workera skorelowany z UUID zadania"
docker logs "$M3_WEBSERVER" --since 10m 2>&1 \
  | grep -iE "${TASK:0:8}|duplicate" | tail -20 | sed 's/^/  /' \
  | tee "$M3_RAW_DIR/dup-worker.log" >/dev/null || true
sed 's/^/  /' "$M3_RAW_DIR/dup-worker.log" 2>/dev/null || m3_log "  (brak dopasowanych linii)"

m3_section "zdrowie po próbie"
docker inspect "$M3_WEBSERVER" --format '  restart_count={{.RestartCount}} status={{.State.Status}} health={{.State.Health.Status}}'
m3_curl "$M3_API/status/" -o "$M3_RAW_DIR/dup-status-after.json" >/dev/null
m3_status_summary "$M3_RAW_DIR/dup-status-after.json"
check "webserver pozostał zdrowy" \
  "$([ "$(m3_health)" = "healthy" ] && echo yes || echo no)"

m3_section "kryteria wariantu odrzucania"
if [ "$MODE" = "reject" ]; then
  check "brak nowego rekordu dokumentu (delta=$DELTA)" \
    "$([ "$DELTA" -eq 0 ] && echo yes || echo no)"
  check "zbiór dokumentów o tej sumie bez zmian" \
    "$([ "$BEFORE_IDS" = "$AFTER_IDS" ] && echo yes || echo no)"
  TASK_KIND="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
r = d["results"] if isinstance(d, dict) and "results" in d else d
t = r[0] if r else {}; rd = t.get("result_data")
if not isinstance(rd, dict) or not isinstance(rd.get("duplicate_of"), int):
    print("other")
elif not isinstance(rd.get("duplicate_in_trash"), bool):
    print("other")
else:
    print("duplicate")' \
    "$M3_RAW_DIR/dup-task-v10.json")"
  check "result_data jednoznacznie opisuje odrzucony duplikat" \
    "$([ "$TASK_KIND" = "duplicate" ] && echo yes || echo no)"
  REPORTED="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
r = d["results"] if isinstance(d, dict) and "results" in d else d
rd = (r[0].get("result_data") or {}) if r else {}
print(rd.get("duplicate_of", ""))' \
    "$M3_RAW_DIR/dup-task-v10.json")"
  m3_log "  wskazany_dokument_istniejący=${REPORTED:-<brak>}"
  check "odpowiedź wskazuje istniejący dokument" \
    "$([ -n "$REPORTED" ] && echo yes || echo no)"
  check "wskazany dokument należał do zbioru sprzed próby" \
    "$(case " $BEFORE_IDS " in *" $REPORTED "*) echo yes ;; *) echo no ;; esac)"
  if [ -n "$EXPECT_DOC" ]; then
    check "wskazany dokument to $EXPECT_DOC" \
      "$([ "$REPORTED" = "$EXPECT_DOC" ] && echo yes || echo no)"
  fi
  IN_TRASH="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
r = d["results"] if isinstance(d, dict) and "results" in d else d
rd = (r[0].get("result_data") or {}) if r else {}
print(rd["duplicate_in_trash"] if "duplicate_in_trash" in rd else "<pole nieobecne>")' \
    "$M3_RAW_DIR/dup-task-v10.json")"
  m3_log "  informacja_o_koszu=$IN_TRASH"
  check "wynik rozróżnia duplikat w koszu" \
    "$([ "$IN_TRASH" != "<pole nieobecne>" ] && echo yes || echo no)"
  check "status API dla kontrolowanego odrzucenia to failure" \
    "$([ "$STATUS" = "failure" ] && echo yes || echo no)"
else
  m3_log "  (kryteria PASS wariantu odrzucania sprawdzane tylko przy --mode reject)"
fi

m3_section "podsumowanie"
m3_log "  tryb=$MODE"
m3_log "  kontroli nieudanych: $FAILURES"
m3_log "  wyniki surowe: $M3_RAW_DIR"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
