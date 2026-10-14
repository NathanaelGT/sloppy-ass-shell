#!/usr/bin/env bash
set -u

src="$1"
outdir="$2"
key="$3"

for dir in /nix/store/*-coreutils-*/bin /nix/store/*-gnugrep-*/bin /nix/store/*-squashfs-*/bin; do
  if [ -d "$dir" ]; then
    PATH="$dir:$PATH"
  fi
done
export PATH

locate() {
  local name="$1"
  local found
  found="$(command -v "$name" 2>/dev/null)"
  if [ -n "$found" ]; then
    printf '%s' "$found"
    return 0
  fi
  local candidate
  for candidate in /nix/store/*-*/bin/"$name"; do
    if [ -x "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
}

sha_bin="$(locate sha256sum)"
unsquashfs_bin="$(locate unsquashfs)"
readlink_bin="$(locate readlink)"

[ -f "$src" ] || exit 0
[ -n "$sha_bin" ] || exit 0
[ -n "$unsquashfs_bin" ] || exit 0
[ -n "$readlink_bin" ] || exit 0

cache="${XDG_CACHE_HOME:-$HOME/.cache}/appimage-run/$("$sha_bin" "$src" | cut -d' ' -f1)"
root="$cache"
scratch=""
offset=""

if [ ! -d "$root" ]; then
  for candidate in $(LC_ALL=C grep -abo 'hsqs' "$src" | cut -d: -f1); do
    if "$unsquashfs_bin" -o "$candidate" -s "$src" >/dev/null 2>&1; then
      offset="$candidate"
      break
    fi
  done
  [ -n "$offset" ] || exit 0
  scratch="$(mktemp -d)"
  root="$scratch"
  "$unsquashfs_bin" -q -d "$scratch" -o "$offset" "$src" .DirIcon '*.desktop' >/dev/null 2>&1
fi

desktop="$(ls "$root"/*.desktop 2>/dev/null | head -1)"
name=""
version=""

if [ -n "$desktop" ]; then
  name="$(grep -m1 '^Name=' "$desktop" | cut -d= -f2-)"
  version="$(grep -m1 '^X-AppImage-Version=' "$desktop" | cut -d= -f2-)"
fi

icon=""

if [ -L "$root/.DirIcon" ]; then
  member="$("$readlink_bin" "$root/.DirIcon" 2>/dev/null)"
  if [ -n "$member" ] && [ ! -f "$root/$member" ] && [ -n "$offset" ]; then
    "$unsquashfs_bin" -q -d "$scratch" -o "$offset" "$src" "$member" >/dev/null 2>&1
  fi
  if [ -n "$member" ] && [ -f "$root/$member" ]; then
    icon="$root/$member"
  fi
elif [ -f "$root/.DirIcon" ]; then
  icon="$root/.DirIcon"
elif [ -n "$desktop" ]; then
  iconname="$(grep -m1 '^Icon=' "$desktop" | cut -d= -f2-)"
  if [ -n "$iconname" ]; then
    icon="$(find "$root" -path '*/icons/*' -iname "$iconname.*" -type f 2>/dev/null | head -1)"
  fi
fi

dest=""

if [ -n "$icon" ] && [ -f "$icon" ]; then
  mkdir -p "$outdir"
  dest="$outdir/$key.${icon##*.}"
  cp -f "$icon" "$dest" 2>/dev/null || dest=""
fi

[ -n "$scratch" ] && rm -rf "$scratch"
printf '%s\n%s\n%s\n%s' "$src" "$dest" "$name" "$version"
