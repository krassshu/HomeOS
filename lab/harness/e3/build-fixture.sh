#!/usr/bin/env bash
# Etap 4 — fixture Core i manifest źródłowy przed backupem.
#
# Uzupełnia laboratoryjną bazę `core_fixture`:
#   - `document_link(external_id, checksum_sha256)` wskazujące dokumenty z E1,
#   - `asset(path, checksum_sha256)` oraz syntetyczne pliki assetów,
# a następnie zapisuje manifest liczników i checksum.
#
# To nie jest projekt modelu produkcyjnego. Manifest celowo NIE zawiera tytułów
# ani treści dokumentów — wyłącznie identyfikatory i sumy kontrolne.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common-e3.sh
source "${HERE}/common-e3.sh"

CORE_DB="${M3_PROJECT}-core_fixture_db-1"
ASSET_DIR="/srv/core-assets"
MANIFEST_DIR="${E3_MANIFEST_DIR:-${E3_ROOT}/manifest}"

usage() {
  cat <<'EOF'
Użycie: ./build-fixture.sh [--assets N] [--manifest-dir KATALOG]

Tworzy powiązania fixture Core z dokumentami Paperless, syntetyczne assety
i manifest źródłowy. Nie usuwa dokumentów Paperless.
EOF
}

ASSET_COUNT=3
while [ $# -gt 0 ]; do
  case "$1" in
    --assets) ASSET_COUNT="${2:?brak wartości}"; shift 2 ;;
    --manifest-dir) MANIFEST_DIR="${2:?brak wartości}"; shift 2 ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done
[ "$ASSET_COUNT" -ge 2 ] || m3_die "$M3_EXIT_USAGE" "wymagane co najmniej dwa assety"

m3_require_cmds docker python3 sha256sum
m3_require_project
# Manifest i pliki pośrednie zawierają checksumy dokumentów — tylko dla właściciela.
umask 077
install -d -m 700 "$MANIFEST_DIR"

FAILURES=0
check() { if [ "$2" = "yes" ]; then m3_log "  OK   $1"; else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); fi; }

psql_core() { docker exec -i "$CORE_DB" psql -U core_fixture -d core_fixture -v ON_ERROR_STOP=1 "$@"; }

trap m3_token_cleanup EXIT
m3_token_init

m3_section "1. Stan Paperless przed budową fixture"
DOCS="$(m3_doc_count)"
TRASH="$(m3_curl "$M3_API/trash/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
TAGS="$(m3_curl "$M3_API/tags/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
CORRESPONDENTS="$(m3_curl "$M3_API/correspondents/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
DOCTYPES="$(m3_curl "$M3_API/document_types/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
m3_log "  dokumentów=$DOCS kosz=$TRASH tagów=$TAGS korespondentów=$CORRESPONDENTS typów=$DOCTYPES"
[ "$DOCS" -gt 0 ] || m3_die "$M3_EXIT_PRECONDITION" "brak dokumentów — fixture nie miałby czego wskazywać"

m3_section "2. Identyfikatory i sumy kontrolne dokumentów"
m3_curl "$M3_API/documents/?page_size=1000&ordering=id" -o "${MANIFEST_DIR}/.documents.json"
DOC_IDS="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(" ".join(str(r["id"]) for r in d["results"]))' "${MANIFEST_DIR}/.documents.json")"
m3_log "  ID dokumentów: $DOC_IDS"

: > "${MANIFEST_DIR}/.doc-checksums.tsv"
for id in $DOC_IDS; do
  m3_curl "$M3_API/documents/$id/metadata/" -o "${MANIFEST_DIR}/.meta-$id.json"
  checksum="$(python3 -c '
import json, sys
print(json.load(open(sys.argv[1])).get("original_checksum") or "")' "${MANIFEST_DIR}/.meta-$id.json")"
  size="$(python3 -c '
import json, sys
print(json.load(open(sys.argv[1])).get("original_size") or 0)' "${MANIFEST_DIR}/.meta-$id.json")"
  [ -n "$checksum" ] || m3_die "$M3_EXIT_FAIL" "dokument $id nie ma original_checksum"
  printf 'paperless:%s\t%s\t%s\t%s\n' "$id" "$id" "$checksum" "$size" >> "${MANIFEST_DIR}/.doc-checksums.tsv"
  rm -f "${MANIFEST_DIR}/.meta-$id.json"
