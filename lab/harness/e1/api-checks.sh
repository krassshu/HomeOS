#!/usr/bin/env bash
# Odtwarzalne kontrole kontraktu API E1 dla uruchomionej instancji Paperless.
# Kontrole niczego nie usuwają. Polecenia `upload` i `all` tworzą trwały rekord,
# jeżeli Paperless przyjmie plik; pozostałe polecenia są tylko do odczytu.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$HERE/common.sh"

usage() {
  cat <<'EOF'
Użycie: ./api-checks.sh <polecenie> [opcje]

Polecenia:
  status                    GET /api/status/ — wersja, DB, Valkey, Celery, indeks
  version                   nagłówki X-Api-Version i X-Version
  schema                    pobiera OpenAPI do katalogu wyników i liczy ścieżki
  upload   --file PLIK      wysyła plik, odpytuje zadanie do stanu końcowego
           [--title TYTUŁ]
  task     --uuid UUID      reprezentacja zadania w API v10 i v9
  document --id ID          detail i metadata dokumentu
  download --id ID          original, preview i thumb + sumy kontrolne
  search   --query FRAZA    wyszukiwanie pełnotekstowe dokładnej frazy
  checksum --sha256 SUMA    dokumenty dzielące podaną sumę kontrolną
  all      --file PLIK      status, version, upload, document, download

Opcje wspólne:
  --raw-dir KATALOG         katalog wyników surowych (domyślnie $M3_RAW_DIR)
  --api-version 9|10        wersja nagłówka Accept (domyślnie 10)
  -h, --help                ta pomoc

Token (nigdy w argumentach ani logach), w kolejności:
  PAPERLESS_API_TOKEN          — zmienna środowiskowa
  PAPERLESS_TOKEN_FILE         — plik 0600 zawierający sam token
  M3_ALLOW_CONTAINER_TOKEN=1   — jednorazowe pobranie z instancji laboratoryjnej

Kody wyjścia: 0 OK, 1 błąd, 2 błąd użycia, 3 niespełniony warunek wstępny,
4 kontrola nie przeszła, 5 odmowa (nieoczekiwany projekt lub ochrona).
EOF
}

CMD="${1:-}"; [ $# -gt 0 ] && shift || true
FILE=""; TITLE=""; DOC_ID=""; UUID=""; QUERY=""; SHA=""

while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2:?brak wartości dla --file}"; shift 2 ;;
    --title) TITLE="${2:?brak wartości dla --title}"; shift 2 ;;
    --id) DOC_ID="${2:?brak wartości dla --id}"; shift 2 ;;
    --uuid) UUID="${2:?brak wartości dla --uuid}"; shift 2 ;;
    --query) QUERY="${2:?brak wartości dla --query}"; shift 2 ;;
    --sha256) SHA="${2:?brak wartości dla --sha256}"; shift 2 ;;
    --raw-dir) M3_RAW_DIR="${2:?brak wartości dla --raw-dir}"; shift 2 ;;
    --api-version) M3_API_VERSION="${2:?brak wartości dla --api-version}"; shift 2 ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

case "$CMD" in
  ""|-h|--help) usage; exit "$M3_EXIT_OK" ;;
  status|version|schema|upload|task|document|download|search|checksum|all) ;;
  *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznane polecenie: $CMD" ;;
esac

case "$M3_API_VERSION" in 9|10) ;; *) m3_die "$M3_EXIT_USAGE" "--api-version musi mieć wartość 9 albo 10" ;; esac

m3_require_cmds docker curl python3 sha256sum
m3_require_project
m3_mkdir "$M3_RAW_DIR"
trap m3_token_cleanup EXIT
m3_token_init

FAILURES=0
check() { # check <opis> <warunek_ok:yes|no>
  if [ "$2" = "yes" ]; then m3_log "  OK   $1"; else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); fi
}

cmd_status() {
  m3_section "status"
  local code
  code="$(m3_curl "$M3_API/status/" -D "$M3_RAW_DIR/status.headers" -o "$M3_RAW_DIR/status.json" -w '%{http_code}')"
  check "HTTP 200 (otrzymano $code)" "$([ "$code" = "200" ] && echo yes || echo no)"
  [ "$code" = "200" ] || return 0
  m3_status_summary "$M3_RAW_DIR/status.json"
  python3 - "$M3_RAW_DIR/status.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); t = d["tasks"]
bad = [k for k in ("redis_status", "celery_status", "index_status") if t[k] != "OK"]
if d["database"]["status"] != "OK":
    bad.append("database")
print("  wszystkie_podsystemy_OK=" + ("yes" if not bad else "no: " + ",".join(bad)))
PY
  local subsystems
  subsystems="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1])); t = d["tasks"]
ok = d["database"]["status"] == "OK" and all(t[k] == "OK" for k in ("redis_status", "celery_status", "index_status"))
print("yes" if ok else "no")' "$M3_RAW_DIR/status.json")"
  check "DB, Valkey, Celery i indeks w stanie OK" "$subsystems"
}

