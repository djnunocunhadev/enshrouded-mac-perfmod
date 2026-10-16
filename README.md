# Enshrouded on Mac: MoltenVK performance mod for CrossOver

A patched MoltenVK that roughly **doubles Enshrouded's frame rate** under CrossOver on Apple Silicon Macs, and lets the game start at all on CrossOver builds that ship an older MoltenVK.

| In-world, Apple M5 (16 GB), macOS 26, CrossOver Preview 27, Lowest preset, FSR3 Performance | Average | Median | Worst 5% |
|---|---|---|---|
| Stock MoltenVK main | 22.5 FPS | 21.9 | 18.8 |
| **This mod** | **39.0 FPS** | **39.3** | **34.6** |

Visuals were checked side by side and look the same. Your numbers will vary with your Mac, settings and where you are in the world. Bases with many buildings and lights are the heaviest scenes.

## What it fixes

**1. "No compatible graphics card found".** Enshrouded needs the Vulkan feature `drawIndirectCount`. CrossOver's bundled MoltenVK doesn't offer it, so the game refuses to start. This build is based on MoltenVK `main`, which added it in [KhronosGroup/MoltenVK#2775](https://github.com/KhronosGroup/MoltenVK/pull/2775). That version also pins a SPIRV-Cross release that compiles all of Enshrouded's shaders ([#2840](https://github.com/KhronosGroup/MoltenVK/issues/2840)).

**2. The slowdown.** Shaders mark some maths as "precise", meaning the compiler must not fuse or reorder those operations. SPIRV-Cross, the shader translator inside MoltenVK, honours that by routing every precise add, subtract and multiply through a helper function marked `[[clang::optnone]]`. That stops Metal from optimising or inlining those helpers at all. About 94% of Enshrouded's compute shaders use them, and one colour pass alone was taking ~4 ms per frame.

This mod removes `optnone` from **only those precise-math helpers**, and **only outside vertex shaders**. In vertex shaders, exactness across pipelines prevents flickering, so they keep it. The patch is [patches/0001-optimize-precise-math-helpers.patch](patches/0001-optimize-precise-math-helpers.patch), 23 lines.

Other `optnone` helpers are left alone. `spvMulExtended` relies on it to avoid a Metal compiler crash; `spvQuantizeToF16` and `spvReflect` use it to match Vulkan's exact results.

## Requirements

- An Apple Silicon Mac.
- CrossOver or CrossOver Preview with Enshrouded installed through Steam in a bottle.
- Tested on macOS 26 with CrossOver Preview 27 (Aug 2026).

## Install

1. Download `enshrouded-mac-perfmod.zip` from [Releases](../../releases) and unzip it.
2. **Quit** your game, Steam and CrossOver.
3. In Terminal, run:

```bash
cd ~/Downloads/enshrouded-mac-perfmod
bash install.sh
```

The installer:
- finds CrossOver and checks the download against `SHA256SUMS`;
- backs up CrossOver's original file to `~/Library/Application Support/CrossOver/moltenvk-perfmod-backup/`;
- swaps in the patched library.

If several CrossOver installs exist, pick one with `--app "/Applications/CrossOver Preview.app"`.

macOS may ask to let Terminal **modify apps**. Allow it in System Settings → Privacy & Security → App Management.

**After every CrossOver update, run `install.sh` again**, because updates replace the file.

### Uninstall

```bash
bash install.sh --restore
```

To switch the optimisation off without uninstalling, set `MVK_PERF_OPTIMIZE_PRECISE_MATH=0` in the bottle's environment variables.

## Recommended game settings

- **Window mode: Windowed**, then make it full screen the Mac way (green button or Ctrl+Cmd+F). Don't put `Borderless` in the settings file: the game rejects it and resets every setting to defaults.
- **Start from the Lowest preset with FSR3 Performance.** The High preset crashed on a 16 GB Mac when GPU memory ran out (`VK_ERROR_DEVICE_LOST`).
- **Cheap upgrades:** texture anisotropy High, contact shadows on, models Quality and shadows Medium together cost ~2–3 FPS on an M5.
- **Avoid:** decorative objects above Disabled (Medium cost ~8 FPS), point-light shadows above Lowest, dynamic GI High, tessellation.

## Known issues

- **Other games:** this replaces MoltenVK for every CrossOver bottle. Vulkan and DXVK games elsewhere use it too. D3DMetal games aren't affected. Use `--restore` if another game misbehaves.
- **No overlay:** the macOS Metal performance HUD (`MTL_HUD_ENABLED=1`) hangs Enshrouded on a black screen. Steam's FPS counter doesn't appear either.
- **Tearing:** don't set `MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE=2` or `MVK_CONFIG_SPECIALIZED_QUEUE_FAMILIES=1`. Under Rosetta they cause tearing-like artefacts.

## Build it yourself

```bash
scripts/build.sh
```

This clones MoltenVK at the pinned commit, applies `patches/`, builds, and writes `dist/libMoltenVK.dylib` and `SHA256SUMS`. It needs Xcode, and the first build takes 15–30 minutes. Release binaries are built by [GitHub Actions](.github/workflows/build.yml) from this same script, so you can check how they were made.

## Upstream

The proper fix belongs in SPIRV-Cross and MoltenVK, so every Vulkan game on Mac benefits and CrossOver can ship it. Upstream reports:

- SPIRV-Cross issue: *(link once filed)*
- MoltenVK [#2841](https://github.com/KhronosGroup/MoltenVK/issues/2841), the Enshrouded performance report: *(comment link once posted)*

## Licence

Apache License 2.0, the same as MoltenVK and SPIRV-Cross. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

This is an unofficial build, not affiliated with or endorsed by Khronos, The Brenwill Workshop, CodeWeavers or Keen Games. Use at your own risk.
