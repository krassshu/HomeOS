#!/usr/bin/env bash
set -Eeuo pipefail

lab_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_dir="$(cd -- "${lab_dir}/.." && pwd)"

usage() {
  echo "Użycie: ./m3-lab.sh <source|restore> <shared|split> <config|images|versions|up|down|reset|export|import|sanity|prepare-restore>"
}

target="${1:-}"
valkey_mode="${2:-}"
action="${3:-}"

case "${target}" in
  source)
    target_file="${lab_dir}/compose.source.yaml"
    env_file="${M3_ENV_FILE:-${lab_dir}/.env.source}"
    example_env="${lab_dir}/.env.example"
    runtime_dir="${workspace_dir}/lab-data/m3-source"
    project_name="homeos-m3-source"
    ;;
  restore)
    target_file="${lab_dir}/compose.restore.yaml"
    env_file="${M3_ENV_FILE:-${lab_dir}/.env.restore}"
    example_env="${lab_dir}/restore.env.example"
    runtime_dir="${workspace_dir}/lab-data/m3-restore"
    project_name="homeos-m3-restore"
    ;;
  *)
    usage
    exit 2
    ;;
esac

case "${valkey_mode}" in
  shared)
    valkey_file="${lab_dir}/compose.valkey-shared.yaml"
    ;;
  split)
    valkey_file="${lab_dir}/compose.valkey-split.yaml"
    ;;
  *)
    usage
    exit 2
    ;;
esac

case "${action}" in
  config|images|versions)
    if [[ ! -f "${env_file}" ]]; then
      env_file="${example_env}"
    fi
    ;;
  up|down|reset|export|import|sanity|prepare-restore)
    if [[ ! -f "${env_file}" ]]; then
      echo "Brak ${env_file}. Utwórz go z ${example_env}."
      exit 1
    fi
    ;;
  *)
    usage
    exit 2
    ;;
esac

compose=(
  docker compose
  --env-file "${env_file}"
  -f "${lab_dir}/compose.baseline.yaml"
  -f "${lab_dir}/compose.override.yaml"
  -f "${target_file}"
  -f "${valkey_file}"
)

require_real_secrets() {
  if grep -qE '^[A-Z0-9_]+=replace-this' "${env_file}"; then
    echo "Plik ${env_file} nadal zawiera bezpieczne placeholdery."
    exit 1
  fi
}

prepare_runtime_dirs() {
  install -d -m 700 \
    "${runtime_dir}" \
    "${runtime_dir}/consume" \
    "${runtime_dir}/export"
}

case "${action}" in
  config)
    "${compose[@]}" config
    ;;
  images|versions)
    "${compose[@]}" config --images | sort -u
    ;;
  up)
    require_real_secrets
    prepare_runtime_dirs
    "${compose[@]}" up -d
    ;;
  down)
    "${compose[@]}" down --remove-orphans
    ;;
  reset)
    require_real_secrets
    if [[ "${M3_CONFIRM_RESET:-}" != "${project_name}" ]]; then
      echo "Pełny reset wymaga M3_CONFIRM_RESET=${project_name}."
      exit 1
    fi
    "${compose[@]}" down --volumes --remove-orphans
    case "${runtime_dir}" in
      "${workspace_dir}/lab-data/m3-source"|"${workspace_dir}/lab-data/m3-restore")
        if [[ -d "${runtime_dir}" ]]; then
          find "${runtime_dir}" -depth -mindepth 1 -delete
        fi
        ;;
      *)
        echo "Odmowa resetu nieoczekiwanej ścieżki: ${runtime_dir}"
        exit 1
        ;;
    esac
    ;;
  export)
    require_real_secrets
    if [[ "${target}" != "source" ]]; then
      echo "Eksport M3 wykonuje się ze środowiska source."
      exit 1
    fi
    prepare_runtime_dirs
    "${compose[@]}" exec -T webserver \
      document_exporter ../export --compare-checksums
    ;;
  import)
    require_real_secrets
    if [[ "${target}" != "restore" ]]; then
      echo "Import M3 wykonuje się do czystego środowiska restore."
      exit 1
    fi
    "${compose[@]}" exec -T webserver document_importer ../export
    ;;
  sanity)
    require_real_secrets
    "${compose[@]}" exec -T webserver document_sanity_checker
    ;;
  prepare-restore)
    require_real_secrets
    if [[ "${target}" != "restore" ]]; then
      echo "prepare-restore wymaga targetu restore."
      exit 1
    fi
    if [[ -d "${runtime_dir}" ]] && [[ -n "$(find "${runtime_dir}" -mindepth 1 -print -quit)" ]]; then
      echo "Katalog restore nie jest pusty: ${runtime_dir}"
      exit 1
    fi
    for volume in \
      homeos-m3-restore-paperless-data \
      homeos-m3-restore-paperless-media \
      homeos-m3-restore-paperless-postgres \
      homeos-m3-restore-paperless-valkey \
      homeos-m3-restore-core-postgres \
      homeos-m3-restore-core-assets \
      homeos-m3-restore-core-valkey; do
      if docker volume inspect "${volume}" >/dev/null 2>&1; then
        echo "Cel restore nie jest czysty; istnieje wolumen ${volume}."
        exit 1
      fi
    done
    prepare_runtime_dirs
    echo "Czysty cel restore przygotowany: ${runtime_dir}"
    ;;
esac
