# fts-fx

The FastTrack Studio effects: the DSP (`dsp-core`, `dsp`), the plugin
shells and UI they need, and the CLAP/VST3 plugins they ship as.

Studio's engine links the same crates, so an effect sounds the same as a
plugin in any host and as a block in Studio.

## Where it came from

Split out of [FastTrackStudios/studio](https://github.com/FastTrackStudios/studio)
at commit `6019839d016f43964cca839472826f04373d957b` (2026-11-17), with the
history of each directory, as part of the split in
[studio#510](https://github.com/FastTrackStudios/studio/issues/510). The
paths are Studio's (`features/dsp`, `apps/plugins`, `features/ui/<crate>`).

Before the October 2026 merger this code lived in
[FastTrackStudios/processor](https://github.com/FastTrackStudios/processor);
that repo is the older copy and is not developed.

## Licence

GPL-3.0-or-later.
