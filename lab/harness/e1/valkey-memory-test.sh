#!/usr/bin/env bash
# E1-14 — kontrolowane osiągnięcie limitu pamięci Valkey w izolowanym brokerze.
#
# Test NIGDY nie dotyka brokera ani wolumenu źródła. Uruchamia własny kontener
# Valkey z tego samego przypiętego obrazu, w osobnej sieci-nie-sieci (bez
# publikowanych portów), doprowadza go do limitu i sprawdza, czy zachowanie jest
# przewidywalne oraz czy nie ma cichej utraty danych. Po próbie kontener i jego
# wolumen są usuwane, a środowisko odtwarzane od zera.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$HERE/common.sh"

# Ten sam obraz i digest co broker źródła, ale całkowicie osobna instancja.
VALKEY_IMAGE="${VALKEY_IMAGE:-valkey/valkey:9-alpine@sha256:ee91f7a174ac4d6a6b0685b3a60e321f0a9dbbb691f9b0e285be2ba1d1be8328}"
CONTAINER="${E1_14_CONTAINER:-homeos-m3-lab-e1-14-valkey}"
VOLUME="${E1_14_VOLUME:-homeos-m3-lab-e1-14-valkey-data}"
SOURCE_VOLUME="homeos-m3-source-paperless-valkey"
MAXMEMORY="${E1_14_MAXMEMORY:-3mb}"

usage() {
  cat <<'EOF'
Użycie: ./valkey-memory-test.sh [--raw-dir KATALOG] [--maxmemory ROZMIAR]

Izolowany test limitu pamięci Valkey (E1-14). Nie używa brokera źródła.
Kody wyjścia: 0 PASS, 1 błąd, 2 błąd użycia, 4 FAIL kontroli, 5 odmowa.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --raw-dir) M3_RAW_DIR="${2:?brak wartości}"; shift 2 ;;
    --maxmemory) MAXMEMORY="${2:?brak wartości}"; shift 2 ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

m3_require_cmds docker python3
m3_mkdir "$M3_RAW_DIR"

FAILURES=0
check() { if [ "$2" = "yes" ]; then m3_log "  OK   $1"; else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); fi; }

# Twarda odmowa, gdyby ktoś podstawił nazwę wolumenu źródła.
case "$VOLUME" in
  "$SOURCE_VOLUME"|homeos-m3-source-*) m3_die "$M3_EXIT_REFUSED" \
    "odmowa: '$VOLUME' należy do projektu source" ;;
esac
case "$CONTAINER" in
  homeos-m3-source-*) m3_die "$M3_EXIT_REFUSED" \
    "odmowa: '$CONTAINER' należy do projektu source" ;;
esac

SOURCE_VOLUME_BEFORE="$(docker volume inspect "$SOURCE_VOLUME" --format '{{.CreatedAt}}' 2>/dev/null || echo '<brak>')"

cleanup() {
  local rc=$?
  trap - EXIT
  set +e
  m3_section "sprzątanie izolowanego brokera"
  docker rm -f "$CONTAINER" >/dev/null 2>&1 && m3_log "  kontener_usunięty=$CONTAINER"
  docker volume rm "$VOLUME" >/dev/null 2>&1 && m3_log "  wolumen_usunięty=$VOLUME"
  local after
  after="$(docker volume inspect "$SOURCE_VOLUME" --format '{{.CreatedAt}}' 2>/dev/null || echo '<brak>')"
  if [ "$after" = "$SOURCE_VOLUME_BEFORE" ]; then
    m3_log "  wolumen_valkey_source_nienaruszony=yes"
  else
    m3_log "  wolumen_valkey_source_nienaruszony=NIE — WYMAGANA INTERWENCJA RĘCZNA"
    rc="$M3_EXIT_ERROR"
  fi
  exit "$rc"
}
trap cleanup EXIT

vk() { docker exec "$CONTAINER" valkey-cli "$@"; }

start_broker() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker volume rm "$VOLUME" >/dev/null 2>&1 || true
  docker volume create "$VOLUME" >/dev/null
  # Bez publikowanych portów: dostęp wyłącznie przez `docker exec`.
  docker run -d --name "$CONTAINER" \
    --network none \
    -v "$VOLUME:/data" \
    "$VALKEY_IMAGE" \
    valkey-server --save "" --appendonly no >/dev/null
  for _ in $(seq 1 30); do
    vk PING 2>/dev/null | grep -q PONG && return 0
    sleep 1
  done
  return 1
}

