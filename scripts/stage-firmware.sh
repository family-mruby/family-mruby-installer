#!/usr/bin/env bash
# Usage: scripts/stage-firmware.sh <version>
# Copies build artifacts from fmruby-core/ and fmruby-graphics-audio/ build/
# directories into firmware/<version>/ and writes per-target manifest.json.
#
# By default the source build dirs are resolved relative to this script
# (assuming the installer lives at family-mruby/tmp/family-mruby-installer/).
# Override with FMRUBY_CORE_BUILD / FMRUBY_GFX_BUILD env vars when running
# from elsewhere.

set -euo pipefail

VER="${1:-}"
if [[ -z "$VER" ]]; then
  echo "Usage: $0 <version>     (e.g. $0 0.1.0)" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_BUILD="${FMRUBY_CORE_BUILD:-${ROOT}/../../fmruby-core/build}"
GFX_BUILD="${FMRUBY_GFX_BUILD:-${ROOT}/../../fmruby-graphics-audio/build}"

if [[ ! -d "$CORE_BUILD" ]]; then
  echo "fmruby-core build dir not found: $CORE_BUILD" >&2
  echo "Run 'rake build:esp32' in fmruby-core first, or set FMRUBY_CORE_BUILD." >&2
  exit 1
fi
if [[ ! -d "$GFX_BUILD" ]]; then
  echo "fmruby-graphics-audio build dir not found: $GFX_BUILD" >&2
  echo "Run 'rake build:esp32' in fmruby-graphics-audio first, or set FMRUBY_GFX_BUILD." >&2
  exit 1
fi

# stage <target> <build_dir> <chipFamily> <bootloader_offset> <storage_offset> <app_bin_name>
stage() {
  local target="$1" build_dir="$2" chip="$3" boot_off="$4" stor_off="$5" app_bin="$6"
  local dest="${ROOT}/firmware/${VER}/${target}"

  mkdir -p "$dest"
  cp "${build_dir}/bootloader/bootloader.bin"           "$dest/"
  cp "${build_dir}/partition_table/partition-table.bin" "$dest/"
  cp "${build_dir}/${app_bin}"                          "$dest/"
  cp "${build_dir}/storage.bin"                         "$dest/"

  cat > "${dest}/manifest.json" <<EOF
{
  "name": "${target}",
  "version": "${VER}",
  "new_install_prompt_erase": true,
  "builds": [
    {
      "chipFamily": "${chip}",
      "parts": [
        { "path": "bootloader.bin",       "offset": ${boot_off} },
        { "path": "partition-table.bin",  "offset": 32768 },
        { "path": "${app_bin}",           "offset": 65536 },
        { "path": "storage.bin",          "offset": ${stor_off} }
      ]
    }
  ]
}
EOF
  echo "Staged ${target} v${VER} -> firmware/${VER}/${target}/"
}

stage "fmruby-core"           "$CORE_BUILD" "ESP32-S3" 0    2162688 "fmruby-core.bin"
stage "fmruby-graphics-audio" "$GFX_BUILD"  "ESP32"    4096 2113536 "fmruby-graphics-audio.bin"

echo
echo "Done. Next steps:"
echo "  1. Edit versions.json and add: { \"tag\": \"${VER}\", \"released\": \"$(date +%Y-%m-%d)\" }"
echo "  2. git add firmware/${VER} versions.json"
echo "  3. git commit && git push"
