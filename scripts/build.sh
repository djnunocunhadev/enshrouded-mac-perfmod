#!/bin/bash
# Build the patched MoltenVK from official source.
#
#   scripts/build.sh            -> dist/libMoltenVK.dylib (universal) + dist/SHA256SUMS
#
# Needs Xcode (command line tools alone are not enough), git and python3.
# The first build fetches and compiles MoltenVK's dependencies and takes 15-30 minutes.
set -euo pipefail

# MoltenVK main at a commit that has drawIndirectCount support (KhronosGroup/MoltenVK#2775),
# which Enshrouded requires, and a SPIRV-Cross revision that compiles all of its shaders.
MOLTENVK_REPO="https://github.com/KhronosGroup/MoltenVK.git"
MOLTENVK_REF="${MOLTENVK_REF:-5189f8de86ec365860f63bf1da736815cfaea5cd}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$ROOT/build}"
SRC="$WORK/MoltenVK"
DIST="$ROOT/dist"

mkdir -p "$WORK" "$DIST"
# Initialise in place rather than cloning: CI restores a dependency cache into
# $SRC/External first, so $SRC may already exist without a checkout.
if [[ ! -d "$SRC/.git" ]]; then
  mkdir -p "$SRC"
  git -C "$SRC" init --quiet
  git -C "$SRC" remote add origin "$MOLTENVK_REPO"
fi
git -C "$SRC" fetch --quiet --filter=blob:none origin "$MOLTENVK_REF"
git -C "$SRC" checkout --quiet --force "$MOLTENVK_REF"
git -C "$SRC" reset --quiet --hard
for p in "$ROOT"/patches/*.patch; do
  echo "Applying $(basename "$p")"
  git -C "$SRC" apply "$p"
done

cd "$SRC"
./fetchDependencies --macos
make macos

OUT="$SRC/Package/Release/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib"
cp "$OUT" "$DIST/libMoltenVK.dylib"
cd "$DIST"
shasum -a 256 libMoltenVK.dylib > SHA256SUMS
lipo -info libMoltenVK.dylib
cat SHA256SUMS
echo "Built from MoltenVK $MOLTENVK_REF with $(ls "$ROOT"/patches/*.patch | wc -l | tr -d ' ') patch(es)."
