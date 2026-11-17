---
"dsp" = "patch"
---

Fixed FTS Modulation failing to build on its own (`just plugins-bundle modulation`): its native UI now enables the tempo-sync parameters it uses instead of relying on another crate in the build to turn them on
