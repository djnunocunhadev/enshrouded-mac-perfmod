<!-- r/macgaming (and optionally the Enshrouded Steam discussions). Flair: CrossOver / Guide. -->

**Title:** Enshrouded on Apple Silicon via CrossOver: fixed "no compatible graphics card" and nearly doubled FPS (22 → 39 on M5) with a MoltenVK mod

Enshrouded refuses to start in CrossOver ("no compatible graphics card found") because CrossOver's bundled MoltenVK doesn't support `drawIndirectCount`. I made a patched MoltenVK that fixes that and also makes the game much faster.

**Results** (M5 16 GB, Lowest preset, FSR3 Performance, in-world): **22.5 → 39 FPS average**, and the worst 5% went from 18.8 to 34.6.

**Why it's faster:** the shader translator inside MoltenVK makes every "precise" maths operation an unoptimisable function call. The mod lets Metal optimise those, except in vertex shaders. It's a 23-line patch.

**Get it:** `https://github.com/djnunocunhadev/enshrouded-mac-perfmod`
- Download the release, quit CrossOver, run `bash install.sh`. It backs up the original, and `install.sh --restore` undoes it.
- Release binaries are built by GitHub Actions from the official MoltenVK source plus the patch, so you can see exactly what you're running.
- Re-run the installer after CrossOver updates.

**Settings tips:**
- Windowed mode, then Ctrl+Cmd+F for full screen.
- Start from Lowest. The High preset crashes on 16 GB Macs.
- Anisotropy High, contact shadows, Quality models and Medium shadows cost only ~2–3 FPS. Decorative objects are expensive.

It's unofficial and use-at-your-own-risk. I've also reported the root cause to SPIRV-Cross and MoltenVK so it can be fixed properly.
