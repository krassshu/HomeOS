#!/usr/bin/env bash
# Etap 5 — lokalna symulacja storage dla E3.
#
# Tworzy katalogi repozytoriów, stagingu, kopii retencyjnych i materiałów
# odzyskiwania oraz generuje osobne losowe hasła dla Restic i Borg. Hasła są
# zapisywane w dwóch identycznych kopiach (recovery-copy-a i recovery-copy-b),
# obie z uprawnieniami 0600.
#
# UWAGA: to jest wyłącznie symulacja dwóch kopii. Oba katalogi leżą na tym samym
# fizycznym storage tej samej maszyny. Po dostarczeniu dysków materiały muszą
# zostać przeniesione również poza serwer.
#
# Skrypt nigdy nie wypisuje wartości haseł ani kluczy.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common-e3.sh
source "${HERE}/common-e3.sh"

usage() {
  cat <<'EOF'
Użycie: ./prepare-storage.sh [--rotate]

Tworzy strukturę katalogów E3 i materiały odzyskiwania. Domyślnie nie nadpisuje
istniejących haseł. --rotate wymusza wygenerowanie nowych (unieważnia dostęp do
istniejących repozytoriów).
EOF
}

ROTATE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rotate) ROTATE=1; shift ;;
    -h|--help) usage; exit "$M3_EXIT_OK" ;;
    *) usage >&2; m3_die "$M3_EXIT_USAGE" "nieznany argument: $1" ;;
  esac
done

m3_require_cmds install sha256sum cmp
e3_require_tools

FAILURES=0
check() { if [ "$2" = "yes" ]; then m3_log "  OK   $1"; else m3_log "  FAIL $1"; FAILURES=$((FAILURES + 1)); fi; }

umask 077

m3_section "1. Katalogi symulacji storage"
for dir in "$E3_ROOT" \
           "${E3_ROOT}/repositories" \
           "$E3_RESTIC_REPO" "$E3_BORG_REPO" \
           "$E3_RESTORE_STAGING" "$E3_RETENTION_COPIES" \
           "$E3_RECOVERY_A" "$E3_RECOVERY_B" \
           "$E3_EXPORT_DIR" "$E3_DR_DIR" "$E3_RESULTS"; do
  install -d -m 700 "$dir"
  printf '  %-58s %s\n' "$dir" "$(stat -c %a "$dir")"
done

BAD_PERMS="$(find "$E3_ROOT" -maxdepth 2 -type d ! -perm 700 | wc -l)"
check "wszystkie katalogi E3 mają uprawnienia 700" \
  "$([ "$BAD_PERMS" -eq 0 ] && echo yes || echo no)"

m3_section "2. Materiały odzyskiwania"
# Osobne, niezależne hasła: kompromitacja jednego repozytorium nie otwiera drugiego.
new_secret() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

write_pair() { # write_pair <opis> <plik_a> <plik_b>
  local label="$1" file_a="$2" file_b="$3"
  if [ -s "$file_a" ] && [ "$ROTATE" -ne 1 ]; then
    m3_log "  ${label}: istnieje, pozostawiam bez zmian"
  else
    local secret; secret="$(new_secret)"
    printf '%s' "$secret" > "$file_a"
    printf '%s' "$secret" > "$file_b"
    unset secret
    m3_log "  ${label}: wygenerowano nowe"
  fi
  chmod 600 "$file_a" "$file_b"
  local perm_a perm_b
  perm_a="$(stat -c %a "$file_a")"; perm_b="$(stat -c %a "$file_b")"
  check "${label}: obie kopie mają uprawnienia 0600 (${perm_a}/${perm_b})" \
    "$([ "$perm_a" = "600" ] && [ "$perm_b" = "600" ] && echo yes || echo no)"
  check "${label}: kopia A i kopia B są identyczne" \
    "$(cmp -s "$file_a" "$file_b" && echo yes || echo no)"
  # Do raportu trafia wyłącznie długość i skrót skrótu, nigdy wartość.
  m3_log "  ${label}: długość=$(wc -c < "$file_a") B, sha256(hasła)=$(sha256sum < "$file_a" | cut -c1-12)…"
}

write_pair "hasło repozytorium Restic" "$E3_RESTIC_PASSWORD_A" "$E3_RESTIC_PASSWORD_B"
write_pair "passphrase repozytorium Borg" "$E3_BORG_PASSPHRASE_A" "$E3_BORG_PASSPHRASE_B"

check "hasła Restic i Borg są różne" \
  "$(cmp -s "$E3_RESTIC_PASSWORD_A" "$E3_BORG_PASSPHRASE_A" && echo no || echo yes)"

m3_section "3. Kontrola, że materiały nie trafiają do repozytorium Git"
IGNORED=0
if grep -q '^lab-data/' "${E3_WORKSPACE}/.gitignore" 2>/dev/null; then IGNORED=1; fi
check "katalog lab-data/ jest ignorowany przez Git" \
  "$([ "$IGNORED" -eq 1 ] && echo yes || echo no)"
check "materiały leżą poza wersjonowanym drzewem" \
  "$(case "$E3_RECOVERY_A" in *"/lab-data/"*) echo yes ;; *) echo no ;; esac)"

m3_section "4. Ograniczenie symulacji"
m3_log "  recovery-copy-a: ${E3_RECOVERY_A}"
m3_log "  recovery-copy-b: ${E3_RECOVERY_B}"
m3_log "  urządzenie A=$(stat -c %d "$E3_RECOVERY_A") urządzenie B=$(stat -c %d "$E3_RECOVERY_B")"
SAME_DEVICE="$([ "$(stat -c %d "$E3_RECOVERY_A")" = "$(stat -c %d "$E3_RECOVERY_B")" ] && echo yes || echo no)"
m3_log "  obie kopie na tym samym urządzeniu: ${SAME_DEVICE}"
m3_log ""
m3_log "  To jest symulacja. Dwie kopie na jednym fizycznym storage NIE chronią"
m3_log "  przed utratą serwera. Po dostarczeniu dysków 4 TB materiały odzyskiwania"
m3_log "  muszą zostać przeniesione również poza ten serwer."

{
  echo "restic_repo=${E3_RESTIC_REPO}"
  echo "borg_repo=${E3_BORG_REPO}"
  echo "restore_staging=${E3_RESTORE_STAGING}"
  echo "retention_copies=${E3_RETENTION_COPIES}"
  echo "recovery_copy_a=${E3_RECOVERY_A}"
  echo "recovery_copy_b=${E3_RECOVERY_B}"
  echo "obie_kopie_na_tym_samym_urzadzeniu=${SAME_DEVICE}"
  echo "restic=$("$E3_RESTIC" version | head -1)"
  echo "borg=$("$E3_BORG" --version)"
} > "${E3_RESULTS}/storage-simulation.txt"

m3_section "Podsumowanie"
m3_log "  kontroli nieudanych: $FAILURES"
m3_log "  opis: ${E3_RESULTS}/storage-simulation.txt"
[ "$FAILURES" -eq 0 ] || exit "$M3_EXIT_FAIL"
