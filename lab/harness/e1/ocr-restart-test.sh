#!/usr/bin/env bash
# E1-13 — kontrolowany restart Paperless w trakcie OCR.
#
# Skrypt wysyła syntetyczny, wielostronicowy dokument rastrowy, potwierdza stan
# `started`, a następnie odtwarza WYŁĄCZNIE usługę webserver. Sprawdza, czy
# dokument nie zginął, nie powstał podwójnie i kończy się sukcesem albo czytelnym
# błędem. Nie zmienia konfiguracji, nie wykonuje `down`, `reset` ani operacji na
# wolumenach i nie usuwa żadnego dokumentu.
#
# Materiał jest syntetyczny. To NIE jest test rzeczywistego skanu papierowego.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$HERE/common.sh"

usage() {
  cat <<'EOF'
Użycie: ./ocr-restart-test.sh --file PLIK [opcje]

Wymagane:
  --file PLIK           wielostronicowy fixture rastrowy bez warstwy tekstowej

Opcje:
  --expect-pages N      oczekiwana liczba stron (domyślnie 20)
  --phrase FRAZA        fraza kontrolna szukana w treści OCR
  --title TYTUŁ         tytuł przesyłanego dokumentu
  --raw-dir KATALOG     katalog wyników surowych (domyślnie $M3_RAW_DIR)
  --started-timeout S   czas oczekiwania na stan started (domyślnie 120)
  --final-timeout S     czas oczekiwania na stan końcowy po restarcie (domyślnie 900)
  --timeout S           oczekiwanie na healthy po restarcie (domyślnie 300)
  -h, --help            ta pomoc

Kody wyjścia: 0 PASS, 1 błąd lub nieudany rollback, 2 błąd użycia,
3 niespełniony warunek wstępny, 4 FAIL kontroli, 5 odmowa.
EOF
}

FILE=""; TITLE="E1-13 restart w trakcie OCR"; EXPECT_PAGES=20
PHRASE="SYGNATURA RESTARTU OCR DELTA ECHO 2026"
STARTED_TIMEOUT=120; FINAL_TIMEOUT=900; HEALTH_TIMEOUT=300

while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2:?brak wartości dla --file}"; shift 2 ;;
    --expect-pages) EXPECT_PAGES="${2:?brak wartości dla --expect-pages}"; shift 2 ;;
    --phrase) PHRASE="${2:?brak wartości dla --phrase}"; shift 2 ;;
    --title) TITLE="${2:?brak wartości dla --title}"; shift 2 ;;
    --raw-dir) M3_RAW_DIR="${2:?brak wartości dla --raw-dir}"; shift 2 ;;
    --started-timeout) STARTED_TIMEOUT="${2:?brak wartości}"; shift 2 ;;
    --final-timeout) FINAL_TIMEOUT="${2:?brak wartości}"; shift 2 ;;
    --timeout) HEALTH_TIMEOUT="${2:?brak wartości}"; shift 2 ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

[ -n "$FILE" ] || { usage >&2; m3_die "$M3_EXIT_USAGE" "wymagane --file"; }
[ -r "$FILE" ] || m3_die "$M3_EXIT_PRECONDITION" "plik nieczytelny: $FILE"

m3_require_cmds docker curl python3 sha256sum
m3_require_project
m3_mkdir "$M3_RAW_DIR"

ENV_FILE="${M3_ENV_FILE:-${M3_LAB_DIR}/.env.${M3_TARGET}}"
ENV_SHA_BEFORE=""; DOCS_BEFORE=""; TRASH_BEFORE=""; IMAGE_BEFORE=""
CLEANED=0; FAILURES=0

check() { if [ "$2" = "yes" ]; then m3_log "  OK   $1"; else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); fi; }

# `/api/status/` wymaga uwierzytelnienia: bez tokenu zwraca 401, co wyglądałoby
# jak niedostępność usługi i zawyżało zmierzony czas przerwy.
api_up() {
  local code
  [ -n "$M3_CURL_CFG" ] || return 1
  code="$(curl -s -o /dev/null -w '%{http_code}' -K "$M3_CURL_CFG" \
    -H "Accept: application/json; version=$M3_API_VERSION" \
    --max-time 5 "$M3_API/status/" 2>/dev/null || true)"
  [ "$code" = "200" ]
}

