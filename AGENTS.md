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

## Build and test

Every build runs in the fleet's devenv shell: `devenv shell -- <command>`, or
direnv through `.envrc` (`eval "$(devenv direnvrc)"` then `use devenv`; a bare
`use devenv` fails silently in an agent shell and leaves the host's rustc).
devenv-fleet's `rust` module (imported in `devenv.yaml`) is the toolchain:
check it with `devenv shell -- fleet-doctor` (the rustc store path, the
wrapper, the linker; it fails off the pin). `devenv.nix` adds what the
plugins link. Move the pins only with devenv-fleet's
`scripts/fleet-pins --write .`, never by hand; never set or unset
`RUSTC_WRAPPER` or `CARGO_HOME`.

```bash
just check             # cargo check --workspace --all-targets
just test              # cargo nextest run --workspace
just wasm-check        # dsp-core, fts-audio-ui and dsp for wasm32-unknown-unknown
just plugins-bundle [names] && just plugins-link   # .clap/.vst3 into target/bundled, linked into the plugin folders
just install [names]   # or copied there, replacing older copies
just plugins-verify    # every bundle loads
```

A PR gets one free job, `PR checks` (`.github/workflows/pr.yml`: fmt and
the lockfile; it compiles nothing). Run the three recipes above before
pushing: nothing else does. It runs on ready PRs only (skipped on a
draft): mark the PR ready (`gh pr ready`) to get it.

Studio pins this repo by `rev` (`studio:Cargo.toml`). A change Studio
needs lands here first, then Studio moves its rev. Do not rename or remove
a crate, a cargo feature or public API that Studio uses without the
matching Studio PR: `builtin`, `daw-standalone`, the rigs and the apps
link `dsp`, `dsp-core`, `fts-audio-ui`, `plugin-core` and the plugin
crates.

Rust 1.99.1: the devenv shell's (devenv-fleet), and `rust-toolchain.toml`
for rustup outside it. kache is the rustc wrapper, the host's (the fleet's
`~/.cargo/config.toml`, or the `rust` module exporting it from PATH), never
set in this repo; keep `.cargo/config.toml`'s rustflags tables as they are
(the fleet's, flag for flag) and keep keys stable
(no `env!("CARGO_MANIFEST_DIR")` outside tests, target dirs named
`target`).

Dependencies build at opt-level 1 in dev, with an allowlist back at 3 for
audio-thread crates (`dsp-core`, `dsp` and the FFT crates). Extend the
allowlist; never raise `package."*"`.

## Installers and releases

- **The suite is the Justfile's `fts_plugins` list.** `plugins-bundle`,
  `install`, `plugins-pkg` and `plugins-package` all take it, and the
  installers copy only those bundles out of `target/bundled`, never
  "whatever is there". A new plugin goes into that list and
  `bundler.toml`; nothing else lists plugins.
- **FTS Mic is not in any installer, and no installer, release asset or
  commit may carry its models.** They are private (`mic-models`, measured
  from a commercial product) and `apps/plugins/mic/build.rs` builds the
  default one into the binary when it finds them, so a `mic` bundle built
  on a machine with the models IS private data. Shipping FTS Mic is the
  owner's decision and needs a build that cannot see the models.
- **macOS** (`scripts/macos/`, ported from Studio's
  `deploy-macos-plugins.sh` / `deploy-macos-pkg.sh`): universal bundles,
  Developer ID Application + hardened runtime, one `.pkg` signed with
  Developer ID Installer, one component per plugin with Studio's stable ids
  (`app.fasttrackstudio.plugin.<slug>`; never change them, they are what
  upgrades in place). Signing identities live only in the build keychain
  (`fts-build.keychain` on the release Mac); never commit an identity, a
  certificate, a key or the notarization config.
- **Notarizing submits to Apple**: only the release workflow and the owner
  do it (`NOTARIZE=1 just plugins-pkg`, or `scripts/macos/notarize.sh
  <pkg>`; `DRY_RUN=1` checks without submitting).
- **Linux / Windows**: an archive with `install.sh` / `install.ps1`
  (`scripts/package.sh`). The Linux release builds on THEBATTLESHIP's
  self-hosted pool (NixOS, no apt) inside the devenv shell, so a library a
  plugin newly links on Linux goes into `devenv.nix`, or the release breaks.
- **Releases** follow the fleet flow, copied from patchbay
  (`scripts/release.sh`): CalVer `YY.M.MICRO` in `[workspace.package]
  version`, change files in `.changes/`, `just release-prepare` →
  `release-pr` → `release-merge` → `release-tag`. The tag runs
  `.github/workflows/release.yml`, which builds the three installers and
  publishes the Release with them. Never create a tag or a release by
  hand, and never move a tag.
- `release.yml`'s build jobs are self-hosted (macOS on the release Mac,
  Linux on THEBATTLESHIP) and build through `devenv shell -- …`. This repo
  is public: they must stay tag-only (a `v*` tag of this repo, or a
  maintainer's dispatch on one; `needs: tag-guard` plus the same `if:`; no
  `pull_request` trigger on a self-hosted job), and the guard runs the base
  commit's `release.sh`. `scripts/macos/` run Apple's tools from /usr/bin
  without the shell's nix SDK (DEVELOPER_DIR, SDKROOT); keep it that way.

## Licence

**GPL-3.0-or-later.** A new crate inherits it with
`license.workspace = true`. Incoming code must be GPL-compatible.

## Process

Branch from `origin/main`, open a PR into `main` with a conventional
title. A lone PR squash-merges; an import that carries history merges with
a merge commit. A change a user would notice adds a change file
(`.changes/README`).