cmd_version() {
  m3_section "wersja"
  local code
  code="$(m3_curl "$M3_API/documents/?page_size=1" \
    -D "$M3_RAW_DIR/version.headers" -o /dev/null -w '%{http_code}')"
  check "endpoint wersji zwrócił 200 (otrzymano $code)" "$([ "$code" = "200" ] && echo yes || echo no)"
  [ "$code" = "200" ] || return 0
  grep -iE '^(x-api-version|x-version):' "$M3_RAW_DIR/version.headers" \
    | tr -d '\r' | sed 's/^/  /' || true
  local api_v
  api_v="$(grep -i '^x-api-version:' "$M3_RAW_DIR/version.headers" | tr -d '\r' | awk '{print $2}')"
  check "nagłówek X-Api-Version obecny" "$([ -n "$api_v" ] && echo yes || echo no)"
}

cmd_schema() {
  m3_section "OpenAPI"
  local code
  code="$(m3_curl_accept "application/vnd.oai.openapi; version=$M3_API_VERSION" \
    "$M3_API/schema/" -o "$M3_RAW_DIR/openapi.yaml" -w '%{http_code}')"
  check "schemat zwrócił HTTP 200 (otrzymano $code)" "$([ "$code" = "200" ] && echo yes || echo no)"
  [ "$code" = "200" ] || return 0
  m3_log "  sha256=$(sha256sum "$M3_RAW_DIR/openapi.yaml" | cut -d' ' -f1)"
  m3_log "  bajtów=$(wc -c < "$M3_RAW_DIR/openapi.yaml")"
  m3_log "  ścieżek=$(grep -cE '^  /' "$M3_RAW_DIR/openapi.yaml" || true)"
  check "schemat pobrany i niepusty" "$([ -s "$M3_RAW_DIR/openapi.yaml" ] && echo yes || echo no)"
}

cmd_upload() {
  [ -n "$FILE" ] || m3_die "$M3_EXIT_USAGE" "upload wymaga --file"
  [ -r "$FILE" ] || m3_die "$M3_EXIT_PRECONDITION" "plik nieczytelny: $FILE"
  m3_section "upload: $(basename "$FILE")"
  local before after sha code
  sha="$(sha256sum "$FILE" | cut -d' ' -f1)"
  before="$(m3_doc_count)"
  m3_log "  sha256_wejścia=$sha rozmiar=$(wc -c < "$FILE")"
  m3_log "  dokumentów_przed=$before"
  local args=(-F "document=@$FILE")
  [ -n "$TITLE" ] && args+=(-F "title=$TITLE")
  code="$(m3_curl "${args[@]}" \
    -D "$M3_RAW_DIR/upload.headers" -o "$M3_RAW_DIR/upload.json" -w '%{http_code}' \
    "$M3_API/documents/post_document/")"
  m3_log "  upload_http=$code"
  check "upload zwrócił 200 (otrzymano $code)" "$([ "$code" = "200" ] && echo yes || echo no)"
  [ "$code" = "200" ] || return 0
  UUID="$(python3 -c '
import json, re, sys
v = json.load(open(sys.argv[1]))
if not isinstance(v, str) or not re.fullmatch(r"[0-9a-fA-F-]{36}", v):
    raise SystemExit(1)
print(v)' "$M3_RAW_DIR/upload.json")" || {
    check "odpowiedź uploadu zawiera UUID zadania" no
    return 0
  }
  check "odpowiedź uploadu zawiera UUID zadania" yes
  m3_log "  task_uuid=$UUID"
  local status
  status="$(m3_poll_task "$UUID" "$M3_RAW_DIR/task.json")"
  m3_log "  status_końcowy=$status"
  check "zadanie osiągnęło stan końcowy" \
    "$(m3_task_nonterminal "$status" && echo no || echo yes)"
  if ! cmd_task_report "$M3_RAW_DIR/task.json" 10; then
    check "odpowiedź zawiera rekord zadania" no
  else
    check "odpowiedź zawiera rekord zadania" yes
  fi
  after="$(m3_doc_count)"
  m3_log "  dokumentów_po=$after (delta=$((after - before)))"
  m3_log "  dokumenty_o_tej_sumie=$(m3_docs_by_checksum "$sha")"
}

