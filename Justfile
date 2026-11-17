# fts-fx: the effects. `just` lists the recipes.

default:
    @just --list

# cargo check of every crate and target
check:
    cargo check --workspace --all-targets --locked

# Every test (nextest does not run doctests; `cargo test --doc` does)
test:
    cargo nextest run --workspace --locked

# What Studio's web builds reach, checked for the browser: the effect
# engines and their painted UI (no plugin shell, no native windowing).
wasm_dsp_features := "align comp comp-profiles comp-ui comp-viz delay delay-profiles delay-ui delay-viz eq eq-analyzer eq-analyzer-ui eq-graph eq-graph-paint eq-profiles eq-ui level modulation modulation-profiles modulation-ui modulation-viz multiband pitch reverb reverb-profiles reverb-ui reverb-viz saturate saturate-analysis saturate-profiles saturate-ui saturate-viz stack stretch tune"

wasm-check:
    cargo check --locked -p dsp-core --target wasm32-unknown-unknown --features "audio loudness modulation"
    cargo check --locked -p fts-audio-ui --target wasm32-unknown-unknown --features shader
    cargo check --locked -p dsp --target wasm32-unknown-unknown --features "{{wasm_dsp_features}}"

# architect-ui is a git dependency with no stable path on disk: link the
# resolved checkout where the FX editors' tailwind.css files import it.
_architect-ui-link:
    #!/usr/bin/env bash
    set -euo pipefail
    ui=$(cargo metadata --locked --format-version 1 2>/dev/null \
        | python3 -c 'import json,sys,os; print(next(os.path.dirname(p["manifest_path"]) for p in json.load(sys.stdin)["packages"] if p["name"]=="architect-ui"))')
    ln -sfn "$ui" features/ui/.architect-ui

# The FX editors' embedded Tailwind sheets (the editor include_str!s
# assets/tailwind.css). Rebuild after class changes in the editor or in
# architect-ui.
tailwind-eq: _architect-ui-link
    tailwindcss -i features/dsp/eq/tailwind.css -o features/dsp/eq/assets/tailwind.css --minify

tailwind-comp: _architect-ui-link
    tailwindcss -i features/dsp/comp/tailwind.css -o features/dsp/comp/assets/tailwind.css --minify

tailwind-limiter: _architect-ui-link
    tailwindcss -i features/dsp/comp/ui_limiter-tailwind.css -o features/dsp/comp/ui_limiter-assets/tailwind.css --minify

tailwind-trigger: _architect-ui-link
    tailwindcss -i features/dsp/trigger/tailwind.css -o features/dsp/trigger/assets/tailwind.css --minify

tailwind-eq-standalone: _architect-ui-link
    tailwindcss -i apps/plugins/eq-standalone/tailwind.css -o apps/plugins/eq-standalone/assets/tailwind.css --minify

# THE plugin suite — the one list every plugin recipe iterates. A name here
# is `<name>-plugin` as a cargo package and "FTS <Name>" as a bundle (see
# bundler.toml); adding a plugin means touching this line and that file.
fts_plugins := "eq comp reverb delay tune modulation level saturate gate limiter trigger meter pitch unison"

# Bundle every FTS plugin as .clap + .vst3 (target/bundled/, names from
# bundler.toml). Pass a subset to bundle only those:
#   just plugins-bundle "eq comp"
# Debug of a single plugin: cargo run -p fts-plugin-xtask -- bundle -p eq-plugin
#
# On macOS this uses nice-plug-xtask's `bundle-universal` instead of
# `bundle`: it builds both aarch64-apple-darwin and x86_64-apple-darwin and
# lipo's them into one universal .clap/.vst3 per plugin — no custom lipo
# scripting needed. Requires the x86_64-apple-darwin rustc target
# (`rustup target add x86_64-apple-darwin`).
plugins-bundle plugins=fts_plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    cmd=bundle
    [ "$(uname)" = "Darwin" ] && cmd=bundle-universal
    for p in {{plugins}}; do
        # `export` (the CLAP/VST3 entry points) is a feature of each plugin.
        feat=(); grep -q '^export *=' "apps/plugins/$p/Cargo.toml" && feat=(--features export)
        cargo run -q -p fts-plugin-xtask -- "$cmd" -p "$p-plugin" --release "${feat[@]}"
    done
    ls target/bundled/