done
m3_log "  zebrano sum kontrolnych: $(wc -l < "${MANIFEST_DIR}/.doc-checksums.tsv")"
BAD_SUM="$(awk -F'\t' '$3 !~ /^[0-9a-f]{64}$/' "${MANIFEST_DIR}/.doc-checksums.tsv" | wc -l)"
check "wszystkie sumy dokumentów są SHA-256" "$([ "$BAD_SUM" -eq 0 ] && echo yes || echo no)"

m3_section "3. Powiązania document_link"
# Idempotentnie: ponowne uruchomienie aktualizuje sumę, nie mnoży wierszy.
while IFS=$'\t' read -r external_id doc_id checksum size; do
  printf "INSERT INTO document_link (external_id, checksum_sha256) VALUES ('%s', '%s')
          ON CONFLICT (external_id) DO UPDATE SET checksum_sha256 = EXCLUDED.checksum_sha256;\n" \
    "$external_id" "$checksum"
done < "${MANIFEST_DIR}/.doc-checksums.tsv" | psql_core -q
LINK_COUNT="$(psql_core -tAc 'SELECT count(*) FROM document_link;')"
m3_log "  wierszy document_link=$LINK_COUNT"
check "liczba powiązań odpowiada liczbie dokumentów" \
  "$([ "$LINK_COUNT" = "$DOCS" ] && echo yes || echo no)"

m3_section "4. Syntetyczne assety Core"
# Assety są deterministyczne, żeby manifest dało się odtworzyć.
docker exec "$CORE_DB" sh -c "install -d -m 700 $ASSET_DIR"
for i in $(seq 1 "$ASSET_COUNT"); do
  name="asset-$(printf '%02d' "$i").txt"
  docker exec "$CORE_DB" sh -c "cat > $ASSET_DIR/$name <<'EOF'
HomeOS M3 — syntetyczny asset laboratoryjny nr $i
Materiał testowy fixture Core. Nie zawiera danych osobowych.
Zażółć gęślą jaźń — kontrola kodowania UTF-8.
identyfikator=asset-$(printf '%02d' "$i")
EOF
chmod 600 $ASSET_DIR/$name"
done
docker exec "$CORE_DB" sh -c "cd $ASSET_DIR && sha256sum *.txt" > "${MANIFEST_DIR}/.asset-checksums.txt"
sed 's/^/    /' "${MANIFEST_DIR}/.asset-checksums.txt"

while read -r checksum name; do
  printf "INSERT INTO asset (path, checksum_sha256) VALUES ('%s/%s', '%s')
          ON CONFLICT (path) DO UPDATE SET checksum_sha256 = EXCLUDED.checksum_sha256;\n" \
    "$ASSET_DIR" "$name" "$checksum"
done < "${MANIFEST_DIR}/.asset-checksums.txt" | psql_core -q
ASSET_ROWS="$(psql_core -tAc 'SELECT count(*) FROM asset;')"
m3_log "  wierszy asset=$ASSET_ROWS"
check "liczba wierszy asset odpowiada liczbie plików" \
  "$([ "$ASSET_ROWS" = "$ASSET_COUNT" ] && echo yes || echo no)"
check "utworzono co najmniej dwa assety" \
  "$([ "$ASSET_ROWS" -ge 2 ] && echo yes || echo no)"

m3_section "5. Manifest źródłowy"
WEB_DIGEST="$(docker image inspect "$(docker inspect "$M3_WEBSERVER" --format '{{.Image}}')" \
  --format '{{range .RepoDigests}}{{.}}{{end}}')"
PNGX_VERSION="$(m3_curl "$M3_API/status/" | python3 -c 'import json,sys; print(json.load(sys.stdin)["pngx_version"])')"

python3 - "$MANIFEST_DIR" "$PNGX_VERSION" "$WEB_DIGEST" "$DOCS" "$TRASH" "$TAGS" \
  "$CORRESPONDENTS" "$DOCTYPES" "$ASSET_DIR" > "${MANIFEST_DIR}/source-manifest.json" <<'PY'
import hashlib, json, os, sys