m3_section "1. Izolowany broker z przypiętego obrazu"
start_broker || m3_die "$M3_EXIT_ERROR" "izolowany broker nie wystartował"
m3_log "  kontener=$CONTAINER"
m3_log "  obraz=$(docker inspect "$CONTAINER" --format '{{.Config.Image}}')"
m3_log "  wersja=$(vk INFO server | tr -d '\r' | sed -n 's/^valkey_version:/  valkey_version=/p')"
m3_log "  sieć=$(docker inspect "$CONTAINER" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}')"
m3_log "  porty_publikowane=$(docker port "$CONTAINER" | wc -l)"
check "izolowany broker nie publikuje portów" \
  "$([ "$(docker port "$CONTAINER" | wc -l)" -eq 0 ] && echo yes || echo no)"
check "izolowany broker nie używa wolumenu źródła" \
  "$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{.Name}} {{end}}' | grep -q "$SOURCE_VOLUME" && echo no || echo yes)"

m3_section "2. Ustawienie limitu pamięci i kontrola polityki"
vk CONFIG SET maxmemory "$MAXMEMORY" | sed 's/^/    /'
POLICY="$(vk CONFIG GET maxmemory-policy | tr -d '\r' | tail -1)"
LIMIT="$(vk CONFIG GET maxmemory | tr -d '\r' | tail -1)"
m3_log "  maxmemory=$LIMIT"
m3_log "  maxmemory-policy=$POLICY"
check "polityka domyślna to noeviction" "$([ "$POLICY" = "noeviction" ] && echo yes || echo no)"

m3_section "3. Zapis znacznika kontrolnego przed wypełnieniem"
vk SET e1-14:sentinel "wartosc-kontrolna-przed-limitem" | sed 's/^/    /'
SENTINEL_BEFORE="$(vk GET e1-14:sentinel | tr -d '\r')"
m3_log "  sentinel=$SENTINEL_BEFORE"

m3_section "4. Kontrolowane doprowadzenie do limitu"
FILL_OUT="$M3_RAW_DIR/e1-14-fill.txt"
# Zapis do pierwszego błędu; payload 64 KiB, twardy limit prób.
docker exec "$CONTAINER" sh -c '
  i=0
  payload=$(head -c 65536 /dev/zero | tr "\0" "x")
  while [ $i -lt 2000 ]; do
    out=$(valkey-cli SET e1-14:fill:$i "$payload" 2>&1)
    case "$out" in
      OK) ;;
      *) echo "PIERWSZY_BŁĄD_PRZY=$i"; echo "TREŚĆ_BŁĘDU=$out"; break ;;
    esac
    i=$((i + 1))
  done
  echo "ZAPISANYCH=$i"
' > "$FILL_OUT" 2>&1 || true
sed 's/^/    /' "$FILL_OUT"
ERROR_TEXT="$(sed -n 's/^TREŚĆ_BŁĘDU=//p' "$FILL_OUT")"
WRITTEN="$(sed -n 's/^ZAPISANYCH=//p' "$FILL_OUT")"
check "zapis został zatrzymany błędem, a nie w ciszy" \
  "$([ -n "$ERROR_TEXT" ] && echo yes || echo no)"
check "komunikat błędu wskazuje przekroczenie maxmemory" \
  "$(printf '%s' "$ERROR_TEXT" | grep -qi 'OOM\|maxmemory' && echo yes || echo no)"

m3_section "5. Brak cichej utraty danych"
USED="$(vk INFO memory | tr -d '\r' | sed -n 's/^used_memory_human://p')"
KEYS="$(vk DBSIZE | tr -d '\r')"
EVICTED="$(vk INFO stats | tr -d '\r' | sed -n 's/^evicted_keys://p')"
SENTINEL_AFTER="$(vk GET e1-14:sentinel | tr -d '\r')"
m3_log "  used_memory=$USED"
m3_log "  kluczy=$KEYS (zapisanych danych=$WRITTEN + sentinel)"
m3_log "  evicted_keys=$EVICTED"
m3_log "  sentinel_po_limicie=$SENTINEL_AFTER"
check "żaden klucz nie został wyrzucony (evicted_keys=0)" \
  "$([ "$EVICTED" = "0" ] && echo yes || echo no)"
