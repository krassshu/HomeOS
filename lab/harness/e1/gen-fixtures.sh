#!/usr/bin/env bash
# Uruchamia generator syntetycznych fixture wewnątrz kontenera Paperless
# i kopiuje wynik do katalogu na hoście. Domyślnie odmawia nadpisania plików.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$HERE/common.sh"

usage() {
  cat <<'EOF'
Użycie: ./gen-fixtures.sh [opcje]

Generuje syntetyczne fixture E1 w kontenerze Paperless i kopiuje je na host.
Fixture są plikami binarnymi — nie umieszczaj ich w Git.

Opcje:
  -o, --out KATALOG   katalog docelowy na hoście (domyślnie $M3_FIXTURE_DIR
                      lub ./fixtures)
      --only GRUPY    raster,text,duplicate,corrupted (domyślnie wszystkie)
      --overwrite     zezwól na nadpisanie fixture o tych samych nazwach
  -h, --help          ta pomoc

Zmienne środowiskowe:
  M3_PROJECT          projekt Compose (domyślnie homeos-m3-source)
  M3_WEBSERVER        nazwa kontenera webservera
  M3_FIXTURE_DIR      domyślny katalog docelowy

Kody wyjścia: 0 OK, 2 błąd użycia, 3 niespełniony warunek wstępny.
EOF
}

OUT_DIR="${M3_FIXTURE_DIR:-./fixtures}"
ONLY=""
OVERWRITE=0

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--out) OUT_DIR="${2:?brak wartości dla --out}"; shift 2 ;;
    --only)   ONLY="${2:?brak wartości dla --only}"; shift 2 ;;
    --overwrite) OVERWRITE=1; shift ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

m3_require_cmds docker install find sort sha256sum
m3_require_project

CONTAINER_DIR="/tmp/m3-fixtures-$$-$RANDOM"
m3_mkdir "$OUT_DIR"

cleanup() {
  docker exec "$M3_WEBSERVER" rm -f /tmp/gen-fixtures.py >/dev/null 2>&1 || true
  case "$CONTAINER_DIR" in
    /tmp/m3-fixtures-[0-9]*-[0-9]*) docker exec "$M3_WEBSERVER" rm -rf "$CONTAINER_DIR" >/dev/null 2>&1 || true ;;
  esac
}
trap cleanup EXIT

m3_section "generowanie w kontenerze $M3_WEBSERVER"
docker cp "$HERE/gen-fixtures.py" "$M3_WEBSERVER:/tmp/gen-fixtures.py"
ARGS=("$CONTAINER_DIR")
[ -n "$ONLY" ] && ARGS+=(--only "$ONLY")
docker exec "$M3_WEBSERVER" python3 /tmp/gen-fixtures.py "${ARGS[@]}"

m3_section "kopiowanie na host: $OUT_DIR"
mapfile -t GENERATED < <(
  docker exec "$M3_WEBSERVER" find "$CONTAINER_DIR" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | sort
)
[ "${#GENERATED[@]}" -gt 0 ] || m3_die "$M3_EXIT_FAIL" "generator nie utworzył żadnego pliku"
if [ "$OVERWRITE" -ne 1 ]; then
  for name in "${GENERATED[@]}"; do
    [ ! -e "$OUT_DIR/$name" ] || m3_die "$M3_EXIT_REFUSED" \
      "odmowa nadpisania istniejącego pliku: $OUT_DIR/$name (użyj --overwrite świadomie)"
  done
fi
for name in "${GENERATED[@]}"; do
  docker cp "$M3_WEBSERVER:$CONTAINER_DIR/$name" "$OUT_DIR/$name"
  chmod 600 "$OUT_DIR/$name"
done

m3_section "sumy kontrolne na hoście"
for name in "${GENERATED[@]}"; do
  sha256sum "$OUT_DIR/$name"
done

m3_log ""
m3_log "Gotowe. Fixture są syntetyczne, ale pozostają poza Git (katalog wyników jest ignorowany)."
