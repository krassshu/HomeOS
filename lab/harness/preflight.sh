#!/usr/bin/env bash
# Audyt i preflight M3. Wyłącznie odczyt: nie zmienia source, nie tworzy dokumentów.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
lab_dir="$(cd -- "${script_dir}/.." && pwd)"
workspace_dir="$(cd -- "${lab_dir}/.." && pwd)"

# Zapamiętane przed `source`, bo common.sh nadaje M3_RAW_DIR własną wartość domyślną.
raw_dir_from_env="${M3_RAW_DIR:-}"

# shellcheck source=lab/harness/e1/common.sh
source "${script_dir}/e1/common.sh"

M3_RAW_DIR="${raw_dir_from_env:-${workspace_dir}/Docs/operations/spike-results/raw}"
OUT_DIR="${M3_RAW_DIR}/preflight"
TOOLCHAIN_BIN="${TOOLCHAIN_BIN:-${workspace_dir}/lab-data/toolchain/bin}"
NODE_IMAGE="${NODE_IMAGE:-node:24.18.0-bookworm-slim}"

# Minimalny zapas dysku dla prób backupu, zgodnie z warunkiem M3.
MIN_FREE_GB="${MIN_FREE_GB:-20}"

m3_require_cmds docker curl python3 sha256sum
m3_mkdir "$OUT_DIR"

fail_count=0
note_fail() { fail_count=$((fail_count + 1)); printf 'NIESPEŁNIONE: %s\n' "$*"; }

m3_section "1. System, Docker i Compose"
{
  echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "host=$(hostname)"
  echo "os=$(. /etc/os-release && echo "$PRETTY_NAME")"
  echo "kernel=$(uname -r)"
  echo "arch=$(uname -m)"
  echo "vcpu=$(nproc)"
  echo "ram_total=$(free -h | awk '/^Mem:/{print $2}')"
  echo "ram_available=$(free -h | awk '/^Mem:/{print $7}')"
  echo "docker_engine=$(docker version --format '{{.Server.Version}}')"
  echo "docker_client=$(docker version --format '{{.Client.Version}}')"
  echo "docker_compose=$(docker compose version --short)"
  echo "containerd=$(docker version --format '{{range .Server.Components}}{{if eq .Name "containerd"}}{{.Version}}{{end}}{{end}}')"
} | tee "${OUT_DIR}/host.txt"

m3_section "2. Storage i wolne miejsce"
df -h / "${workspace_dir}" | tee "${OUT_DIR}/disk.txt"
free_gb="$(df -BG --output=avail "${workspace_dir}" | tail -1 | tr -dc '0-9')"
echo "free_gb=${free_gb} min_required_gb=${MIN_FREE_GB}"
if [ "${free_gb}" -lt "${MIN_FREE_GB}" ]; then
  note_fail "wolne miejsce ${free_gb} GB < wymagane ${MIN_FREE_GB} GB — próby backupu muszą zostać wstrzymane"
fi

m3_section "3. Kontenery projektu source"
docker ps -a --filter "label=com.docker.compose.project=${M3_PROJECT}" \
  --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | tee "${OUT_DIR}/containers.txt"
container_count="$(docker ps -q --filter "label=com.docker.compose.project=${M3_PROJECT}" | wc -l)"
echo "running_containers=${container_count}"
[ "${container_count}" -eq 6 ] || note_fail "oczekiwano 6 działających kontenerów source, jest ${container_count}"

m3_section "4. Obraz, tag i digest każdego kontenera"
: > "${OUT_DIR}/images.tsv"
printf 'container\timage_ref\trepo_digest\timage_id\n' >> "${OUT_DIR}/images.tsv"
while read -r name; do
  [ -n "$name" ] || continue
  ref="$(docker inspect "$name" --format '{{.Config.Image}}')"
  img="$(docker inspect "$name" --format '{{.Image}}')"
  digest="$(docker image inspect "$img" --format '{{range .RepoDigests}}{{.}} {{end}}' 2>/dev/null | tr -s ' ' | sed 's/ $//')"
  printf '%s\t%s\t%s\t%s\n' "$name" "$ref" "${digest:-<brak>}" "$img" >> "${OUT_DIR}/images.tsv"
done < <(docker ps -a --filter "label=com.docker.compose.project=${M3_PROJECT}" --format '{{.Names}}')
column -t -s $'\t' "${OUT_DIR}/images.tsv"

m3_section "5. Kontrola digestu baseline Paperless"
expected_digest="sha256:3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582"
web_img="$(docker inspect "${M3_WEBSERVER}" --format '{{.Image}}')"
web_digests="$(docker image inspect "$web_img" --format '{{range .RepoDigests}}{{.}} {{end}}')"
echo "webserver_image_ref=$(docker inspect "${M3_WEBSERVER}" --format '{{.Config.Image}}')"
echo "webserver_repo_digests=${web_digests}"
if printf '%s' "$web_digests" | grep -q "$expected_digest"; then
  echo "digest_baseline=OK"
else
  note_fail "webserver nie działa na oczekiwanym digeście ${expected_digest}"
