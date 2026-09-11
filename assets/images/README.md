# Layer assets

Silhouette layers produced by `tools/silhouette.py`, loaded by
`ParallaxComponent`. Flame repeats each layer horizontally
(`ImageRepeat.repeatX` is the default), so every file here must be
**seamless under horizontal repeat** — pass `--tile` and check the
`*_tilecheck.png` the tool writes with `--verify`.

Naming: `layer_<depth>_<subject>.png`, far to near — e.g. `layer_far_treeline.png`,
`layer_mid_rooftank.png`, `layer_fg_fronds.png`.

Keep each file under 2048px wide (the safe texture size across budget
Android devices) and prefer power-of-two widths (`--pot`).