# Symlink the built bundles into this machine's user plugin dirs, so a rebuild
# is live in REAPER (and anything else that scans them) without reinstalling.
#
# Points at `target/bundled` rather than copying it. The bundler rewrites each bundle in place at a stable path, so the link stays
# valid across rebuilds — `just plugins-bundle eq` and the next plugin scan
# sees the new binary.
#
#   just plugins-link              # every bundle currently in target/bundled
#   just plugins-bundle eq && ...  # rebuild one; the link already points at it
#
# Idempotent, and deliberately conservative: it replaces its own symlinks but
# refuses to delete a REAL directory of the same name, which would be a copy
# installed by hand or by a release. Remove those yourself first —
# a plugin folder is not somewhere to be clever with rm -rf.
plugins-link:
    #!/usr/bin/env bash
    set -euo pipefail
    src="$(pwd)/target/bundled"
    [ -d "$src" ] || { echo "no target/bundled — run 'just plugins-bundle' first" >&2; exit 1; }
    case "$(uname)" in
        Darwin) clap_dir="$HOME/Library/Audio/Plug-Ins/CLAP"; vst3_dir="$HOME/Library/Audio/Plug-Ins/VST3";;
        *)      clap_dir="$HOME/.clap"; vst3_dir="$HOME/.vst3";;
    esac
    mkdir -p "$clap_dir" "$vst3_dir"
    linked=0; skipped=0
    for bundle in "$src"/*.clap "$src"/*.vst3; do
        [ -e "$bundle" ] || continue
        name="$(basename "$bundle")"
        case "$name" in *.clap) dest_dir="$clap_dir";; *) dest_dir="$vst3_dir";; esac
        dest="$dest_dir/$name"
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            printf "  SKIP  %-22s (a real copy is installed at %s)\n" "$name" "$dest_dir"
            skipped=$((skipped+1))
            continue
        fi
        rm -f "$dest"
        ln -s "$bundle" "$dest"
        printf "  link  %-22s -> %s\n" "$name" "$dest_dir"
        linked=$((linked+1))
    done
    echo "linked $linked bundle(s), skipped $skipped"

# Remove the symlinks `plugins-link` made, leaving any real installs alone.
plugins-unlink:
    #!/usr/bin/env bash
    set -euo pipefail
    src="$(pwd)/target/bundled"
    case "$(uname)" in
        Darwin) dirs=("$HOME/Library/Audio/Plug-Ins/CLAP" "$HOME/Library/Audio/Plug-Ins/VST3");;
        *)      dirs=("$HOME/.clap" "$HOME/.vst3");;
    esac
    for dir in "${dirs[@]}"; do
        [ -d "$dir" ] || continue
        for link in "$dir"/*.clap "$dir"/*.vst3; do
            [ -L "$link" ] || continue
            target="$(readlink "$link")"
            case "$target" in "$src"/*) rm -f "$link"; echo "  unlink $(basename "$link")";; esac
        done
    done

# Prove every bundle in target/bundled actually LOADS — dlopen it, run its
# entry point, and walk its factory (apps/plugins/verify/). A plugin that
# compiles, links, and exports the right symbol can still fail in a host: a
# missing dependency or a panicking init only shows up at load time, and
# `nm` cannot see either.
#
# Works on both platforms, including their different bundle shapes (Linux
# .clap is a bare shared object, macOS .clap is a directory) and different
# VST3 entry-point names (ModuleEntry vs bundleEntry). On macOS, pass an
# arch to run the universal binaries in one personality:
#   just plugins-verify              # native
#   just plugins-verify x86_64       # the Intel half, under Rosetta
plugins-verify arch="":
    #!/usr/bin/env bash
    set -euo pipefail
    [ -d target/bundled ] || { echo "no target/bundled — run 'just plugins-bundle' first" >&2; exit 1; }
    out="target/plugin-verify"; mkdir -p "$out"
    archflag=""
    [ -n "{{arch}}" ] && archflag="-arch {{arch}}"
    cc $archflag -o "$out/clap_load" apps/plugins/verify/clap_load.c -ldl
    cc $archflag -o "$out/vst3_load" apps/plugins/verify/vst3_load.c -ldl
    # The loadable binary inside a bundle, whatever shape the bundle is.
    binary_in() {
        if [ -d "$1" ]; then find "$1/Contents" -type f -perm -u+x ! -name "*.txt" ! -name "PkgInfo" | head -1
        else echo "$1"; fi
    }
    fail=0
    for b in target/bundled/*.clap target/bundled/*.vst3; do
        [ -e "$b" ] || continue
        case "$b" in *.clap) loader="$out/clap_load";; *) loader="$out/vst3_load";; esac
        bin="$(binary_in "$b")"
        if [ -z "$bin" ]; then printf "%-24s FAIL no binary in bundle\n" "$(basename "$b")"; fail=1; continue; fi
        result="$("$loader" "$bin" 2>&1 | tail -1)"
        printf "%-24s %s\n" "$(basename "$b")" "$result"
        case "$result" in OK*) ;; *) fail=1;; esac
    done
    [ "$fail" = 0 ] || { echo "FAILURES — some bundles do not load" >&2; exit 1; }
    echo "all bundles load"

# The models are the private FastTrackStudios/mic-models repository, read from
# $FTS_MIC_MODELS, else ~/.local/share/fts/mic-models. The default mic (LD-47K)
# is built into the plugin, so this is only needed for the other thirty-nine.
# Install or update the FTS Mic models for the plugin
mic-models-install:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="${FTS_MIC_MODELS:-${XDG_DATA_HOME:-$HOME/.local/share}/fts/mic-models}"
    if [ -d "$dest/.git" ]; then
        git -C "$dest" pull --ff-only
    elif [ -e "$dest" ]; then
        echo "$dest exists and is not a mic-models checkout; leaving it alone" >&2
        exit 1
    else
        mkdir -p "$(dirname "$dest")"
        git clone git@github.com:FastTrackStudios/mic-models.git "$dest"
    fi

# Package the plugin bundles as a single release tarball in dist/
# (fts-plugins-v<version>-<platform>.tar.gz + SHA256SUMS entry). The macOS
# release artifact is NOT this: Apple only accepts zip/pkg/dmg for
# notarization, and the signing script is still in Studio
# (studio:apps/session/desktop/ios/deploy-macos-plugins.sh), not ported here.
plugins-package: plugins-bundle
    #!/usr/bin/env bash
    set -euo pipefail
    version="$(cargo pkgid -p eq-plugin | sed 's/.*[#@]//')"
    case "$(uname)-$(uname -m)" in
        Darwin-*)        plat=macos ;;
        Linux-x86_64)    plat=x86_64-linux ;;
        Linux-aarch64)   plat=aarch64-linux ;;
        *) echo "unsupported platform: $(uname)-$(uname -m)" >&2; exit 1 ;;
    esac
    mkdir -p dist
    tarball="fts-plugins-v$version-$plat.tar.gz"
    tar -czf "dist/$tarball" -C target/bundled .
    (cd dist && sha256sum "$tarball" >> SHA256SUMS 2>/dev/null || sha256sum "$tarball" > SHA256SUMS)
    echo "packaged: dist/$tarball"
