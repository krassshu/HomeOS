#!/usr/bin/env bash
# Walidacja wyników E1: poprawność surowych artefaktów, spójność pomiarów
# i kontrola, czy do wyników nie trafił sekret.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$HERE/common.sh"

usage() {
  cat <<'EOF'
Użycie: ./validate-results.sh [opcje]

Kontrole:
  json     — każdy plik .json w katalogu wyników parsuje się poprawnie
  tasks    — każdy zapisany rekord zadania ma stan końcowy i znane pola
  secrets  — w wynikach nie ma nagłówka Authorization z wartością, znanego
             tokenu z PAPERLESS_API_TOKEN, hasła ani adresu e-mail
  csv      — plik pomiarów: nagłówek, delta = after - before, mnożniki do
             sześciu miejsc po przecinku

Opcje:
  --raw-dir KATALOG   katalog wyników surowych (domyślnie $M3_RAW_DIR)
  --csv PLIK          plik pomiarów do walidacji (opcjonalny)
  --only KONTROLE     lista rozdzielona przecinkami (domyślnie wszystkie
                      dostępne dla podanych danych wejściowych)
  -h, --help          ta pomoc

Kody wyjścia: 0 wszystko przeszło, 2 błąd użycia, 3 brak danych wejściowych,
4 walidacja nie przeszła.
EOF
}

CSV_FILE=""
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --raw-dir) M3_RAW_DIR="${2:?brak wartości dla --raw-dir}"; shift 2 ;;
    --csv) CSV_FILE="${2:?brak wartości dla --csv}"; shift 2 ;;
    --only) ONLY="${2:?brak wartości dla --only}"; shift 2 ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

m3_require_cmds python3

if [ -n "$ONLY" ]; then
  IFS=',' read -r -a REQUESTED <<< "$ONLY"
  for requested in "${REQUESTED[@]}"; do
    case "$requested" in json|tasks|secrets|csv) ;; *)
      m3_die "$M3_EXIT_USAGE" "nieznana kontrola w --only: $requested"
    esac
  done
fi

wants() { # wants <nazwa>
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

FAILURES=0
check() { if [ "$2" = "yes" ]; then m3_log "  OK   $1"; else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); fi; }

if [ ! -d "$M3_RAW_DIR" ] && [ -z "$CSV_FILE" ]; then
  m3_die "$M3_EXIT_PRECONDITION" "brak katalogu wyników '$M3_RAW_DIR' i nie podano --csv"
fi

if [ -d "$M3_RAW_DIR" ] && wants json; then
  m3_section "poprawność JSON"
  JSON_OUT="$(python3 - "$M3_RAW_DIR" <<'PY'
import json, pathlib, sys

total = empty = bad = 0
for path in sorted(pathlib.Path(sys.argv[1]).rglob("*.json")):
    total += 1
    raw = path.read_bytes()
    if not raw.strip():
        # Pusta odpowiedź jest legalna, np. ciało przekierowania 302.
        empty += 1
        print(f"    {path.name}: pusty (pomijam)")
        continue
    try:
        json.loads(raw.decode("utf-8"))
    except Exception as exc:
        bad += 1
        print(f"    {path.name}: {type(exc).__name__}: {exc}")
print(f"__TOTAL__={total} __EMPTY__={empty} __BAD__={bad}")
PY
)"
  printf '%s\n' "$JSON_OUT" | grep -v '^__TOTAL__' || true
  m3_log "  $(printf '%s\n' "$JSON_OUT" | sed -n 's/^__TOTAL__=\([0-9]*\) __EMPTY__=\([0-9]*\) __BAD__=\([0-9]*\)/plików: \1, pustych: \2, niepoprawnych: \3/p')"
  JSON_BAD="$(printf '%s\n' "$JSON_OUT" | sed -n 's/.*__BAD__=\([0-9]*\)/\1/p')"
  JSON_TOTAL="$(printf '%s\n' "$JSON_OUT" | sed -n 's/^__TOTAL__=\([0-9]*\).*/\1/p')"
  check "znaleziono co najmniej jeden plik JSON" \
    "$([ "${JSON_TOTAL:-0}" -gt 0 ] && echo yes || echo no)"
  check "wszystkie niepuste pliki JSON parsują się poprawnie" \
    "$([ "${JSON_BAD:-1}" = "0" ] && echo yes || echo no)"
fi