check "znacznik kontrolny nadal ma pierwotną wartość" \
  "$([ "$SENTINEL_AFTER" = "$SENTINEL_BEFORE" ] && echo yes || echo no)"
check "liczba kluczy zgadza się z liczbą potwierdzonych zapisów" \
  "$([ "$KEYS" = "$((WRITTEN + 1))" ] && echo yes || echo no)"

m3_section "6. Odczyt po odmowie zapisu"
READBACK="$(vk GET "e1-14:fill:0" | tr -d '\r' | wc -c)"
m3_log "  rozmiar_odczytanej_wartości=$READBACK"
check "odczyt działa mimo odmowy zapisu" \
  "$([ "$READBACK" -gt 60000 ] && echo yes || echo no)"

m3_section "7. Kontrast: polityka wyrzucająca dane"
# Pokazuje, dlaczego broker kolejki nie może działać na polityce eksmisji.
vk CONFIG SET maxmemory-policy allkeys-lru | sed 's/^/    /'
docker exec "$CONTAINER" sh -c '
  payload=$(head -c 65536 /dev/zero | tr "\0" "y")
  i=0
  while [ $i -lt 50 ]; do valkey-cli SET e1-14:lru:$i "$payload" >/dev/null 2>&1; i=$((i + 1)); done
' || true
EVICTED_LRU="$(vk INFO stats | tr -d '\r' | sed -n 's/^evicted_keys://p')"
SENTINEL_LRU="$(vk GET e1-14:sentinel | tr -d '\r')"
m3_log "  evicted_keys_po_allkeys-lru=$EVICTED_LRU"
m3_log "  sentinel_po_allkeys-lru=${SENTINEL_LRU:-<usunięty>}"
check "polityka allkeys-lru rzeczywiście usuwa dane (dowód ryzyka)" \
  "$([ "${EVICTED_LRU:-0}" -gt 0 ] && echo yes || echo no)"
vk CONFIG SET maxmemory-policy noeviction >/dev/null

m3_section "8. Odtworzenie środowiska od zera"
start_broker || m3_die "$M3_EXIT_ERROR" "nie udało się odtworzyć izolowanego brokera"
FRESH_KEYS="$(vk DBSIZE | tr -d '\r')"
FRESH_LIMIT="$(vk CONFIG GET maxmemory | tr -d '\r' | tail -1)"
m3_log "  kluczy_po_odtworzeniu=$FRESH_KEYS"
m3_log "  maxmemory_po_odtworzeniu=$FRESH_LIMIT"
check "odtworzony broker jest pusty" "$([ "$FRESH_KEYS" = "0" ] && echo yes || echo no)"
check "odtworzony broker nie ma limitu z próby" "$([ "$FRESH_LIMIT" = "0" ] && echo yes || echo no)"

m3_section "9. Broker źródła nietknięty"
SOURCE_KEYS="$(docker exec "${M3_PROJECT}-broker-1" valkey-cli DBSIZE 2>/dev/null | tr -d '\r' || echo '?')"
SOURCE_LIMIT="$(docker exec "${M3_PROJECT}-broker-1" valkey-cli CONFIG GET maxmemory 2>/dev/null | tr -d '\r' | tail -1 || echo '?')"
m3_log "  broker_source_kluczy=$SOURCE_KEYS"
m3_log "  broker_source_maxmemory=$SOURCE_LIMIT"
check "broker źródła nie ma narzuconego limitu" \
  "$([ "$SOURCE_LIMIT" = "0" ] && echo yes || echo no)"

{
  echo "maxmemory=$LIMIT"
  echo "maxmemory_policy=$POLICY"
  echo "zapisanych_kluczy=$WRITTEN"
  echo "blad=$ERROR_TEXT"
  echo "evicted_noeviction=$EVICTED"
  echo "evicted_allkeys_lru=$EVICTED_LRU"
  echo "used_memory=$USED"
} > "$M3_RAW_DIR/e1-14-summary.txt"

m3_section "Podsumowanie E1-14"
m3_log "  kontroli nieudanych: $FAILURES"
m3_log "  wyniki: $M3_RAW_DIR"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
