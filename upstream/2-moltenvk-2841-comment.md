<!-- Post as a comment on: https://github.com/KhronosGroup/MoltenVK/issues/2841 -->

I hit the same fixed per-frame cost with Enshrouded on an Apple M5 (macOS 26, CrossOver Preview 27, Rosetta 2), running MoltenVK main @ 5189f8de. I tracked most of it down to shader translation rather than encoding or synchronisation.

**Root cause:** SPIRV-Cross implements `NoContraction` with helpers marked `[[clang::optnone]]` (`spvFAdd`, `spvFSub`, `spvFMul` and the matrix variants), so Metal can't inline or optimise any precise add or multiply. About 94% of this game's compute shaders use them; one full-screen colour pass cost ~4 ms per frame because of it.

**Experiment:** in `MVKShaderModule.mm`, before compiling, I stripped `optnone` from those helpers in non-vertex shaders only, behind an env var. Same settings (Lowest, FSR3 Performance), in-world:

| | Avg | Median | Worst 5% |
|---|---|---|---|
| main @ 5189f8de | 22.5 | 21.9 | 18.8 |
| + precise-math helpers optimisable | **39.0** | **39.3** | **34.6** |

We saw no visual difference. Patch (23 lines): `https://github.com/djnunocunhadev/enshrouded-mac-perfmod/blob/main/patches/0001-optimize-precise-math-helpers.patch`. I've also reported it to SPIRV-Cross, where the real fix belongs: `<SPIRV-CROSS-ISSUE-URL>`.

**Things that did not help here,** measured with per-frame counters in an instrumented build:

- **The indirect-count prepass from this issue:** no measurable FPS difference on the M5. In the world the game issues about 50 `vkCmdDraw*IndirectCount` per frame, expanding to ~34k Metal draws through `maxDrawCount`.
- **Capping those empty draws to 64 per call:** no FPS change either, so zero-instance indirect draws seem cheap on Apple GPUs.
- **Keeping compute encoders open across pipeline barriers:** the game's barriers are all-stages to all-stages, causing ~420 compute encoder restarts per frame. Deferring them cut that to ~33 and gained ~5–7%, but caused visual glitches in my naive version.

Also, under Rosetta, `MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE=2` plus `MVK_CONFIG_SPECIALIZED_QUEUE_FAMILIES=1` gave me tearing-like artefacts even in composited full screen, so I'd be careful recommending them.
