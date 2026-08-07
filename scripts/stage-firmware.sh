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

# stage <target> <build_dir> <chipFamily>
#
# Files and offsets come from the build's own flasher_args.json, never from
# constants here: a hardcoded storage offset (0x210000, from the 2MB-factory
# era) outlived two partition-table growths and bricked S3 installs when
# storage landed inside the 4MB factory app. The build is the single source
# of truth for the flash layout.
stage() {
  local target="$1" build_dir="$2" chip="$3"
  local dest="${ROOT}/firmware/${VER}/${target}"
  local fa="${build_dir}/flasher_args.json"

  if [[ ! -f "$fa" ]]; then
    echo "flasher_args.json not found in ${build_dir}" >&2
    exit 1
  fi

  mkdir -p "$dest"
  python3 - "$fa" "$build_dir" "$dest" "$target" "$VER" "$chip" <<'PY'
import json, shutil, sys
fa_path, build_dir, dest, target, ver, chip = sys.argv[1:7]
files = json.load(open(fa_path))["flash_files"]
parts = []
for off, rel in sorted(files.items(), key=lambda kv: int(kv[0], 16)):
    name = rel.split("/")[-1]
    shutil.copy(f"{build_dir}/{rel}", f"{dest}/{name}")
    parts.append({"path": name, "offset": int(off, 16)})
manifest = {
    "name": target,
    "version": ver,
    "new_install_prompt_erase": True,
    "builds": [{"chipFamily": chip, "parts": parts}],
}
with open(f"{dest}/manifest.json", "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
PY
  echo "Staged ${target} v${VER} -> firmware/${VER}/${target}/"
}

stage "fmruby-core"           "$CORE_BUILD" "ESP32-S3"
stage "fmruby-graphics-audio" "$GFX_BUILD"  "ESP32"

# Modern (M5Stack Tab5, ESP32-P4): single-chip firmware, staged only when the
# caller provides a Tab5 build dir (releases before 2.0.0 have none).
TAB5_BUILD="${FMRUBY_CORE_TAB5_BUILD:-}"
if [[ -n "$TAB5_BUILD" && -d "$TAB5_BUILD" ]]; then
  stage "fmruby-core-tab5" "$TAB5_BUILD" "ESP32-P4"
fi

echo
echo "Done. Next steps:"
echo "  1. Edit versions.json and add: { \"tag\": \"${VER}\", \"released\": \"$(date +%Y-%m-%d)\" }"
echo "  2. git add firmware/${VER} versions.json"
echo "  3. git commit && git push"