fi

m3_section "6. Publikacja portów — wyłącznie loopback"
docker ps --filter "label=com.docker.compose.project=${M3_PROJECT}" \
  --format '{{.Names}}\t{{.Ports}}' | tee "${OUT_DIR}/ports.txt"
public_ports="$(docker ps --filter "label=com.docker.compose.project=${M3_PROJECT}" --format '{{.Ports}}' \
  | tr ',' '\n' | grep -oE '^[[:space:]]*[0-9.:\[\]]+->' | grep -v '127\.0\.0\.1' || true)"
if [ -n "${public_ports}" ]; then
  note_fail "porty poza loopbackiem: ${public_ports}"
else
  echo "porty_publiczne=brak"
fi

m3_section "7. Zdrowie Paperless i /api/status/"
echo "docker_health=$(m3_health)"
m3_token_init
trap 'm3_token_cleanup' EXIT
m3_curl "${M3_API}/status/" -o "${OUT_DIR}/api-status.json" -D "${OUT_DIR}/api-status.headers"
m3_status_summary "${OUT_DIR}/api-status.json"
python3 - "${OUT_DIR}/api-status.json" <<'PY' || note_fail "status API nie jest w pełni OK"
import json, sys
d = json.load(open(sys.argv[1]))
ok = d["database"]["status"] == "OK" and all(
    d["tasks"][k] == "OK" for k in ("redis_status", "celery_status", "index_status")
)
print("status_all_ok=" + ("OK" if ok else "NIE"))
sys.exit(0 if ok else 1)
PY

m3_section "8. Stan kolekcji"
: > "${OUT_DIR}/counts.txt"
for res in documents tags correspondents document_types; do
  c="$(m3_curl "${M3_API}/${res}/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
  printf '%s=%s\n' "$res" "$c" | tee -a "${OUT_DIR}/counts.txt"
done
trash_count="$(m3_curl "${M3_API}/trash/?page_size=1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
printf 'trash=%s\n' "$trash_count" | tee -a "${OUT_DIR}/counts.txt"

m3_section "9. Sanity checker Paperless"
if docker exec "${M3_WEBSERVER}" document_sanity_checker > "${OUT_DIR}/sanity.txt" 2>&1; then
  echo "sanity=OK"
else
  echo "sanity=ZGŁOSZONE UWAGI (kod $?)"
fi
tail -5 "${OUT_DIR}/sanity.txt"

m3_section "10. Projekt restore"
restore_containers="$(docker ps -a --filter "label=com.docker.compose.project=homeos-m3-restore" --format '{{.Names}}' | wc -l)"
restore_volumes="$(docker volume ls -q --filter 'name=homeos-m3-restore' | wc -l)"
echo "restore_containers=${restore_containers}"
echo "restore_volumes=${restore_volumes}"
docker volume ls -q --filter 'name=homeos-m3-restore' || true
{
  echo "restore_containers=${restore_containers}"
  echo "restore_volumes=${restore_volumes}"
} > "${OUT_DIR}/restore-state.txt"

m3_section "11. Wolumeny źródła"
docker volume ls --filter 'name=homeos-m3-source' --format '{{.Name}}' | tee "${OUT_DIR}/source-volumes.txt"

m3_section "12. Wersje narzędzi"
{
  echo "restic=$("${TOOLCHAIN_BIN}/restic" version 2>/dev/null | head -1)"
  echo "borg=$("${TOOLCHAIN_BIN}/borg" --version 2>/dev/null)"
  echo "python3_host=$(python3 --version)"
  echo "node_image=${NODE_IMAGE}"
  echo "node=$(docker run --rm "${NODE_IMAGE}" node --version 2>/dev/null)"
  echo "npm=$(docker run --rm "${NODE_IMAGE}" npm --version 2>/dev/null)"
  echo "bullmq=$(python3 -c 'import json;print(json.load(open("'"${lab_dir}"'/harness/package.json"))["dependencies"]["bullmq"])')"
  echo "prisma=$(python3 -c 'import json;print(json.load(open("'"${lab_dir}"'/e2/package.json"))["devDependencies"]["prisma"])')"
  echo "prisma_client=$(python3 -c 'import json;print(json.load(open("'"${lab_dir}"'/e2/package.json"))["dependencies"]["@prisma/client"])')"
  echo "drizzle_orm=$(python3 -c 'import json;print(json.load(open("'"${lab_dir}"'/e2/package.json"))["dependencies"]["drizzle-orm"])')"
  echo "drizzle_kit=$(python3 -c 'import json;print(json.load(open("'"${lab_dir}"'/e2/package.json"))["devDependencies"]["drizzle-kit"])')"
  echo "postgres_source=$(docker exec "${M3_PROJECT}-db-1" postgres --version 2>/dev/null)"
  echo "postgres_core_fixture=$(docker exec "${M3_PROJECT}-core_fixture_db-1" postgres --version 2>/dev/null)"
  echo "valkey_source=$(docker exec "${M3_PROJECT}-broker-1" valkey-server --version 2>/dev/null)"
} | tee "${OUT_DIR}/tool-versions.txt"