if [ -d "$M3_RAW_DIR" ] && wants tasks; then
  m3_section "rekordy zadań"
  TASK_OUT="$(python3 - "$M3_RAW_DIR" <<'PY'
import json, pathlib, sys

NONTERMINAL = {"pending", "started", "received", "retry", "queued",
               "PENDING", "STARTED", "RECEIVED", "RETRY", "QUEUED"}


def expected_nonterminal(path):
    """Stan nieterminalny bywa dowodem, a nie usterką.

    Akceptujemy go wyłącznie wtedy, gdy katalog zawiera plik
    EXPECTED-NONTERMINAL.txt wymieniający nazwę tego pliku. Dzięki temu
    świadomie zachowany dowód nie psuje walidacji, a przypadkowy rekord
    w stanie nieterminalnym nadal ją zatrzymuje.
    """
    marker = path.parent / "EXPECTED-NONTERMINAL.txt"
    if not marker.exists():
        return False
    return path.name in marker.read_text(encoding="utf-8")


found = problems = 0
for path in sorted(pathlib.Path(sys.argv[1]).rglob("*task*.json")):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        continue
    records = data if isinstance(data, list) else (data.get("results") or [])
    if not records or "status" not in records[0]:
        continue
    found += 1
    task = records[0]
    status = task["status"]
    marks = []
    if status in NONTERMINAL and not expected_nonterminal(path):
        marks.append(f"stan nieterminalny: {status}")
    result = task.get("result_data") or {}
    has_link = bool(task.get("related_document_ids") or task.get("related_document")
                    or result.get("duplicate_of") or result.get("document_id"))
    normalized = str(status).lower()
    if normalized == "success" and not has_link:
        marks.append("sukces bez powiązania z dokumentem")
    if normalized == "failure":
        if isinstance(result, dict) and isinstance(result.get("duplicate_of"), int):
            related = task.get("related_document_ids") or []
            if result["duplicate_of"] not in related:
                marks.append("duplicate_of nie zgadza się z related_document_ids")
            if not isinstance(result.get("duplicate_in_trash"), bool):
                marks.append("brak bool duplicate_in_trash")
        elif isinstance(result, dict) and result.get("error_type"):
            if "error_message" not in result:
                marks.append("błąd bez error_message")
        elif not (task.get("duplicate_documents") or task.get("result")):
            marks.append("failure bez rozpoznawalnego wyniku")
    if marks:
        problems += 1
        print(f"    {path.name}: " + "; ".join(marks))
    else:
        print(f"    {path.name}: status={status} ok")
print(f"__PROBLEMS__={problems} __FOUND__={found}")
PY
)"
  printf '%s\n' "$TASK_OUT" | grep -v '^__PROBLEMS__' || true
  TASK_PROBLEMS="$(printf '%s\n' "$TASK_OUT" | sed -n 's/^__PROBLEMS__=\([0-9]*\).*/\1/p')"
  TASK_FOUND="$(printf '%s\n' "$TASK_OUT" | sed -n 's/.*__FOUND__=\([0-9]*\)/\1/p')"
  check "znaleziono co najmniej jeden rekord zadania" \
    "$([ "${TASK_FOUND:-0}" -gt 0 ] && echo yes || echo no)"
  check "każdy zapisany rekord zadania ma stan końcowy i spójne powiązanie" \
    "$([ "${TASK_PROBLEMS:-0}" = "0" ] && echo yes || echo no)"
fi

if [ -d "$M3_RAW_DIR" ] && wants secrets; then
  m3_section "skan sekretów w wynikach"
  SECRET_OUT="$(python3 - "$M3_RAW_DIR" <<'PY'
import os, pathlib, re, sys

# Szukamy wartości sekretu w artefaktach tekstowych, nie samej nazwy nagłówka: literał
# "Authorization: Token" bez wartości występuje legalnie w schemacie OpenAPI
# i w kodzie skryptów pobierających token.
PATTERNS = [
    # Wartość musi być alfanumeryczna: interpolacja w rodzaju
    # "Authorization: Token '+zmienna" nie jest sekretem.
    ("nagłówek Authorization z wartością", re.compile(rb"Authorization:\s*Token\s+[A-Za-z0-9]{16,}")),
    # Jawny znacznik redakcji nie jest sekretem: zapisuje tylko długość usuniętej wartości.
    ("hasło w postaci klucz=wartość",
     re.compile(rb"(?i)(password|passwd|secret_key)\s*[=:]\s*(?!<zredagowano:)\S{8,}")),
    ("adres e-mail", re.compile(
        rb"[A-Za-z0-9._%+-]+@(?!example\.(com|org|net)|localhost)[A-Za-z0-9.-]+\.[A-Za-z]{2,}")),
]
known_token = os.environ.get("PAPERLESS_API_TOKEN", "").encode()
if len(known_token) >= 16:
    PATTERNS.append(("wartość PAPERLESS_API_TOKEN", re.compile(re.escape(known_token))))