cmd_task_report() { # cmd_task_report <plik_json> <wersja>
  python3 - "$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); version = sys.argv[2]
records = d if isinstance(d, list) else (d.get("results") or [])
shape = "lista JSON" if isinstance(d, list) else "obiekt stronicowany count/results"
print(f"  kształt_odpowiedzi[v{version}]={shape}")
if not records:
    print("  BRAK REKORDU ZADANIA")
    raise SystemExit(1)
t = records[0]
print("  klucze:", ", ".join(sorted(t.keys())))
for key in ("status", "task_type", "task_name", "type", "trigger_source",
            "wait_time_seconds", "duration_seconds",
            "related_document", "related_document_ids", "duplicate_documents",
            "duplicate_of", "duplicate_in_trash"):
    if key in t:
        print(f"  {key}: {json.dumps(t[key], ensure_ascii=False)}")
result = t.get("result_data")
if isinstance(result, dict):
    # Traceback bywa długi i ujawnia wewnętrzne ścieżki — nie trafia do podsumowania.
    safe = {k: (f"<traceback {len(str(v))} znaków>" if k == "traceback" else v)
            for k, v in result.items()}
    print("  result_data:", json.dumps(safe, ensure_ascii=False))
elif "result" in t:
    text = t["result"]
    print("  result:", text if not isinstance(text, str) or len(text) <= 200
          else f"<{len(text)} znaków, prawdopodobny traceback>")
PY
}

cmd_task() {
  [ -n "$UUID" ] || m3_die "$M3_EXIT_USAGE" "task wymaga --uuid"
  local v
  for v in 10 9; do
    m3_section "zadanie $UUID — API v$v"
    local code
    code="$(m3_curl_version "$v" "$M3_API/tasks/?task_id=$UUID" \
      -D "$M3_RAW_DIR/task-v$v.headers" -o "$M3_RAW_DIR/task-v$v.json" -w '%{http_code}')"
    check "task v$v zwrócił 200 (otrzymano $code)" "$([ "$code" = "200" ] && echo yes || echo no)"
    [ "$code" = "200" ] || continue
    grep -iE '^(x-api-version|x-version):' "$M3_RAW_DIR/task-v$v.headers" \
      | tr -d '\r' | sed 's/^/  /' || true
    if ! cmd_task_report "$M3_RAW_DIR/task-v$v.json" "$v"; then
      check "task v$v zawiera rekord zadania" no
    else
      check "task v$v zawiera rekord zadania" yes
    fi
  done
}

cmd_document() {
  [ -n "$DOC_ID" ] || m3_die "$M3_EXIT_USAGE" "document wymaga --id"
  m3_section "dokument $DOC_ID"
  local code
  code="$(m3_curl "$M3_API/documents/$DOC_ID/" -o "$M3_RAW_DIR/document-$DOC_ID.json" -w '%{http_code}')"
  check "detail zwrócił 200 (otrzymano $code)" "$([ "$code" = "200" ] && echo yes || echo no)"
  [ "$code" = "200" ] || return 0
  code="$(m3_curl "$M3_API/documents/$DOC_ID/metadata/" \
    -o "$M3_RAW_DIR/metadata-$DOC_ID.json" -w '%{http_code}')"
  check "metadata zwróciły 200 (otrzymano $code)" "$([ "$code" = "200" ] && echo yes || echo no)"
  [ "$code" = "200" ] || return 0
  python3 - "$M3_RAW_DIR/document-$DOC_ID.json" "$M3_RAW_DIR/metadata-$DOC_ID.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1])); meta = json.load(open(sys.argv[2]))
print(f"  title={doc.get('title')!r} page_count={doc.get('page_count')} "
      f"content_chars={len(doc.get('content') or '')}")
for key in ("original_filename", "original_mime_type", "original_size",
            "original_checksum", "has_archive_version", "archive_size",
            "archive_checksum", "lang"):
    print(f"  {key}: {meta.get(key)}")
PY
}

cmd_download() {
  [ -n "$DOC_ID" ] || m3_die "$M3_EXIT_USAGE" "download wymaga --id"
  m3_section "pobrania dokumentu $DOC_ID"
  check_binary_endpoint original "$M3_API/documents/$DOC_ID/download/?original=true" \
    "application/pdf" "application/pdf"
  check_binary_endpoint preview "$M3_API/documents/$DOC_ID/preview/" \
    "application/pdf" "application/pdf"
  check_binary_endpoint thumb "$M3_API/documents/$DOC_ID/thumb/" \
    "image/webp" "image/"
}

