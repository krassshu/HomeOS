#!/usr/bin/env bash
# Etap 8 — obowiązkowe próby narzędzi backupowych dla Restic i Borg.
#
# Obejmuje: restore pojedynczego pliku, otwarcie repozytorium drugą kopią
# materiału odzyskiwania, czysty pomiar czasu i rozmiaru, retencję w dry-run,
# rzeczywistą retencję z prune WYŁĄCZNIE na jednorazowej kopii repozytorium,
# kontrolę integralności po retencji oraz jakość diagnostyki.
#
# Prune nigdy nie dotyka podstawowych repozytoriów wynikowych eksperymentu.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common-e3.sh
source "${HERE}/common-e3.sh"

SIZING_DIR="${E3_ROOT}/sizing"
SINGLE_FILE_DIR="${E3_ROOT}/single-file-restore"

usage() {
  cat <<'EOF'
Użycie: ./tool-trials.sh [--candidates "restic borg"]

Wymaga istniejącego zestawu DR (uruchom wcześniej e3b.sh).
Kody wyjścia: 0 PASS, 1 błąd, 2 użycie, 3 warunek wstępny, 4 FAIL.
EOF
}

CANDIDATES="restic borg"
while [ $# -gt 0 ]; do
  case "$1" in
    --candidates) CANDIDATES="${2:?brak wartości}"; shift 2 ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

m3_require_cmds python3 sha256sum cmp realpath
e3_require_tools
e3_require_recovery_material
[ -s "${E3_DR_DIR}/CHECKSUMS.sha256" ] || m3_die "$M3_EXIT_PRECONDITION" \
  "brak zestawu DR — uruchom najpierw e3b.sh"
install -d -m 700 "$E3_RESULTS" "$SIZING_DIR" "$SINGLE_FILE_DIR" "$E3_RETENTION_COPIES"

FAILURES=0
check() { if [ "$2" = "yes" ]; then m3_log "  OK   $1"; else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); fi; }

# Plik kontrolny do restore pojedynczego pliku — mały i o znanej sumie.
SINGLE_REL="meta/tool-versions.txt"
SINGLE_SRC="${E3_DR_DIR}/${SINGLE_REL}"
SINGLE_SHA="$(sha256sum "$SINGLE_SRC" | cut -d' ' -f1)"

