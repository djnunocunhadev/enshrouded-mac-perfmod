<!-- Post on the CodeWeavers Enshrouded forum (https://www.codeweavers.com/compatibility/crossover/forum/enshrouded)
     and/or send to CodeWeavers support as a bug report. -->

**Title:** Enshrouded runs (~39 FPS on M5) with a newer MoltenVK. Two changes needed in CrossOver's MoltenVK.

Enshrouded currently stops with "no compatible graphics card found" in CrossOver Preview 27 on Apple Silicon. It works, and plays well, with two MoltenVK changes:

1. **A MoltenVK main build (after July 2026).** The game needs the Vulkan feature `drawIndirectCount`. The bundled MoltenVK (1.2.10) and release 1.4.2 report it as unsupported, and the game's own `enshrouded.log` says `skipping device because 'drawIndirectCount' is not supported!`. MoltenVK main added it in KhronosGroup/MoltenVK#2775, and main's pinned SPIRV-Cross compiles all of the game's shaders.

2. **Optimisable precise-math helpers.** SPIRV-Cross marks its precise-math helpers `[[clang::optnone]]`. Letting Metal optimise them outside vertex shaders took the game from 22.5 to 39 FPS on an M5. Patch and details: `https://github.com/djnunocunhadev/enshrouded-mac-perfmod`. Upstream reports: SPIRV-Cross `<SPIRV-CROSS-ISSUE-URL>`, MoltenVK #2841.

Working setup (Apple M5, 16 GB, macOS 26):
- Windowed mode plus macOS full screen.
- Lowest preset with FSR3 Performance. The High preset runs out of GPU memory on 16 GB.
- Don't use the Metal HUD (`MTL_HUD_ENABLED`): it hangs the game at startup.

It would be great if a future CrossOver could ship a MoltenVK with `drawIndirectCount`, and ideally the precise-math change too. Happy to test builds.