# Rollback: po tym teście source musi mieć niezmienioną konfigurację, zdrowy
# webserver i nie mniej dokumentów niż przed próbą.
cleanup() {
  local rc=$?
  trap - EXIT
  trap '' INT TERM HUP
  set +e
  [ "$CLEANED" -eq 1 ] && exit "$rc"
  CLEANED=1
  local rollback_failed=0

  m3_section "kontrola stanu końcowego source (rc=$rc)"

  if [ -n "$ENV_SHA_BEFORE" ] && [ -f "$ENV_FILE" ]; then
    local now; now="$(sha256sum "$ENV_FILE" | cut -d' ' -f1)"
    if [ "$now" = "$ENV_SHA_BEFORE" ]; then
      m3_log "  konfiguracja_niezmieniona=yes"
    else
      m3_log "  konfiguracja_niezmieniona=NIE — WYMAGANA INTERWENCJA RĘCZNA"
      rollback_failed=1
    fi
  fi

  if [ "$(m3_health)" = "healthy" ]; then
    m3_log "  webserver_healthy=yes"
  else
    m3_log "  webserver nie jest healthy — próba odtworzenia usługi"
    m3_compose up -d --no-deps webserver 2>&1 | sed 's/^/    /'
    if m3_wait_healthy "$HEALTH_TIMEOUT"; then
      m3_log "  webserver_healthy=yes (po odtworzeniu)"
    else
      m3_log "  webserver_healthy=NIE — WYMAGANA INTERWENCJA RĘCZNA"
      m3_log "  sprawdź: docker logs $M3_WEBSERVER oraz plik $ENV_FILE"
      rollback_failed=1
    fi
  fi

  docker inspect "$M3_WEBSERVER" --format '  image={{.Config.Image}}
  restart_count={{.RestartCount}}
  health={{.State.Health.Status}}' 2>/dev/null || true

  if [ -n "$DOCS_BEFORE" ] && api_up; then
    local docs_after; docs_after="$(m3_doc_count 2>/dev/null || echo '?')"
    m3_log "  dokumentów_przed=$DOCS_BEFORE dokumentów_po=$docs_after"
    if [ "$docs_after" != "?" ] && [ "$docs_after" -lt "$DOCS_BEFORE" ]; then
      m3_log "  UBYŁO DOKUMENTÓW — WYMAGANA INTERWENCJA RĘCZNA"
      rollback_failed=1
    fi
  fi

  m3_token_cleanup
  if [ "$rollback_failed" -ne 0 ] && [ "$rc" -eq 0 ]; then rc="$M3_EXIT_ERROR"; fi
  exit "$rc"
}
trap cleanup EXIT

m3_token_init

m3_section "1. Stan przed próbą"
[ -f "$ENV_FILE" ] && ENV_SHA_BEFORE="$(sha256sum "$ENV_FILE" | cut -d' ' -f1)"
SRC_SHA="$(sha256sum "$FILE" | cut -d' ' -f1)"
SRC_SIZE="$(wc -c < "$FILE")"
DOCS_BEFORE="$(m3_doc_count)"
TRASH_BEFORE="$(m3_curl "$M3_API/trash/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
IMAGE_BEFORE="$(docker inspect "$M3_WEBSERVER" --format '{{.Config.Image}}')"
RESTARTS_BEFORE="$(docker inspect "$M3_WEBSERVER" --format '{{.RestartCount}}')"
m3_curl "$M3_API/status/" -o "$M3_RAW_DIR/e1-13-status-before.json" >/dev/null
m3_log "  plik=$(basename "$FILE") rozmiar=$SRC_SIZE sha256=$SRC_SHA"
m3_log "  dokumentów_przed=$DOCS_BEFORE kosz_przed=$TRASH_BEFORE"
m3_log "  obraz=$IMAGE_BEFORE restart_count=$RESTARTS_BEFORE"
m3_status_summary "$M3_RAW_DIR/e1-13-status-before.json"
BEFORE_IDS="$(m3_docs_by_checksum "$SRC_SHA")"
m3_log "  dokumenty_o_tej_sumie_przed=${BEFORE_IDS:-<brak>}"
[ -z "$BEFORE_IDS" ] || m3_die "$M3_EXIT_PRECONDITION" \
  "dokument o sumie $SRC_SHA już istnieje (ID: $BEFORE_IDS) — użyj świeżego fixture"

m3_section "2. Upload i potwierdzenie stanu started"
UPLOAD_CODE="$(m3_curl -F "document=@$FILE" -F "title=$TITLE" \
  -D "$M3_RAW_DIR/e1-13-upload.headers" -o "$M3_RAW_DIR/e1-13-upload.json" -w '%{http_code}' \
  "$M3_API/documents/post_document/")"