m3_section "13. Pakiety Debiana narzędzi backupu"
{
  for d in "${workspace_dir}"/lab-data/toolchain/debs/*.deb; do
    [ -e "$d" ] || continue
    printf '%s\t%s\t%s\n' \
      "$(dpkg-deb -f "$d" Package)" \
      "$(dpkg-deb -f "$d" Version)" \
      "$(dpkg-deb -f "$d" Architecture)"
  done
} | tee "${OUT_DIR}/backup-tool-packages.tsv"

m3_section "14. docker compose config — cztery warianty"
# `docker compose config` rozwija sekrety z pliku env, więc wynik nigdy nie trafia
# na dysk w postaci surowej — zapisujemy wyłącznie wersję zredagowaną.
redact_config() {
  # Skrypt przekazany przez -c, bo `python3 -` z heredokiem zajmuje stdin,
  # z którego trzeba przeczytać redagowaną konfigurację.
  python3 -c '
import re, sys

SECRET_KEY = re.compile(r"(?i)(password|passwd|secret|token|api_key|_key)$")
for line in sys.stdin:
    line = line.rstrip("\n")
    m = re.match(r"^(\s*)([A-Za-z0-9_.-]+)(:\s+|=)(.+?)\s*$", line)
    if m and SECRET_KEY.search(m.group(2)):
        value = m.group(4).strip().strip("\"'"'"'")
        if value and not value.startswith("${"):
            print(f"{m.group(1)}{m.group(2)}{m.group(3)}<zredagowano:{len(value)} znaków>")
            continue
    print(line)
'
}

config_fail=0
for target in source restore; do
  for valkey in shared split; do
    raw_config="$(mktemp)"; chmod 600 "$raw_config"
    if "${lab_dir}/m3-lab.sh" "$target" "$valkey" config > "$raw_config" 2>"${OUT_DIR}/config-${target}-${valkey}.err"; then
      redact_config < "$raw_config" > "${OUT_DIR}/config-${target}-${valkey}.yaml"
      echo "config ${target}/${valkey}=OK ($(wc -l < "${OUT_DIR}/config-${target}-${valkey}.yaml") linii, zredagowano $(grep -c '<zredagowano:' "${OUT_DIR}/config-${target}-${valkey}.yaml" || true) wartości)"
    else
      config_fail=1
      note_fail "docker compose config ${target}/${valkey} nie powiodło się"
      tail -3 "${OUT_DIR}/config-${target}-${valkey}.err"
    fi
    shred -u "$raw_config" 2>/dev/null || rm -f "$raw_config"
  done
done

m3_section "15. Kontrola obrazów bez tagu latest"
if grep -rn 'image:.*:latest' "${OUT_DIR}"/config-*.yaml >/dev/null 2>&1; then
  note_fail "konfiguracja zawiera obraz z tagiem latest"
else
  echo "latest=brak"
fi

m3_section "16. Rozdzielność source i restore"
overlap="$(python3 - "${OUT_DIR}/config-source-shared.yaml" "${OUT_DIR}/config-restore-shared.yaml" <<'PY'
import re, sys
def names(path):
    txt = open(path).read()
    # Compose zapisuje nazwę wolumenu w polu `name:` sekcji `volumes:`.
    vols = set(re.findall(r'^\s+name:\s*(homeos-m3-\S+)\s*$', txt, re.M))
    binds = set(re.findall(r'source:\s*(\S+)', txt))
    return vols, binds
sv, sb = names(sys.argv[1])
rv, rb = names(sys.argv[2])
# Pusta konfiguracja dałaby fałszywe "brak" — kontrola musi mieć co porównywać.
if len(sv) < 3 or len(rv) < 3:
    print(f"BŁĄD_WEJŚCIA: za mało wolumenów do porównania (source={len(sv)}, restore={len(rv)})")
    raise SystemExit(1)
shared_vol = sv & rv
shared_bind = {b for b in (sb & rb) if 'lab-data' in b}
print(f"wolumeny_source={len(sv)} wolumeny_restore={len(rv)}")
print("wspólne_wolumeny=" + (",".join(sorted(shared_vol)) or "brak"))
print("wspólne_katalogi_danych=" + (",".join(sorted(shared_bind)) or "brak"))
PY
)" || note_fail "nie udało się porównać konfiguracji source i restore"
echo "$overlap"
printf '%s' "$overlap" | grep -q 'wspólne_wolumeny=brak' || note_fail "source i restore współdzielą wolumen"
printf '%s' "$overlap" | grep -q 'wspólne_katalogi_danych=brak' || note_fail "source i restore współdzielą katalog danych"

m3_section "Podsumowanie preflight"
echo "katalog_wyników=${OUT_DIR}"
if [ "$fail_count" -eq 0 ]; then
  echo "PREFLIGHT: OK"
  exit "$M3_EXIT_OK"
fi
echo "PREFLIGHT: ${fail_count} niespełnionych warunków"
exit "$M3_EXIT_FAIL"
