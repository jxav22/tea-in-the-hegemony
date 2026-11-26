# Tea in the Hegemony

Narrative social-espionage RPG — chapter **The Reception**.

Godot **4.3**, **Compatibility** renderer (browser-friendly), typed GDScript.

## Play in browser

**Live (GitHub Pages):** [https://jxav22.github.io/tea-in-the-hegemony/](https://jxav22.github.io/tea-in-the-hegemony/)

> If that URL 404s, Pages is not enabled yet or the first deploy is still running. See **Publish / Pages** in [HANDOFF.md](HANDOFF.md). Workflow: `.github/workflows/web-pages.yml`.

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
