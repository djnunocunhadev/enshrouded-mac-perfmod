#!/bin/bash
# Install (or restore) the patched libMoltenVK.dylib into CrossOver.
#
#   ./install.sh                     install ./libMoltenVK.dylib (or dist/libMoltenVK.dylib)
#   ./install.sh path/to/libMoltenVK.dylib
#   ./install.sh --restore           put CrossOver's original MoltenVK back
#   ./install.sh --app "/Applications/CrossOver Preview.app" ...   pick a specific CrossOver
#
# CrossOver updates replace this file, so run the installer again after updating CrossOver.
set -euo pipefail

BACKUP_DIR="$HOME/Library/Application Support/CrossOver/moltenvk-perfmod-backup"
HERE="$(cd "$(dirname "$0")" && pwd)"
RESTORE=0; APP=""; SRC=""

while (( $# )); do
  case "$1" in
    --restore) RESTORE=1 ;;
    --app) APP="$2"; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) SRC="$1" ;;
  esac
  shift
done

die() { echo "error: $*" >&2; exit 1; }

# Find CrossOver.
if [[ -z "$APP" ]]; then
  candidates=()
  for a in "/Applications/CrossOver.app" "/Applications/CrossOver Preview.app" \
           "$HOME/Applications/CrossOver.app" "$HOME/Applications/CrossOver Preview.app"; do
    [[ -d "$a" ]] && candidates+=("$a")
  done
  (( ${#candidates[@]} )) || die "CrossOver not found. Pass --app \"/path/to/CrossOver.app\"."
  if (( ${#candidates[@]} > 1 )); then
    echo "Several CrossOver installs found:"; printf '  %s\n' "${candidates[@]}"
    die "pick one with --app \"...\""
  fi
  APP="${candidates[0]}"
fi
# Where CrossOver keeps MoltenVK differs between versions:
#   lib/x86_64/  CrossOver Preview 27
#   lib64/       CrossOver 26.3 (reported in issue #1)
# Fall back to searching the bundle, accepting only a library with an x86_64 slice
# (the architecture Wine loads under Rosetta).
CXDIR="$APP/Contents/SharedSupport/CrossOver"
TARGET=""
for t in "$CXDIR/lib/x86_64/libMoltenVK.dylib" "$CXDIR/lib64/libMoltenVK.dylib"; do
  [[ -f "$t" ]] && { TARGET="$t"; break; }
done
if [[ -z "$TARGET" ]]; then
  found=()
  while IFS= read -r f; do
    lipo -info "$f" 2>/dev/null | grep -q x86_64 && found+=("$f")
  done < <(find "$CXDIR" -name libMoltenVK.dylib -type f 2>/dev/null)
  (( ${#found[@]} )) || die "no libMoltenVK.dylib found inside $CXDIR"
  if (( ${#found[@]} > 1 )); then
    echo "Several MoltenVK copies found:"; printf '  %s\n' "${found[@]}"
    die "please report this at https://github.com/djnunocunhadev/enshrouded-mac-perfmod/issues"
  fi
  TARGET="${found[0]}"
fi
echo "MoltenVK in this CrossOver: $TARGET"

VERSION="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)"
APPNAME="$(basename "$APP" .app | tr ' ' '-')"
BACKUP="$BACKUP_DIR/$APPNAME-$VERSION-libMoltenVK.original.dylib"

# Replacing a library that running Wine processes have loaded can crash them.
if pgrep -qf "wineserver|CrossOver.*/wine" ; then
  die "CrossOver programs are running. Quit your games, Steam and CrossOver first."
fi

install_file() {   # atomic replace, so a half-written file is never loaded
  local from="$1" exact="${2:-0}"   # exact=1: restore the original byte for byte
  local tmp="$(dirname "$TARGET")/.libMoltenVK.new"
  if (( exact )); then
    cp -p "$from" "$tmp"; mv -f "$tmp" "$TARGET"; return
  fi
  if lipo -info "$TARGET" | grep -q "Non-fat"; then
    lipo "$from" -thin x86_64 -output "$tmp" 2>/dev/null || cp "$from" "$tmp"
  else
    cp "$from" "$tmp"
  fi
  xattr -c "$tmp" 2>/dev/null || true
  codesign --force --sign - "$tmp" >/dev/null 2>&1 || true
  mv -f "$tmp" "$TARGET"
}

if (( RESTORE )); then
  [[ -f "$BACKUP" ]] || die "no backup for $APPNAME $VERSION in $BACKUP_DIR"
  install_file "$BACKUP" 1
  echo "Restored CrossOver's original MoltenVK in $APP."
  exit 0
fi

# Locate the patched dylib: argument, next to this script (release zip), or dist/ (local build).
if [[ -z "$SRC" ]]; then
  for c in "$HERE/libMoltenVK.dylib" "$HERE/../dist/libMoltenVK.dylib"; do
    [[ -f "$c" ]] && { SRC="$c"; break; }
  done
fi
[[ -n "$SRC" && -f "$SRC" ]] || die "patched libMoltenVK.dylib not found; pass its path"
lipo -info "$SRC" | grep -q x86_64 || die "$SRC has no x86_64 slice (CrossOver runs games as x86_64)"

SUMS="$(dirname "$SRC")/SHA256SUMS"
if [[ -f "$SUMS" ]]; then
  (cd "$(dirname "$SRC")" && shasum -a 256 -c SHA256SUMS) || die "checksum mismatch for $SRC"
fi

mkdir -p "$BACKUP_DIR"
if [[ ! -f "$BACKUP" ]]; then
  cp -p "$TARGET" "$BACKUP"
  echo "Backed up CrossOver's original MoltenVK to: $BACKUP"
fi

install_file "$SRC"
echo "Installed patched MoltenVK into $APP ($VERSION)."
echo "To undo: $0 --restore"
