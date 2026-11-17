# fts-fx — Repo Instructions

**fts-fx is FastTrack Studio's effects**: the DSP, the UI the effects
draw and the CLAP/VST3 plugins. It was split out of
FastTrackStudios/studio at `6019839d0` (studio#510); the rules below are
Studio's, trimmed to what applies here.

**This repo never depends on Studio, not even by git.** Studio depends on
it, so that would be a cycle. If an effect needs something from a product,
the dependency points the wrong way: the product adapts to the effect.

## Crate rules

- **One crate per feature, with cargo features**, not `-proto` / `-ui` /
  `-dsp` sibling crates. Every effect is a module and a cargo feature of
  the one `dsp` crate (`eq`, `eq-native`, `eq-ui`, `eq-profiles`, …).
- **Path deps inside the repo, declared once** in the root
  `[workspace.dependencies]` and consumed as `x.workspace = true`.
  `default-features = false` cannot be set on a workspace-inherited dep:
  put it on the `[workspace.dependencies]` entry.
- **Git deps across repos, pinned** to a tag or a rev (architect, the
  `vendor` repo, the FTS blitz fork). The one branch pin is nice-plug's
  `fts-baseview-03`. Keep versions, pins and `[patch]` entries the same as
  Studio's: Studio links these crates, and two different pins of blitz,
  dioxus or architect in its lockfile do not build.
- **Co-developing with Studio**: in the Studio checkout, override this
  repo with a local path and never commit it:
  `[patch."https://github.com/FastTrackStudios/fts-fx"] dsp = { path = "../fts-fx/features/dsp" }`
  (one line per crate Studio takes).
- **`include_str!` across a repo boundary does not work** (a git dep has
  no stable path on disk). Export the bytes from the owning crate.

## Plugin and DSP rules

**GUI rendering**: plugin UI renders identically standalone, as a
CLAP/VST3 editor and embedded in a host, through one pipeline:
`nice-plug-dioxus` / `dioxus_native` → Blitz (Vello + wgpu).

- Never `dioxus::desktop::LaunchBuilder` for this UI.
- **Inline styles only**: Blitz does not load external stylesheets.
  Inline `style`, or a static string via `document::Style { {CSS} }`;
  `include_str!` a compiled sheet. Components must lay out correctly
  without Tailwind; classes are additive only.
- Root `App` components take no props (context via
  `use_context_provider`), so one component serves standalone and as a
  plugin editor.
- Blitz's gaps: no `position: fixed`/`sticky`, no `overflow: auto` (use
  `overflow-y: scroll` or `hidden`), no `text-overflow`, no CSS
  `fill`/`stroke` on SVG, no `vertical-align`, `text-shadow`, blend modes,
  3D transforms, multi-column or container queries. Inside a plugin
  `use_effect` never runs, `autofocus` is ignored unless the node is
  already in the document, `MountedData::set_focus` panics from an event
  handler, and there is no `placeholder`.

**Processing cores** (the engines in `features/dsp/*`) build for native,
WASM/AudioWorklet and embedded `no_std`: `#![no_std]` + `alloc` (gate
`std` behind an additive feature); no heap allocation on the hot path
(pre-allocate in `reset()`; `process()` never calls `Vec::push` /
`Box::new`); no threads and no task spawning; no platform I/O.

**Parameters must parse the string they print**: a host's parameter list
is text in, text out; each effect's `tests/param_round_trip.rs` holds that
line. Tempo-synced times use `dsp_core::time`; do not grow a second table.

**Realtime lints**: `features/dsp/clippy.toml` adds the audio-thread rules
(`disallowed-methods` for locks, `env::var`, sleeps; `too-large-for-stack`).
Clippy reads the nearest `clippy.toml`; keep its shared settings in step
with the root one.

**Logging**: never `println!` / `eprintln!` / `dbg!` in library code; use
`tracing` with structured fields.

## Build

Rust 1.99.1 (`rust-toolchain.toml`). kache is the rustc wrapper, set by
the fleet in `~/.cargo/config.toml`, never in this repo; keep keys stable
(no `env!("CARGO_MANIFEST_DIR")` outside tests, target dirs named
`target`).

Dependencies build at opt-level 1 in dev, with an allowlist back at 3 for
audio-thread crates (`dsp-core`, `dsp` and the FFT crates). Extend the
allowlist; never raise `package."*"`.

## Licence

**GPL-3.0-or-later.** A new crate inherits it with
`license.workspace = true`. Incoming code must be GPL-compatible.

## Process

Branch from `origin/main`, open a PR into `main` with a conventional
title. A lone PR squash-merges.