m3_log "  upload_http=$UPLOAD_CODE"
[ "$UPLOAD_CODE" = "200" ] || m3_die "$M3_EXIT_FAIL" "upload zwrócił $UPLOAD_CODE"
TASK="$(python3 -c '
import json, re, sys
v = json.load(open(sys.argv[1]))
if not isinstance(v, str) or not re.fullmatch(r"[0-9a-fA-F-]{36}", v):
    raise SystemExit(1)
print(v)' "$M3_RAW_DIR/e1-13-upload.json")" || m3_die "$M3_EXIT_FAIL" \
  "odpowiedź uploadu nie zawiera poprawnego UUID zadania"
m3_log "  task_uuid=$TASK"

STARTED_AT=""; SEEN_STATUS=""
UPLOAD_TS="$(date +%s)"
for ((i = 0; i < STARTED_TIMEOUT * 4; i++)); do
  SEEN_STATUS="$(m3_curl "$M3_API/tasks/?task_id=$TASK" \
    | python3 -c 'import json,sys
d=json.load(sys.stdin); r=d["results"] if isinstance(d,dict) and "results" in d else d
print(r[0]["status"] if r else "absent")' 2>/dev/null || echo absent)"
  case "$SEEN_STATUS" in
    started|STARTED) STARTED_AT="$(date +%s)"; break ;;
    success|SUCCESS|failure|FAILURE) break ;;
  esac
  sleep 0.25
done
m3_log "  status_zaobserwowany=$SEEN_STATUS"
if [ -n "$STARTED_AT" ]; then
  m3_log "  czas_do_started=$((STARTED_AT - UPLOAD_TS))s"
fi
check "zadanie osiągnęło stan started przed restartem" \
  "$([ -n "$STARTED_AT" ] && echo yes || echo no)"
[ -n "$STARTED_AT" ] || m3_die "$M3_EXIT_FAIL" \
  "nie zaobserwowano stanu started (ostatni: $SEEN_STATUS) — dokument przetworzył się za szybko na próbę restartu"

m3_section "3. Stan workera przed restartem"
# Obraz 3.0.4 nie zawiera `ps`, więc listę procesów czytamy z /proc.
worker_processes() {
  docker exec "$M3_WEBSERVER" sh -c '
    for p in /proc/[0-9]*; do
      [ -r "$p/cmdline" ] || continue
      printf "%s " "${p#/proc/}"
      tr "\0" " " < "$p/cmdline"
      echo
    done' 2>/dev/null | grep -iE 'celery|ocrmypdf|tesseract|document_consumer|granian' || true
}
worker_processes > "$M3_RAW_DIR/e1-13-worker-before.txt"
m3_log "  procesów_workera=$(wc -l < "$M3_RAW_DIR/e1-13-worker-before.txt")"
sed 's/^/    /' "$M3_RAW_DIR/e1-13-worker-before.txt" | head -8 || true

m3_section "4. Kontrolowane odtworzenie wyłącznie usługi webserver"
DOWN_START="$(date +%s)"
m3_compose up -d --no-deps --force-recreate webserver 2>&1 | sed 's/^/    /'

API_BACK=""
for ((i = 0; i < HEALTH_TIMEOUT; i++)); do
  if api_up; then API_BACK="$(date +%s)"; break; fi
  sleep 1
done
[ -n "$API_BACK" ] && m3_log "  czas_niedostępności_api=$((API_BACK - DOWN_START))s" \
  || m3_log "  API nie wróciło w ${HEALTH_TIMEOUT}s"

HEALTHY_AT=""
if m3_wait_healthy "$HEALTH_TIMEOUT"; then
  HEALTHY_AT="$(date +%s)"
  m3_log "  czas_do_healthy=$((HEALTHY_AT - DOWN_START))s"
else
  m3_log "  webserver nie osiągnął healthy w ${HEALTH_TIMEOUT}s"
fi
check "webserver wrócił do stanu healthy" "$([ -n "$HEALTHY_AT" ] && echo yes || echo no)"
m3_log "  restart_count_po=$(docker inspect "$M3_WEBSERVER" --format '{{.RestartCount}}')"
m3_log "  obraz_po=$(docker inspect "$M3_WEBSERVER" --format '{{.Config.Image}}')"
check "obraz nie zmienił się po odtworzeniu" \
  "$([ "$(docker inspect "$M3_WEBSERVER" --format '{{.Config.Image}}')" = "$IMAGE_BEFORE" ] && echo yes || echo no)"

