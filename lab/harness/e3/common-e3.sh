#!/usr/bin/env bash
# Wspólne definicje toru E3. Plik jest przeznaczony do `source`.
#
# Wszystkie katalogi E3 leżą w `lab-data/`, czyli poza wersjonowaną częścią
# repozytorium. Hasła i klucze nigdy nie trafiają do logów ani dokumentacji —
# skrypty operują na ścieżkach do plików, nie na wartościach.
set -Eeuo pipefail

E3_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../e1/common.sh
source "${E3_HERE}/../e1/common.sh"

E3_WORKSPACE="${E3_WORKSPACE:-$(cd -- "${M3_LAB_DIR}/.." && pwd)}"
E3_ROOT="${E3_ROOT:-${E3_WORKSPACE}/lab-data/e3}"

E3_RESTIC_REPO="${E3_RESTIC_REPO:-${E3_ROOT}/repositories/restic}"
E3_BORG_REPO="${E3_BORG_REPO:-${E3_ROOT}/repositories/borg}"
E3_RESTORE_STAGING="${E3_RESTORE_STAGING:-${E3_ROOT}/restore-staging}"
E3_RETENTION_COPIES="${E3_RETENTION_COPIES:-${E3_ROOT}/retention-copies}"
E3_RECOVERY_A="${E3_RECOVERY_A:-${E3_ROOT}/recovery-copy-a}"
E3_RECOVERY_B="${E3_RECOVERY_B:-${E3_ROOT}/recovery-copy-b}"
E3_EXPORT_DIR="${E3_EXPORT_DIR:-${E3_ROOT}/export}"
E3_DR_DIR="${E3_DR_DIR:-${E3_ROOT}/dr-set}"
E3_RESULTS="${E3_RESULTS:-${E3_ROOT}/results}"

E3_TOOLCHAIN_BIN="${E3_TOOLCHAIN_BIN:-${E3_WORKSPACE}/lab-data/toolchain/bin}"
E3_RESTIC="${E3_RESTIC:-${E3_TOOLCHAIN_BIN}/restic}"
E3_BORG="${E3_BORG:-${E3_TOOLCHAIN_BIN}/borg}"

# Materiały odzyskiwania: dwie identyczne kopie, obie 0600.
E3_RESTIC_PASSWORD_A="${E3_RECOVERY_A}/restic-repository-password"
E3_RESTIC_PASSWORD_B="${E3_RECOVERY_B}/restic-repository-password"
E3_BORG_PASSPHRASE_A="${E3_RECOVERY_A}/borg-repository-passphrase"
E3_BORG_PASSPHRASE_B="${E3_RECOVERY_B}/borg-repository-passphrase"
E3_BORG_KEY_A="${E3_RECOVERY_A}/borg-repository-key.export"
E3_BORG_KEY_B="${E3_RECOVERY_B}/borg-repository-key.export"

e3_require_tools() {
  [ -x "$E3_RESTIC" ] || m3_die "$M3_EXIT_PRECONDITION" "brak restic: $E3_RESTIC"
  [ -x "$E3_BORG" ] || m3_die "$M3_EXIT_PRECONDITION" "brak borg: $E3_BORG"
}

e3_require_recovery_material() {
  local missing=()
  for f in "$E3_RESTIC_PASSWORD_A" "$E3_RESTIC_PASSWORD_B" \
           "$E3_BORG_PASSPHRASE_A" "$E3_BORG_PASSPHRASE_B"; do
    [ -r "$f" ] || missing+=("$f")
  done
  [ ${#missing[@]} -eq 0 ] || m3_die "$M3_EXIT_PRECONDITION" \
    "brak materiałów odzyskiwania: ${missing[*]} — uruchom prepare-storage.sh"
}

# Wywołania narzędzi. Hasło idzie plikiem, nigdy argumentem ani zmienną w logu.
e3_restic() {
  RESTIC_PASSWORD_FILE="$E3_RESTIC_PASSWORD_A" \
  RESTIC_REPOSITORY="$E3_RESTIC_REPO" \
  "$E3_RESTIC" "$@"
}

e3_restic_repo() { # e3_restic_repo <repo> <plik_hasła> <argumenty...>
  local repo="$1" pass="$2"; shift 2
  RESTIC_PASSWORD_FILE="$pass" RESTIC_REPOSITORY="$repo" "$E3_RESTIC" "$@"
}

# Borg 1.4 nie zna BORG_PASSPHRASE_FILE (to zmienna z serii 2.x). Hasło podaje
# BORG_PASSCOMMAND: w argumentach procesu widać wyłącznie ścieżkę do pliku 0600,
# nigdy samą wartość.
e3_borg() {
  BORG_PASSCOMMAND="cat ${E3_BORG_PASSPHRASE_A}" \
  BORG_REPO="$E3_BORG_REPO" \
  BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=no \
  "$E3_BORG" "$@" < /dev/null
}

e3_borg_repo() { # e3_borg_repo <repo> <plik_hasła> <argumenty...>
  local repo="$1" pass="$2"; shift 2
  BORG_PASSCOMMAND="cat ${pass}" BORG_REPO="$repo" "$E3_BORG" "$@" < /dev/null
}

e3_sha256_dir() { # e3_sha256_dir <katalog> — stabilny checksum zawartości drzewa
  ( cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1 )
}

e3_bytes() { du -sb "$1" 2>/dev/null | cut -f1; }

# Każdy katalog czyszczony rekurencyjnie przez harness musi być ścisłym
# potomkiem E3_ROOT. Chroni to również przy omyłkowym nadpisaniu zmiennych env.
e3_assert_safe_path() { # e3_assert_safe_path <katalog>
  local root target
  root="$(realpath -m -- "$E3_ROOT")"
  target="$(realpath -m -- "$1")"
  case "$root" in
    /|"$(realpath -m -- "$E3_WORKSPACE")"|"$(realpath -m -- "${E3_WORKSPACE}/lab-data")")
      m3_die "$M3_EXIT_REFUSED" "niebezpiecznie szeroki E3_ROOT: $root" ;;
  esac
  case "$target" in
    "$root"/*) ;;
    *) m3_die "$M3_EXIT_REFUSED" "odmowa operacji poza E3_ROOT: $target" ;;
  esac
}

e3_recreate_dir() { # e3_recreate_dir <katalog>
  e3_assert_safe_path "$1"
  rm -rf -- "$1"
  install -d -m 700 "$1"
}
