<!-- File at: https://github.com/KhronosGroup/SPIRV-Cross/issues/new -->

**Title:** MSL: `[[clang::optnone]]` on NoContraction helpers (spvFAdd / spvFSub / spvFMul*) causes a ~1.7x GPU slowdown in a real game

### Summary

To honour `DecorationNoContraction` under fast-math, the MSL backend routes precise float operations through helper functions marked `[[clang::optnone]]`, added in fb3defc9 (2021-09-23). The affected helpers are `spvFAdd`, `spvFSub`, `spvFMul`, `spvFMulVectorMatrix`, `spvFMulMatrixVector` and `spvFMulMatrixMatrix`. For example:

```metal
template<typename T>
[[clang::optnone]] T spvFAdd(T l, T r)
{
    return fma(T(1), l, r);
}
```

`optnone` stops the Metal compiler from optimising *and inlining* these helpers. So every precise add or multiply becomes an unoptimised function call. That's fine for occasional use, but GPU-driven engines mark large parts of their compute shaders as precise.

### Measurements

The game is Enshrouded (Vulkan-only), running through MoltenVK (main @ 5189f8de, SPIRV-Cross aa217aeb) under CrossOver/Wine. The machine is an Apple M5 on macOS 26.

- 3,512 of the game's 7,660 translated pipelines call `spvFMul`, and similar numbers call `spvFAdd`/`spvFSub`. That's about 94% of its compute shaders. One full-screen colour pass took ~4 ms per frame because of this.
- **Experiment:** we removed `[[clang::optnone]]` from those six helpers in every *non-vertex* shader, at load time in MoltenVK. Vertex shaders were left unchanged because of position invariance. In-world frame rate went from **22.5 to 39.0 FPS on average** (median 21.9 → 39.3, worst 5% 18.8 → 34.6) at identical settings. We saw no visual difference.
- The game never used `spvMulExtended`, `spvQuantizeToF16` or `spvReflect`, so the experiment didn't touch them. We understand their `optnone` exists for different reasons (a Metal compiler crash workaround and conformance results).

The patch is a load-time string rewrite in MoltenVK, so it's only a proof of concept: `https://github.com/djnunocunhadev/enshrouded-mac-perfmod/blob/main/patches/0001-optimize-precise-math-helpers.patch`

### Question / suggestion

Could precise maths be honoured without blocking all optimisation? Some options:

- an `msl_options` flag to drop `optnone` from the NoContraction helpers in non-vertex stages, where invariance across pipelines isn't required;
- or a way to prevent contraction that still lets the helper inline (for example a contraction-off pragma scoped to the helper, if the Metal compiler honours it).

We don't know which approach you'd prefer, or whether Metal offers a cheaper way to stop fusion. Happy to test candidate changes on this workload.