m3_section "5. Ten sam UUID po restarcie"
FINAL_STATUS="$(m3_poll_task "$TASK" "$M3_RAW_DIR/e1-13-task-after.json" "$FINAL_TIMEOUT")"
m3_log "  status_po_restarcie=$FINAL_STATUS"
python3 - "$M3_RAW_DIR/e1-13-task-after.json" <<'PY' | tee "$M3_RAW_DIR/e1-13-task-summary.txt"
import json, sys
d = json.load(open(sys.argv[1]))
r = d["results"] if isinstance(d, dict) and "results" in d else d
if not r:
    print("  rekord_zadania=<brak>")
    raise SystemExit
t = r[0]
print("  klucze:", ", ".join(sorted(t.keys())))
for key in ("status", "task_name", "related_document_ids", "related_document"):
    if key in t:
        print(f"  {key}: {json.dumps(t[key], ensure_ascii=False)}")
rd = t.get("result_data")
if isinstance(rd, dict):
    safe = {k: (f"<traceback {len(str(v))} znaków>" if k == "traceback" else v)
            for k, v in rd.items()}
    print("  result_data:", json.dumps(safe, ensure_ascii=False))
elif t.get("result"):
    text = t["result"]
    print("  result:", text if len(str(text)) <= 200 else f"<{len(str(text))} znaków>")
PY
check "rekord tego samego zadania jest dostępny po restarcie" \
  "$(grep -q 'rekord_zadania=<brak>' "$M3_RAW_DIR/e1-13-task-summary.txt" && echo no || echo yes)"
check "zadanie osiągnęło stan końcowy albo czytelny brak" \
  "$(m3_task_nonterminal "$FINAL_STATUS" && echo no || echo yes)"

m3_section "6. Czy dokument zginął albo powstał podwójnie"
AFTER_IDS="$(m3_docs_by_checksum "$SRC_SHA")"
AFTER_COUNT="$(m3_doc_count)"
DOC_N="$(printf '%s' "$AFTER_IDS" | wc -w | tr -d ' ')"
m3_log "  dokumenty_o_tej_sumie_po=${AFTER_IDS:-<brak>} (liczba=$DOC_N)"
m3_log "  dokumentów_łącznie=$AFTER_COUNT (przed=$DOCS_BEFORE)"
TRASH_AFTER="$(m3_curl "$M3_API/trash/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
m3_log "  kosz_po=$TRASH_AFTER (przed=$TRASH_BEFORE)"
check "nie powstał duplikat dokumentu (liczba <= 1)" \
  "$([ "$DOC_N" -le 1 ] && echo yes || echo no)"
check "żaden wcześniejszy dokument nie zniknął" \
  "$([ "$AFTER_COUNT" -ge "$DOCS_BEFORE" ] && echo yes || echo no)"

OUTCOME="nieznany"
if [ "$DOC_N" -eq 1 ]; then
  OUTCOME="dokument-utworzony"
elif [ "$FINAL_STATUS" = "failure" ] || [ "$FINAL_STATUS" = "FAILURE" ]; then
  OUTCOME="czytelny-błąd"
elif [ "$FINAL_STATUS" = "absent" ]; then
  OUTCOME="zadanie-zniknęło-bez-dokumentu"
fi
m3_log "  wynik_próby=$OUTCOME"
check "próba zakończyła się sukcesem albo czytelnym błędem" \
  "$(case "$OUTCOME" in dokument-utworzony|czytelny-błąd) echo yes ;; *) echo no ;; esac)"

if [ "$DOC_N" -eq 1 ]; then
  DOC_ID="$AFTER_IDS"
  m3_section "7. Kontrola dokumentu $DOC_ID"
  m3_curl "$M3_API/documents/$DOC_ID/" -o "$M3_RAW_DIR/e1-13-document.json" >/dev/null
  m3_curl "$M3_API/documents/$DOC_ID/metadata/" -o "$M3_RAW_DIR/e1-13-metadata.json" >/dev/null
  python3 - "$M3_RAW_DIR/e1-13-document.json" "$M3_RAW_DIR/e1-13-metadata.json" \
    "$EXPECT_PAGES" "$SRC_SHA" "$PHRASE" <<'PY' | tee "$M3_RAW_DIR/e1-13-checks.txt"
