# Tea in the Hegemony

Narrative social-espionage RPG — chapter **The Reception**.

Godot **4.3**, **Compatibility** renderer (browser-friendly), typed GDScript.

## Play in browser

**Play (GitHub Pages):** [https://jxav22.github.io/tea-in-the-hegemony/](https://jxav22.github.io/tea-in-the-hegemony/)

> **Not live yet (404).** CI `export-web` succeeds; `deploy-pages` needs the repo owner to set **Settings → Pages → Source: GitHub Actions**, then re-run the workflow. See [HANDOFF.md](HANDOFF.md#play-in-browser-publish).

itch.io-compatible ZIP is produced by CI artifact `tea-in-the-hegemony-web-itch` (or locally via `./tools/export_web.sh`).

## Run locally (editor)

```bash
godot --path .
# or
./.bin/godot --path .
```

Main scene: `scenes/main/boot.tscn`

## Export Web locally

Requires Godot **4.3** export templates installed (`~/.local/share/godot/export_templates/4.3.stable/`, including `web_nothreads_release.zip`).

```bash
./tools/export_web.sh
# → builds/web/index.html  (single-threaded Compatibility)
# → builds/itch/tea-in-the-hegemony-web.zip
```

Serve locally: `python3 -m http.server 8080 --directory builds/web` then open http://127.0.0.1:8080/

## Verify

```bash
./tools/run_tests.sh
```

## Docs

See [HANDOFF.md](HANDOFF.md) for architecture, how to play/add content, and browser publish status.