(manifest_dir, version, digest, docs, trash, tags,
 correspondents, doctypes, asset_dir) = sys.argv[1:10]

documents = []
with open(os.path.join(manifest_dir, ".doc-checksums.tsv"), encoding="utf-8") as fh:
    for line in fh:
        external_id, doc_id, checksum, size = line.rstrip("\n").split("\t")
        # Świadomie bez tytułu i treści: manifest opisuje tożsamość, nie zawartość.
        documents.append({
            "external_id": external_id,
            "paperless_id": int(doc_id),
            "original_checksum_sha256": checksum,
            "original_size_bytes": int(size),
        })

assets = []
with open(os.path.join(manifest_dir, ".asset-checksums.txt"), encoding="utf-8") as fh:
    for line in fh:
        checksum, name = line.split()
        assets.append({"path": f"{asset_dir}/{name}", "checksum_sha256": checksum})

manifest = {
    "opis": "Manifest źródłowy M3 przed backupem E3. Materiał laboratoryjny.",
    "paperless": {"wersja": version, "digest_obrazu": digest},
    "liczniki": {
        "dokumenty_aktywne": int(docs),
        "kosz": int(trash),
        "tagi": int(tags),
        "korespondenci": int(correspondents),
        "typy_dokumentow": int(doctypes),
        "powiazania_document_link": len(documents),
        "assety": len(assets),
    },
    "dokumenty": documents,
    "assety": assets,
}
print(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True))
PY

MANIFEST_SHA="$(sha256sum "${MANIFEST_DIR}/source-manifest.json" | cut -d' ' -f1)"
printf '%s  source-manifest.json\n' "$MANIFEST_SHA" > "${MANIFEST_DIR}/source-manifest.sha256"

{
  echo "# Manifest źródłowy M3 — podsumowanie"
  echo "paperless_wersja=$PNGX_VERSION"
  echo "paperless_digest=$WEB_DIGEST"
  echo "dokumenty_aktywne=$DOCS"
  echo "kosz=$TRASH"
  echo "tagi=$TAGS"
  echo "korespondenci=$CORRESPONDENTS"
  echo "typy_dokumentow=$DOCTYPES"
  echo "powiazania_document_link=$LINK_COUNT"
  echo "assety=$ASSET_ROWS"
  echo "# Checksum samego manifestu (pliku source-manifest.json):"
  echo "manifest_sha256=$MANIFEST_SHA"
} > "${MANIFEST_DIR}/source-manifest.txt"
chmod 600 "${MANIFEST_DIR}"/source-manifest.*

m3_log "  manifest=${MANIFEST_DIR}/source-manifest.json"
m3_log "  manifest_sha256=$MANIFEST_SHA"
m3_log "  dokumentów w manifeście=$(python3 -c '
import json,sys; print(len(json.load(open(sys.argv[1]))["dokumenty"]))' "${MANIFEST_DIR}/source-manifest.json")"

check "manifest zawiera wersję i digest Paperless" \
  "$(python3 -c '
import json,sys
m=json.load(open(sys.argv[1]))
print("yes" if m["paperless"]["wersja"] and m["paperless"]["digest_obrazu"] else "no")' "${MANIFEST_DIR}/source-manifest.json")"
check "manifest nie zawiera tytułów ani treści dokumentów" \
  "$(grep -qiE '"(title|content|tytul)"' "${MANIFEST_DIR}/source-manifest.json" && echo no || echo yes)"
check "checksum manifestu zapisany" \
  "$([ -s "${MANIFEST_DIR}/source-manifest.sha256" ] && echo yes || echo no)"

rm -f "${MANIFEST_DIR}/.documents.json"

m3_section "6. Weryfikacja fixture względem Paperless"
MISMATCH="$(psql_core -tAc "SELECT count(*) FROM document_link" )"
m3_log "  document_link=$MISMATCH asset=$ASSET_ROWS"
psql_core -c "SELECT external_id, left(checksum_sha256, 12) || '…' AS checksum FROM document_link ORDER BY external_id;" \
  | sed 's/^/    /'

m3_section "Podsumowanie etapu 4"
m3_log "  kontroli nieudanych: $FAILURES"
m3_log "  manifest: ${MANIFEST_DIR}"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