import json, sys
doc = json.load(open(sys.argv[1])); meta = json.load(open(sys.argv[2]))
expect_pages = int(sys.argv[3]); src_sha = sys.argv[4]; phrase = sys.argv[5]
content = doc.get("content") or ""
print(f"  page_count={doc.get('page_count')}")
print(f"  content_chars={len(content)}")
print(f"  original_checksum={meta.get('original_checksum')}")
print(f"  has_archive_version={meta.get('has_archive_version')}")
print(f"  archive_size={meta.get('archive_size')}")
print(f"  lang={meta.get('lang')}")
print(f"__PAGES_OK__={'yes' if doc.get('page_count') == expect_pages else 'no'}")
print(f"__OCR_OK__={'yes' if len(content) > 100 else 'no'}")
norm = " ".join(content.split()).upper()
print(f"__PHRASE_OK__={'yes' if phrase.upper() in norm else 'no'}")
print(f"__ARCHIVE_OK__={'yes' if meta.get('has_archive_version') else 'no'}")
print(f"__CHECKSUM_OK__={'yes' if meta.get('original_checksum') == src_sha else 'no'}")
PY
  grep -v '^__' "$M3_RAW_DIR/e1-13-checks.txt" >/dev/null 2>&1 || true
  val() { sed -n "s/^__${1}__=\(.*\)/\1/p" "$M3_RAW_DIR/e1-13-checks.txt"; }
  check "liczba stron zgodna z wejściem ($EXPECT_PAGES)" "$(val PAGES_OK)"
  check "OCR wyprodukował treść" "$(val OCR_OK)"
  check "fraza kontrolna odnaleziona w treści OCR" "$(val PHRASE_OK)"
  check "archive PDF istnieje" "$(val ARCHIVE_OK)"
  check "checksum oryginału zgodny z plikiem wejściowym" "$(val CHECKSUM_OK)"

  m3_section "8. Wyszukiwanie pełnotekstowe frazy kontrolnej"
  m3_curl --get --data-urlencode "query=\"$PHRASE\"" "$M3_API/documents/" \
    -o "$M3_RAW_DIR/e1-13-search.json" >/dev/null
  FOUND="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(" ".join(str(r["id"]) for r in d.get("results", [])))' "$M3_RAW_DIR/e1-13-search.json")"
  m3_log "  trafienia=${FOUND:-<brak>}"
  check "dokument odnajduje się po frazie kontrolnej" \
    "$(case " $FOUND " in *" $DOC_ID "*) echo yes ;; *) echo no ;; esac)"
else
  m3_section "7. Kontrola dokumentu"
  m3_log "  (brak dokumentu do sprawdzenia — patrz wynik_próby)"
fi

m3_section "9. Sanity checker"
if docker exec "$M3_WEBSERVER" document_sanity_checker > "$M3_RAW_DIR/e1-13-sanity.txt" 2>&1; then
  SANITY_OK=yes
else
  SANITY_OK=no
fi
tail -4 "$M3_RAW_DIR/e1-13-sanity.txt" | sed 's/^/    /'
check "sanity checker nie zgłasza problemów" \
  "$(grep -q 'No issues detected' "$M3_RAW_DIR/e1-13-sanity.txt" && echo yes || echo "$SANITY_OK")"

m3_section "10. Stan workera i API po restarcie"
worker_processes > "$M3_RAW_DIR/e1-13-worker-after.txt"
m3_log "  procesów_workera_po=$(wc -l < "$M3_RAW_DIR/e1-13-worker-after.txt")"
sed 's/^/    /' "$M3_RAW_DIR/e1-13-worker-after.txt" | head -8 || true
m3_curl "$M3_API/status/" -o "$M3_RAW_DIR/e1-13-status-after.json" >/dev/null
m3_status_summary "$M3_RAW_DIR/e1-13-status-after.json"
STATUS_OK="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1])); t = d["tasks"]
ok = d["database"]["status"] == "OK" and all(t[k] == "OK" for k in ("redis_status","celery_status","index_status"))
print("yes" if ok else "no")' "$M3_RAW_DIR/e1-13-status-after.json")"
check "wszystkie podsystemy OK po restarcie" "$STATUS_OK"

docker logs "$M3_WEBSERVER" --since 20m 2>&1 | grep -iE "${TASK:0:8}|ocr|consume" \
  | tail -25 > "$M3_RAW_DIR/e1-13-webserver.log" || true
m3_log "  log skorelowany: $M3_RAW_DIR/e1-13-webserver.log"

m3_section "Podsumowanie E1-13"
m3_log "  task_uuid=$TASK"
m3_log "  status_końcowy=$FINAL_STATUS"
m3_log "  wynik_próby=$OUTCOME"
m3_log "  kontroli nieudanych: $FAILURES"
m3_log "  materiał syntetyczny — próba NIE zamyka wymagania rzeczywistego skanu"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