run_restic_trials() {
  local repo="${SIZING_DIR}/restic"
  local pass="$E3_RESTIC_PASSWORD_A"
  local manual_steps=0
  m3_section "=== Restic ==="

  # --- czysty pomiar czasu i rozmiaru ------------------------------------
  e3_recreate_dir "$repo"
  e3_restic_repo "$repo" "$pass" init >/dev/null 2>&1
  local t0 t1 backup_s
  t0="$(date +%s%N)"
  e3_restic_repo "$repo" "$pass" backup "$E3_DR_DIR" --tag sizing \
    > "${E3_RESULTS}/trials-restic-backup.log" 2>&1
  t1="$(date +%s%N)"
  backup_s="$(python3 -c "print(round(($t1-$t0)/1e9, 2))")"
  local repo_bytes; repo_bytes="$(e3_bytes "$repo")"
  local source_bytes; source_bytes="$(e3_bytes "$E3_DR_DIR")"
  m3_log "  czas_backupu=${backup_s}s"
  m3_log "  rozmiar_źródła=${source_bytes} B"
  m3_log "  rozmiar_repozytorium=${repo_bytes} B"

  # --- pełny restore -------------------------------------------------------
  local full="${SIZING_DIR}/restic-full-restore"
  e3_recreate_dir "$full"
  t0="$(date +%s%N)"
  e3_restic_repo "$repo" "$pass" restore latest --target "$full" \
    > "${E3_RESULTS}/trials-restic-restore.log" 2>&1
  t1="$(date +%s%N)"
  local restore_s; restore_s="$(python3 -c "print(round(($t1-$t0)/1e9, 2))")"
  m3_log "  czas_pełnego_restore=${restore_s}s"
  local restored_root; restored_root="$(dirname "$(find "$full" -name CHECKSUMS.sha256 | head -1)")"
  check "restic: pełny restore odtworzył zestaw" \
    "$([ -n "$restored_root" ] && echo yes || echo no)"

  # --- restore pojedynczego pliku -----------------------------------------
  local one="${SINGLE_FILE_DIR}/restic"
  e3_recreate_dir "$one"
  e3_restic_repo "$repo" "$pass" restore latest --target "$one" \
    --include "${E3_DR_DIR}/${SINGLE_REL}" \
    > "${E3_RESULTS}/trials-restic-single.log" 2>&1
  local one_file; one_file="$(find "$one" -type f -name "$(basename "$SINGLE_REL")" | head -1)"
  local one_count; one_count="$(find "$one" -type f | wc -l)"
  m3_log "  plików odtworzonych przy restore pojedynczego pliku=${one_count}"
  check "restic: restore pojedynczego pliku zwrócił dokładnie ten plik" \
    "$([ "$one_count" -eq 1 ] && echo yes || echo no)"
  check "restic: odtworzony pojedynczy plik ma zgodną sumę" \
    "$([ -n "$one_file" ] && [ "$(sha256sum "$one_file" | cut -d' ' -f1)" = "$SINGLE_SHA" ] && echo yes || echo no)"

  # --- otwarcie drugą kopią hasła -----------------------------------------
  local snaps_b
  snaps_b="$(e3_restic_repo "$repo" "$E3_RESTIC_PASSWORD_B" snapshots --json 2>/dev/null \
    | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
  m3_log "  snapshotów widocznych z kopii B hasła=${snaps_b}"
  check "restic: repozytorium otwiera się drugą kopią hasła" \
    "$([ "$snaps_b" -ge 1 ] && echo yes || echo no)"

  # --- jakość diagnostyki przy złym haśle ---------------------------------
  local wrong; wrong="$(mktemp)"; chmod 600 "$wrong"; printf 'nieprawidlowe-haslo' > "$wrong"
  set +e
  e3_restic_repo "$repo" "$wrong" snapshots > "${E3_RESULTS}/trials-restic-wrongpass.log" 2>&1
  local wrong_rc=$?
  set -e
  rm -f "$wrong"
  m3_log "  kod przy złym haśle=${wrong_rc}"
  m3_log "  komunikat: $(head -1 "${E3_RESULTS}/trials-restic-wrongpass.log")"
  check "restic: złe hasło daje niezerowy kod i czytelny komunikat" \
    "$([ "$wrong_rc" -ne 0 ] && grep -qi 'wrong password\|invalid\|unable' "${E3_RESULTS}/trials-restic-wrongpass.log" && echo yes || echo no)"

  # --- retencja: dry-run, potem prune na jednorazowej kopii ---------------
  # Kilka snapshotów, żeby retencja miała co usuwać.
  for i in 1 2; do
    printf 'wersja %s\n' "$i" > "${E3_DR_DIR}/meta/.retention-marker"
    e3_restic_repo "$repo" "$pass" backup "$E3_DR_DIR" --tag "sizing-$i" >/dev/null 2>&1
  done
  rm -f "${E3_DR_DIR}/meta/.retention-marker"
  local before_snaps
  before_snaps="$(e3_restic_repo "$repo" "$pass" snapshots --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  m3_log "  snapshotów przed retencją=${before_snaps}"

  e3_restic_repo "$repo" "$pass" forget --keep-last 1 --dry-run \
    > "${E3_RESULTS}/trials-restic-retention-dryrun.log" 2>&1
  local after_dry
  after_dry="$(e3_restic_repo "$repo" "$pass" snapshots --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  m3_log "  snapshotów po dry-run=${after_dry}"
  check "restic: dry-run retencji niczego nie usunął" \
    "$([ "$after_dry" = "$before_snaps" ] && echo yes || echo no)"

  # Kopia jednorazowa — prune wykonujemy WYŁĄCZNIE na niej.
  local copy="${E3_RETENTION_COPIES}/restic"
  e3_assert_safe_path "$copy"
  rm -rf -- "$copy"; cp -a "$repo" "$copy"
  case "$copy" in
    *"/retention-copies/"*) ;;
    *) m3_die "$M3_EXIT_REFUSED" "odmowa prune poza katalogiem kopii retencyjnych" ;;
  esac
  e3_restic_repo "$copy" "$pass" forget --keep-last 1 --prune \
    > "${E3_RESULTS}/trials-restic-retention.log" 2>&1
  local after_prune
  after_prune="$(e3_restic_repo "$copy" "$pass" snapshots --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  m3_log "  snapshotów w kopii po prune=${after_prune}"
  check "restic: retencja na kopii zostawiła dokładnie jeden snapshot" \
    "$([ "$after_prune" = "1" ] && echo yes || echo no)"

  local main_snaps
  main_snaps="$(e3_restic_repo "$repo" "$pass" snapshots --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  check "restic: repozytorium podstawowe nietknięte przez prune (${main_snaps})" \
    "$([ "$main_snaps" = "$before_snaps" ] && echo yes || echo no)"

  if e3_restic_repo "$copy" "$pass" check --read-data \
      > "${E3_RESULTS}/trials-restic-postcheck.log" 2>&1; then
    check "restic: kontrola integralności po retencji bez błędów" yes
  else
    check "restic: kontrola integralności po retencji bez błędów" no
  fi

  # Kroki manualne zaobserwowane w E3A/E3B: zdjęcie blokady po przerwaniu.
  manual_steps=1
  {
    echo "kandydat=restic"
    echo "czas_backupu_s=${backup_s}"
    echo "czas_pelnego_restore_s=${restore_s}"
    echo "rozmiar_zrodla_B=${source_bytes}"
    echo "rozmiar_repozytorium_B=${repo_bytes}"
    echo "snapshotow_przed_retencja=${before_snaps}"
    echo "snapshotow_po_dryrun=${after_dry}"
    echo "snapshotow_po_prune_na_kopii=${after_prune}"
    echo "restore_pojedynczego_pliku_plikow=${one_count}"
    echo "otwarcie_druga_kopia_hasla=$([ "$snaps_b" -ge 1 ] && echo tak || echo nie)"
    echo "kod_przy_zlym_hasle=${wrong_rc}"
    echo "kroki_manualne_po_przerwaniu=${manual_steps}  # restic unlock"
  } > "${E3_RESULTS}/trials-restic-summary.txt"
}