hits = 0
for path in sorted(pathlib.Path(sys.argv[1]).rglob("*")):
    if not path.is_file():
        continue
    raw = path.read_bytes()
    if b"\x00" in raw[:8192]:
        continue
    for label, pattern in PATTERNS:
        match = pattern.search(raw)
        if match:
            hits += 1
            print(f"    {path.name}: {label}")
            break
print(f"__HITS__={hits}")
PY
)"
  printf '%s\n' "$SECRET_OUT" | grep -v '^__HITS__' || true
  SECRET_HITS="$(printf '%s\n' "$SECRET_OUT" | sed -n 's/^__HITS__=\([0-9]*\)/\1/p')"
  check "brak nagłówka z tokenem, znanego tokenu, hasła i adresu e-mail w wynikach" \
    "$([ "${SECRET_HITS:-1}" = "0" ] && echo yes || echo no)"
fi

if [ -n "$CSV_FILE" ] && wants csv; then
  m3_section "pomiary: $CSV_FILE"
  [ -r "$CSV_FILE" ] || m3_die "$M3_EXIT_PRECONDITION" "plik pomiarów nieczytelny: $CSV_FILE"
  CSV_OK="$(python3 - "$CSV_FILE" <<'PY'
import csv, sys
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

problems = []
with open(sys.argv[1], newline="", encoding="utf-8") as fh:
    reader = csv.DictReader(fh)
    expected_header = [
        "test_id", "metric", "component", "before_bytes", "after_bytes",
        "delta_bytes", "input_bytes", "multiplier", "unit", "notes",
    ]
    if reader.fieldnames != expected_header:
        problems.append(
            "nagłówek niezgodny: " + ",".join(reader.fieldnames or [])
        )
    rows = list(reader)
if not rows:
    problems.append("brak wierszy danych")
width = len(expected_header)
for index, row in enumerate(rows, start=2):
    if len(row) != width or any(k is None for k in row):
        problems.append(f"wiersz {index}: niespójna liczba kolumn")

def number(row, *names):
    for name in names:
        value = (row.get(name) or "").strip()
        if value not in ("", "n/a"):
            try:
                return Decimal(value.replace(",", "."))
            except InvalidOperation:
                return None
    return None

checked_delta = checked_ratio = 0
for index, row in enumerate(rows, start=2):
    before = number(row, "before_bytes", "bytes_before", "before")
    after = number(row, "after_bytes", "bytes_after", "after")
    delta = number(row, "delta_bytes", "bytes_delta", "delta")
    if None not in (before, after, delta):
        checked_delta += 1
        if (after - before) != delta:
            problems.append(f"wiersz {index}: delta {delta} != after-before {after-before}")
    ratio = number(row, "multiplier", "ratio_to_input", "mnoznik")
    base = number(row, "input_bytes", "input_size")
    if None not in (ratio, base, delta) and base:
        checked_ratio += 1
        expected = (delta / base).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)
        if ratio.quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP) != expected:
            problems.append(f"wiersz {index}: mnożnik {ratio} != {expected}")
    if ratio is not None:
        text = (row.get("multiplier") or row.get("ratio_to_input") or "").strip().replace(",", ".")
        if "." in text and len(text.split(".")[1]) > 6:
            problems.append(f"wiersz {index}: mnożnik ma więcej niż sześć miejsc: {text}")
print(f"    sprawdzonych delt: {checked_delta}, sprawdzonych mnożników: {checked_ratio}",
      file=sys.stderr)

for problem in problems:
    print("    " + problem, file=sys.stderr)
print("yes" if not problems else "no")
PY
)"
  m3_log "  wierszy danych: $(($(wc -l < "$CSV_FILE") - 1))"
  check "CSV parsuje się i jest spójny (delta, mnożniki do sześciu miejsc)" "$CSV_OK"
fi

m3_section "podsumowanie"
m3_log "  kontroli nieudanych: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
