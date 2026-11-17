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
just plugins-link      # link them into this machine's plugin folders
just plugins-verify    # dlopen every bundle and walk its factory
```

FTS Mic builds its default mic in when it finds the private models
(`$FTS_MIC_MODELS`, `~/.local/share/fts/mic-models`, or
`apps/plugins/mic/models`); without them the plugin builds and needs the
models installed (`just mic-models-install`).

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
