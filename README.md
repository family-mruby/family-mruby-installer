# family-mruby-installer

Web-based firmware installer for the [Family mruby](https://family-mruby.github.io/) project.

Live: <https://family-mruby.github.io/family-mruby-installer/>

Flashes two firmware targets directly from the browser via the Web Serial API:

- **fmruby-core** — main application MCU (ESP32-S3, 16MB flash)
- **fmruby-graphics-audio** — graphics & audio co-processor (ESP32 / WROVER, 8MB flash)

Built on top of [ESP Web Tools](https://esphome.github.io/esp-web-tools/).

## For users

1. Open the live URL in **Chrome / Edge / Opera** (desktop). Firefox and Safari do not support Web Serial.
2. Connect the ESP32 device over USB.
3. Pick a version from the dropdown.
4. Click the appropriate **Connect & Flash** button (`fmruby-core` for the main MCU, `fmruby-graphics-audio` for the co-processor).
5. Select the serial port in the browser dialog and let the installer run. The `chipFamily` is checked against the connected chip — if you connect the wrong target it will refuse to flash.

## Layout

```
family-mruby-installer/
├── index.html               UI (version selector + 2 install buttons)
├── versions.json            published version list
├── firmware/<version>/<target>/
│   ├── manifest.json        ESP Web Tools manifest
│   ├── bootloader.bin
│   ├── partition-table.bin
│   ├── <target>.bin         application binary
│   └── storage.bin          littleFS partition image
├── js/esp-web-tools/        vendored ESP Web Tools (no CDN)
└── scripts/
    └── stage-firmware.sh    helper for staging a new version from local builds
```

## For maintainers

### Publishing a new version (automated)

The parent [`family-mruby/family-mruby`](https://github.com/family-mruby/family-mruby) repo has a `Release Firmware to Installer` workflow (`.github/workflows/release-installer.yml`) that does the entire release:

1. Builds `fmruby-core` and `fmruby-graphics-audio` from the refs pinned in `.repos`.
2. Runs `scripts/stage-firmware.sh <tag>` in this repo via SSH.
3. Updates `versions.json` (default + new entry).
4. Commits and pushes to `main` here.

Trigger: pushing a `MAJOR.MINOR.PATCH` tag to the parent repo, or running the workflow manually with a version input.

```bash
# In the parent family-mruby repo:
# 1. Update .repos so each sub-repo's `version:` points to the ref you want to ship
# 2. Commit and tag
git tag 0.2.0
git push origin 0.2.0
```

GitHub Pages picks up `main` automatically once the workflow pushes here.

### Manual fallback (no CI)

If you need to ship without CI (e.g. while debugging the workflow):

```bash
# Build firmwares locally in each sub-repo
( cd fmruby-core           && rake clean_all && rake build:esp32 )
( cd fmruby-graphics-audio && rake clean_all && rake build:esp32 )

# Stage into this repo
bash scripts/stage-firmware.sh 0.2.0

# Update versions.json (top of array, set default)
$EDITOR versions.json

# Commit and push
git add firmware/0.2.0 versions.json
git commit -m "Stage firmware 0.2.0 (manual)"
git push
```

`stage-firmware.sh` accepts `FMRUBY_CORE_BUILD` and `FMRUBY_GFX_BUILD` env vars to point at non-default build directories.

### Local preview

Web Serial requires HTTPS or `localhost`, so a static file server is enough:

```bash
python3 -m http.server 8000
# open http://localhost:8000/ in Chrome
```

### Manifest offsets

ESP Web Tools needs explicit byte offsets per part. They mirror each repo's `build/flasher_args.json`:

| Target | Chip | bootloader | partition-table | app | storage |
|---|---|---|---|---|---|
| fmruby-core | ESP32-S3 | `0x0` (0) | `0x8000` (32768) | `0x10000` (65536) | `0x210000` (2162688) |
| fmruby-graphics-audio | ESP32 | `0x1000` (4096) | `0x8000` (32768) | `0x10000` (65536) | `0x204000` (2113536) |

If a future build changes partition layout or storage size, regenerate `manifest.json` (the staging script writes it from a template, so re-running it is enough).

## License

Apache License 2.0. See [LICENSE](LICENSE).

The vendored copy of ESP Web Tools under `js/esp-web-tools/` is independently licensed under Apache-2.0 by the Open Home Foundation.