# Endpointy binarne 3.0.4 (`/download/`, `/preview/`, `/thumb/`) odpowiadają
# właściwym typem, ale nie ogłaszają go jako akceptowanego: zadeklarowanie typu
# docelowego w `Accept` kończy się `406`, również z parametrem `version`.
# Kontrola wykonuje i zapisuje obie próby, a przechodzi wtedy, gdy zawartość jest
# osiągalna wariantem docelowym albo sprawdzonym fallbackiem i ma oczekiwany typ.
check_binary_endpoint() { # <nazwa> <url> <typ_docelowy> <oczekiwany_prefiks_content_type>
  local kind="$1" url="$2" target_type="$3" want_ctype="$4"
  local primary="${target_type}; version=$M3_API_VERSION"
  local fallback="application/json; version=$M3_API_VERSION"
  local primary_code fallback_code="" ctype

  primary_code="$(m3_curl_accept "$primary" "$url" \
    -D "$M3_RAW_DIR/$kind-$DOC_ID-primary.headers" \
    -o "$M3_RAW_DIR/$kind-$DOC_ID-primary.bin" -w '%{http_code}')"
  m3_log "  $kind [Accept: $primary] http=$primary_code"

  if [ "$primary_code" = "200" ]; then
    cp "$M3_RAW_DIR/$kind-$DOC_ID-primary.bin" "$M3_RAW_DIR/$kind-$DOC_ID.bin"
    cp "$M3_RAW_DIR/$kind-$DOC_ID-primary.headers" "$M3_RAW_DIR/$kind-$DOC_ID.headers"
    m3_log "  $kind wariant=zadeklarowany typ docelowy"
  else
    fallback_code="$(m3_curl_accept "$fallback" "$url" \
      -D "$M3_RAW_DIR/$kind-$DOC_ID.headers" \
      -o "$M3_RAW_DIR/$kind-$DOC_ID.bin" -w '%{http_code}')"
    m3_log "  $kind [Accept: $fallback] http=$fallback_code"
    m3_log "  $kind wariant=sprawdzony fallback z wersjonowanym nagłówkiem API"
  fi

  ctype="$(grep -i '^content-type:' "$M3_RAW_DIR/$kind-$DOC_ID.headers" | tr -d '\r' | awk '{print $2}' | tr -d ';')"
  m3_log "  $kind rozmiar=$(wc -c < "$M3_RAW_DIR/$kind-$DOC_ID.bin") sha256=$(sha256sum "$M3_RAW_DIR/$kind-$DOC_ID.bin" | cut -d' ' -f1)"
  m3_log "  $kind content-type=$ctype"
  grep -iE '^content-disposition:' "$M3_RAW_DIR/$kind-$DOC_ID.headers" \
    | tr -d '\r' | sed 's/^/    /' || true
  check "$kind osiągalny wariantem docelowym albo sprawdzonym fallbackiem" \
    "$([ "$primary_code" = "200" ] || [ "$fallback_code" = "200" ] && echo yes || echo no)"
  check "$kind ma oczekiwany typ odpowiedzi ($want_ctype)" \
    "$(case "$ctype" in "$want_ctype"*) echo yes ;; *) echo no ;; esac)"
}

cmd_search() {
  [ -n "$QUERY" ] || m3_die "$M3_EXIT_USAGE" "search wymaga --query"
  m3_section "wyszukiwanie: $QUERY"
  local code
  code="$(m3_curl --get --data-urlencode "query=\"$QUERY\"" "$M3_API/documents/" \
    -o "$M3_RAW_DIR/search.json" -w '%{http_code}')"
  check "wyszukiwanie zwróciło 200 (otrzymano $code)" "$([ "$code" = "200" ] && echo yes || echo no)"
  [ "$code" = "200" ] || return 0
  python3 - "$M3_RAW_DIR/search.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
hits = [(r["id"], round(r.get("__search_hit__", {}).get("score", 0), 4)) for r in d["results"]]
print(f"  count={d['count']} trafienia={hits}")
PY
}

cmd_checksum() {
  [ -n "$SHA" ] || m3_die "$M3_EXIT_USAGE" "checksum wymaga --sha256"
  m3_section "dokumenty o sumie $SHA"
  local ids; ids="$(m3_docs_by_checksum "$SHA")"
  m3_log "  ids=${ids:-<brak>}"
  m3_log "  liczba=$(printf '%s' "$ids" | wc -w)"
}

case "$CMD" in
  status)   cmd_status ;;
  version)  cmd_version ;;
  schema)   cmd_schema ;;
  upload)   cmd_upload ;;
  task)     cmd_task ;;
  document) cmd_document ;;
  download) cmd_download ;;
  search)   cmd_search ;;
  checksum) cmd_checksum ;;
  all)
    cmd_status; cmd_version; cmd_upload
    DOC_ID="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
r = d["results"] if isinstance(d, dict) and "results" in d else d
ids = (r[0].get("related_document_ids") or []) if r else []
print(ids[0] if ids else "")' "$M3_RAW_DIR/task.json")"
    if [ -n "$DOC_ID" ]; then cmd_document; cmd_download; else m3_log "  (brak ID dokumentu — pomijam detail i pobrania)"; fi
    ;;
esac

m3_section "podsumowanie"
m3_log "  kontroli nieudanych: $FAILURES"
m3_log "  wyniki surowe: $M3_RAW_DIR"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