run_borg_trials() {
  local repo="${SIZING_DIR}/borg"
  local pass="$E3_BORG_PASSPHRASE_A"
  local manual_steps=0
  m3_section "=== Borg ==="

  e3_recreate_dir "$repo"
  e3_borg_repo "$repo" "$pass" init --encryption=repokey-blake2 >/dev/null 2>&1
  local t0 t1 backup_s
  t0="$(date +%s%N)"
  e3_borg_repo "$repo" "$pass" create --compression zstd "::sizing" "$E3_DR_DIR" \
    > "${E3_RESULTS}/trials-borg-backup.log" 2>&1
  t1="$(date +%s%N)"
  backup_s="$(python3 -c "print(round(($t1-$t0)/1e9, 2))")"
  local repo_bytes; repo_bytes="$(e3_bytes "$repo")"
  local source_bytes; source_bytes="$(e3_bytes "$E3_DR_DIR")"
  m3_log "  czas_backupu=${backup_s}s"
  m3_log "  rozmiar_źródła=${source_bytes} B"
  m3_log "  rozmiar_repozytorium=${repo_bytes} B"

  local full="${SIZING_DIR}/borg-full-restore"
  e3_recreate_dir "$full"
  t0="$(date +%s%N)"
  ( cd "$full" && BORG_PASSCOMMAND="cat ${pass}" BORG_REPO="$repo" "$E3_BORG" extract "::sizing" ) \
    > "${E3_RESULTS}/trials-borg-restore.log" 2>&1
  t1="$(date +%s%N)"
  local restore_s; restore_s="$(python3 -c "print(round(($t1-$t0)/1e9, 2))")"
  m3_log "  czas_pełnego_restore=${restore_s}s"
  check "borg: pełny extract odtworzył zestaw" \
    "$([ -n "$(find "$full" -name CHECKSUMS.sha256 | head -1)" ] && echo yes || echo no)"

  # --- restore pojedynczego pliku -----------------------------------------
  local one="${SINGLE_FILE_DIR}/borg"
  e3_recreate_dir "$one"
  # Borg zapisuje ścieżki bez wiodącego ukośnika.
  local rel_in_archive="${E3_DR_DIR#/}/${SINGLE_REL}"
  ( cd "$one" && BORG_PASSCOMMAND="cat ${pass}" BORG_REPO="$repo" \
      "$E3_BORG" extract "::sizing" "$rel_in_archive" ) \
    > "${E3_RESULTS}/trials-borg-single.log" 2>&1
  local one_file; one_file="$(find "$one" -type f -name "$(basename "$SINGLE_REL")" | head -1)"
  local one_count; one_count="$(find "$one" -type f | wc -l)"
  m3_log "  plików odtworzonych przy extract pojedynczego pliku=${one_count}"
  check "borg: extract pojedynczego pliku zwrócił dokładnie ten plik" \
    "$([ "$one_count" -eq 1 ] && echo yes || echo no)"
  check "borg: odtworzony pojedynczy plik ma zgodną sumę" \
    "$([ -n "$one_file" ] && [ "$(sha256sum "$one_file" | cut -d' ' -f1)" = "$SINGLE_SHA" ] && echo yes || echo no)"

  # --- otwarcie drugą kopią passphrase i kontrola kopii klucza ------------
  local list_b
  list_b="$(e3_borg_repo "$repo" "$E3_BORG_PASSPHRASE_B" list --format '{archive}{NL}' 2>/dev/null | grep -c . || true)"
  m3_log "  archiwów widocznych z kopii B passphrase=${list_b}"
  check "borg: repozytorium otwiera się drugą kopią passphrase" \
    "$([ "$list_b" -ge 1 ] && echo yes || echo no)"

  # Klucz repokey mieszka w repozytorium; eksport daje niezależny egzemplarz.
  local key_export="${SIZING_DIR}/borg-key.export"
  e3_borg_repo "$repo" "$pass" key export :: "$key_export" >/dev/null 2>&1
  chmod 600 "$key_export"
  m3_log "  eksport klucza=$(wc -c < "$key_export") B"
  check "borg: klucz repozytorium daje się wyeksportować poza repozytorium" \
    "$([ -s "$key_export" ] && echo yes || echo no)"
  check "borg: kopie klucza z etapu E3A są identyczne" \
    "$([ -s "$E3_BORG_KEY_A" ] && cmp -s "$E3_BORG_KEY_A" "$E3_BORG_KEY_B" && echo yes || echo no)"

  # --- diagnostyka przy złym haśle ----------------------------------------
  local wrong; wrong="$(mktemp)"; chmod 600 "$wrong"; printf 'nieprawidlowe-haslo' > "$wrong"
  set +e
  e3_borg_repo "$repo" "$wrong" list > "${E3_RESULTS}/trials-borg-wrongpass.log" 2>&1
  local wrong_rc=$?
  set -e
  rm -f "$wrong"
  m3_log "  kod przy złym haśle=${wrong_rc}"
  m3_log "  komunikat: $(head -1 "${E3_RESULTS}/trials-borg-wrongpass.log")"
  check "borg: złe hasło daje niezerowy kod i czytelny komunikat" \
    "$([ "$wrong_rc" -ne 0 ] && grep -qi 'passphrase\|decrypt\|wrong' "${E3_RESULTS}/trials-borg-wrongpass.log" && echo yes || echo no)"

  # --- retencja ------------------------------------------------------------
  for i in 1 2; do
    printf 'wersja %s\n' "$i" > "${E3_DR_DIR}/meta/.retention-marker"
    e3_borg_repo "$repo" "$pass" create --compression zstd "::sizing-$i" "$E3_DR_DIR" >/dev/null 2>&1
  done
  rm -f "${E3_DR_DIR}/meta/.retention-marker"
  local before_archives
  before_archives="$(e3_borg_repo "$repo" "$pass" list --format '{archive}{NL}' | grep -c . || true)"
  m3_log "  archiwów przed retencją=${before_archives}"

  e3_borg_repo "$repo" "$pass" prune --keep-last 1 --list --dry-run \
    > "${E3_RESULTS}/trials-borg-retention-dryrun.log" 2>&1
  local after_dry
  after_dry="$(e3_borg_repo "$repo" "$pass" list --format '{archive}{NL}' | grep -c . || true)"
  m3_log "  archiwów po dry-run=${after_dry}"
  check "borg: dry-run retencji niczego nie usunął" \
    "$([ "$after_dry" = "$before_archives" ] && echo yes || echo no)"

  local copy="${E3_RETENTION_COPIES}/borg"
  e3_assert_safe_path "$copy"
  rm -rf -- "$copy"; cp -a "$repo" "$copy"
  case "$copy" in
    *"/retention-copies/"*) ;;
    *) m3_die "$M3_EXIT_REFUSED" "odmowa prune poza katalogiem kopii retencyjnych" ;;
  esac

  # Borg wykrywa, że repozytorium zmieniło ścieżkę, i pyta interaktywnie. Bez
  # jawnej zgody każda operacja na skopiowanym repozytorium kończy się kodem 2.
  local relocated_rc
  set +e
  e3_borg_repo "$copy" "$pass" list >/dev/null 2>&1
  relocated_rc=$?
  set -e
  local needs_relocation_ack=no
  [ "$relocated_rc" -ne 0 ] && needs_relocation_ack=yes
  m3_log "  zgoda na przeniesienie repozytorium wymagana=${needs_relocation_ack}"

  # Kopia ma ten sam identyfikator co oryginał, więc Borg traktuje obie ścieżki
  # jako jedno repozytorium i współdzieli dla nich katalog cache oraz security.
  # Bez rozdzielenia stanu operacja na kopii blokuje potem dostęp do oryginału
  # komunikatem o „informacji nowszej niż repozytorium”. Każde repozytorium
  # dostaje więc własny BORG_BASE_DIR.
  local copy_base="${copy}.borg-base" main_base="${repo}.borg-base"
  install -d -m 700 "$copy_base" "$main_base"
  borg_copy() {
    BORG_BASE_DIR="$copy_base" BORG_RELOCATED_REPO_ACCESS_IS_OK=yes \
      e3_borg_repo "$copy" "$pass" "$@"
  }
  borg_main() { BORG_BASE_DIR="$main_base" e3_borg_repo "$repo" "$pass" "$@"; }

  borg_copy prune --keep-last 1 --list \
    > "${E3_RESULTS}/trials-borg-retention.log" 2>&1
  # W Borg 1.4 miejsce zwalnia dopiero `compact`.
  borg_copy compact >> "${E3_RESULTS}/trials-borg-retention.log" 2>&1
  local after_prune
  after_prune="$(borg_copy list --format '{archive}{NL}' | grep -c . || true)"
  m3_log "  archiwów w kopii po prune+compact=${after_prune}"
  check "borg: retencja na kopii zostawiła dokładnie jedno archiwum" \
    "$([ "$after_prune" = "1" ] && echo yes || echo no)"

  local main_archives
  main_archives="$(borg_main list --format '{archive}{NL}' | grep -c . || true)"
  check "borg: repozytorium podstawowe nietknięte przez prune (${main_archives})" \
    "$([ "$main_archives" = "$before_archives" ] && echo yes || echo no)"

  if borg_copy check --verify-data \
      > "${E3_RESULTS}/trials-borg-postcheck.log" 2>&1; then
    check "borg: kontrola integralności po retencji bez błędów" yes
  else
    check "borg: kontrola integralności po retencji bez błędów" no
  fi

  # Kroki manualne Borga: break-lock po przerwaniu, compact po prune oraz zgoda
  # na dostęp do przeniesionego repozytorium.
  manual_steps=3
  {
    echo "kandydat=borg"
    echo "czas_backupu_s=${backup_s}"
    echo "czas_pelnego_restore_s=${restore_s}"
    echo "rozmiar_zrodla_B=${source_bytes}"
    echo "rozmiar_repozytorium_B=${repo_bytes}"
    echo "archiwow_przed_retencja=${before_archives}"
    echo "archiwow_po_dryrun=${after_dry}"
    echo "archiwow_po_prune_na_kopii=${after_prune}"
    echo "restore_pojedynczego_pliku_plikow=${one_count}"
    echo "otwarcie_druga_kopia_hasla=$([ "$list_b" -ge 1 ] && echo tak || echo nie)"
    echo "kod_przy_zlym_hasle=${wrong_rc}"
    echo "wymagana_zgoda_na_przeniesienie_repo=${needs_relocation_ack}"
    echo "kopia_wymaga_izolowanego_BORG_BASE_DIR=tak"
    echo "kroki_manualne=${manual_steps}  # break-lock, compact po prune, zgoda na przeniesienie"
  } > "${E3_RESULTS}/trials-borg-summary.txt"
}

m3_section "Zestaw źródłowy prób"
m3_log "  zestaw_DR=${E3_DR_DIR}"
m3_log "  rozmiar=$(e3_bytes "$E3_DR_DIR") B"
m3_log "  plik kontrolny=${SINGLE_REL} sha256=${SINGLE_SHA}"

for candidate in $CANDIDATES; do
  case "$candidate" in
    restic) run_restic_trials ;;
    borg) run_borg_trials ;;
    *) m3_die "$M3_EXIT_USAGE" "nieznany kandydat: $candidate" ;;
  esac
done

m3_section "Podsumowanie prób narzędziowych"
m3_log "  kontroli nieudanych: $FAILURES"
m3_log "  wyniki: $E3_RESULTS"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
