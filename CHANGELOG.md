# Changelog

All notable changes to this project are documented in this file.

## [26.11.1] - 2026-11-17

### ⚙️ Miscellaneous Tasks

- *(release)* The signing Mac's job finds rustup (#5)
- *(release)* The Linux job installs the GTK and WebKit headers (#6)

## [26.11.0] - 2026-11-17

### Added

- FTS EQ: a dynamic band can ride on the programme (Relative) or on an external side-chain (signal)
- Added stacking to saturate, delay, reverb and EQ: up to 8 circuits, engines or spaces (4 EQ stages) in series or parallel, the same stack the compressor has, and saved presets load unchanged (signal)
- Added installers for the FTS plugins: a signed macOS .pkg (CLAP and VST3, Apple silicon and Intel), Linux and Windows archives with an install script, `just install` from source, and a release workflow that attaches them to each GitHub Release

### Fixed and improved

- Delay-line reads drop the integer modulo and the small conversion helpers inline across crates: Hall reverbs ~25% cheaper per instance, bit-identical output (session)
- FTS Mic's convolver partitions its kernels non-uniformly (64/256/1024/4096): one mic ~5x cheaper, still zero latency, output within float rounding (session)
- VU meters print their numerals along the arc, and the backlit console face prints them larger (signal)
- Fixed FTS Modulation failing to build on its own (`just plugins-bundle modulation`): its native UI now enables the tempo-sync parameters it uses instead of relying on another crate in the build to turn them on

