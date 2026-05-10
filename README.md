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

### Publishing a new version

1. Build both firmwares locally:

   ```bash
   # In fmruby-core
   rake clean_all && rake build:esp32

   # In fmruby-graphics-audio
   rake clean_all && rake build:esp32
   ```

2. From inside this repo, run the staging helper:

   ```bash
   bash scripts/stage-firmware.sh 0.2.0
   ```

   It copies bootloader / partition-table / app / storage from each repo's `build/` directory into `firmware/0.2.0/<target>/` and writes the per-target `manifest.json`.

   Override source paths if your checkout layout differs:

   ```bash
   FMRUBY_CORE_BUILD=/path/to/fmruby-core/build \
   FMRUBY_GFX_BUILD=/path/to/fmruby-graphics-audio/build \
   bash scripts/stage-firmware.sh 0.2.0
   ```

3. Edit `versions.json` to add the new entry at the top of the `versions` array and update `default`:

   ```json
   {
     "default": "0.2.0",
     "versions": [
       { "tag": "0.2.0", "released": "2026-mm-dd" },
       { "tag": "0.1.0", "released": "2026-05-10" }
     ]
   }
   ```

4. Commit and push:

   ```bash
   git add firmware/0.2.0 versions.json
   git commit -m "Stage firmware 0.2.0"
   git push
   ```

   GitHub Pages picks up `main` automatically.

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

## Roadmap

- **Tag-driven CI** — wire a workflow on the parent `family-mruby` repo so that pushing a release tag automatically builds both firmwares and pushes the staged version to this repo. Right now the `stage-firmware.sh` script is the manual equivalent of what that CI would do.
- **Serial console** — optional Web Serial monitor (similar to [R2P2-ESP32-installer](https://github.com/kishima/R2P2-ESP32-installer)) for post-flash boot log inspection.

## License

Same as the family-mruby project. Vendored ESP Web Tools is Apache-2.0 licensed by the Open Home Foundation.
