# fts-fx

The FastTrack Studio effects: the DSP, the UI the effects draw, and the
CLAP/VST3 plugins they ship as.

Studio's engine links the same crates, so an effect sounds the same as a
plugin in any host and as a block in Studio.

## What is here

```
features/dsp/core          dsp-core: the shared DSP primitives (filters, time,
                           loudness, modulation), no_std
features/dsp               dsp: every effect and its engine, one module and one
                           cargo feature each (eq, comp, reverb, delay,
                           saturate, modulation, pitch, tune, gate, level,
                           mic, trigger, stretch, align, …; `-ui`, `-viz`,
                           `-native`, `-profiles` beside each)
features/ui/fts-audio-ui   knobs, meters, faders, the painted audio widgets
features/ui/plugin-core    the plugin shell: editor window, params, chrome
features/preset-browser    presets: storage, browsing, its panel
apps/plugins/<name>        the CLAP/VST3 plugins (`<name>-plugin`): comp, delay,
                           eq, gate, level, limiter, meter, mic, modulation,
                           pitch, reverb, saturate, trigger, tune, unison;
                           eq-standalone (the EQ in a window); verify/ (bundle
                           load checks)
xtask/plugins              the bundler (wraps nice-plug-xtask)
```

## Build

Rust 1.99.1 (`rust-toolchain.toml`).

```bash
just check             # cargo check --workspace --all-targets
just test              # cargo nextest run --workspace
just wasm-check        # the engines and painted UI for wasm32-unknown-unknown
just plugins-bundle    # .clap + .vst3 into target/bundled (universal on macOS)
just install           # copy them into your plugin folders (below)
just plugins-link      # or link them there, so a rebuild is live
just plugins-verify    # dlopen every bundle and walk its factory
```

FTS Mic builds its default mic in when it finds the private models
(`$FTS_MIC_MODELS`, `~/.local/share/fts/mic-models`, or
`apps/plugins/mic/models`); without them the plugin builds and needs the
models installed (`just mic-models-install`).

## Installing the plugins

The installers hold fourteen plugins, each as CLAP and VST3: FTS EQ, Comp,
Limiter, Gate, Level, Meter, Reverb, Delay, Modulation, Saturate, Pitch,
Tune, Unison and Trigger. FTS Mic is not in them (see below).

### From a release

Download from [Releases](https://github.com/FastTrackStudios/fts-fx/releases):

| Platform | File | Installs into |
| --- | --- | --- |
| macOS 11+, Apple silicon and Intel | `FTS-Plugins-<version>-macos.pkg` (signed, notarized) | `/Library/Audio/Plug-Ins/{CLAP,VST3}` for every user, or `~/Library/Audio/Plug-Ins/{CLAP,VST3}` if you choose "just me" |
| Linux x86-64 (AVX2) | `fts-plugins-<version>-linux-x86_64.tar.gz` | `./install.sh`: `~/.clap`, `~/.vst3`; `sudo ./install.sh --system`: `/usr/lib/clap`, `/usr/lib/vst3` |
| Windows x64 (AVX2) | `fts-plugins-<version>-windows-x86_64.zip` | `install.ps1`: `%LOCALAPPDATA%\Programs\Common\{CLAP,VST3}`; `-System` (as administrator): `%COMMONPROGRAMFILES%\{CLAP,VST3}` |

`SHA256SUMS` beside them lists every file's checksum. A newer installer
replaces the plugins an older one installed; quit your host first, then
rescan its plugins. On macOS, Customize picks plugins one by one; unattended:

```bash
sudo installer -pkg FTS-Plugins-<version>-macos.pkg -target /                    # every user
installer -pkg FTS-Plugins-<version>-macos.pkg -target CurrentUserHomeDirectory  # just you, no password
```

The x86-64 builds need a CPU with AVX2 (Intel Haswell / AMD Excavator, 2013,
and later).

### From source

```bash
just plugins-bundle             # every plugin, .clap + .vst3, into target/bundled
just install                    # copy them into your plugin folders, replacing older copies
just install "eq comp"          # or some of them (`just plugins-bundle "eq comp"` first)
just install "eq" --dry-run     # say what would go where
```

`just install` uses the per-user folders: `~/Library/Audio/Plug-Ins/{CLAP,VST3}`
on macOS, `~/.clap` and `~/.vst3` on Linux. On macOS the bundles are
universal and need both Rust targets (`rustup target add x86_64-apple-darwin`).
The builds are not signed with a Developer ID; that is fine on the Mac that
built them.

The installers themselves: `just plugins-pkg` (macOS: signs with the
Developer ID identities in the build keychain, `PKG_UNSIGNED=1` without
them), `just plugins-package` (Linux, Windows). Releases are cut with
`just release-*` (`scripts/release.sh`); the tag builds and attaches the
installers (`.github/workflows/release.yml`).

### FTS Mic

FTS Mic models a microphone from measured models that are private (they
come from a commercial product), so no public installer carries it, and the
installers are built from a list that leaves it out rather than from
whatever is in `target/bundled`. With access to the private
`mic-models` repository: `just mic-models-install`, then
`just plugins-bundle mic && just install mic`.

## Where it came from

Split out of [FastTrackStudios/studio](https://github.com/FastTrackStudios/studio)
at commit `6019839d016f43964cca839472826f04373d957b` (2026-11-17), with the
history of each directory, as part of the split in
[studio#510](https://github.com/FastTrackStudios/studio/issues/510). The
paths are Studio's.

Not here, still in Studio: `builtin` (the effects as blocks of Studio's
engine; it needs the engine), `signal-nam`, and the plugins that need the
sampler, the session or the engine (nam, signal, sampler, guide, the CLAP
host). This repo never depends on Studio; Studio depends on it by git
`rev`. Working on both at once: `studio:docs/fts-fx.md`.

Before the October 2026 merger this code lived in
[FastTrackStudios/processor](https://github.com/FastTrackStudios/processor);
that repo is the older copy and is not developed.

## Licence

GPL-3.0-or-later.
