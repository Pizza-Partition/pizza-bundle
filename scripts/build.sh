#!/usr/bin/env bash
set -euo pipefail
cd /src
# pacman owns dependency resolution, package signature checking and extraction.
mkdir -p /runtime/var/lib/pacman /runtime/etc /empty-hooks
cp /etc/resolv.conf /runtime/etc/resolv.conf
mapfile -t packages < config/packages.txt
pacman --root /runtime --dbpath /runtime/var/lib/pacman \
  --gpgdir /etc/pacman.d/gnupg --cachedir /var/cache/pacman/pkg \
  --hookdir /empty-hooks --noscriptlet --noconfirm --needed -Sy "${packages[@]}"
root=/build/pizza-runtime
mkdir -p "$root" /out
cp -a /runtime/usr/{bin,lib,share} "$root/"
# Keep runtime resources/plugins/licenses wholesale; no hand-written dependency walker.
rm -rf "$root/share/man" "$root/share/info"
# Convert package-owned absolute /usr symlinks to bundle-relative links.
# Keep documentation because some upstream license files link into share/doc.
while IFS= read -r -d '' link; do
  target=$(readlink -- "$link")
  if [[ $target == /* ]]; then
    [[ $target == /usr/* ]] || { echo "External absolute symlink: $link -> $target" >&2; exit 1; }
    target="$root/${target#/usr/}"
    ln -sfn -- "$(realpath -ms --relative-to="${link%/*}" "$target")" "$link"
  fi
done < <(find "$root" -type l -print0)
find "$root/lib" -type f -name '*.a' -delete
mkdir -p "$root/share/pizza" "$root/share/fonts"
cp config/fonts.conf "$root/share/fonts/fonts.conf"
pacman --root /runtime --dbpath /runtime/var/lib/pacman -Q > "$root/share/pizza/package-versions.tsv"
cc -O2 -march=x86-64 tests/abi-check.c -ldl -o "$root/bin/pizza-abi-check"
cc -O2 -march=x86-64 tests/wpe-smoke.c $(pkg-config --cflags --libs wpe-webkit-2.0 wpe-platform-2.0) -o "$root/bin/pizza-wpe-smoke"
# Standard patchelf; every interpreter and search path stays relative.
mapfile -t library_dirs < <(find "$root/lib" -type f -name '*.so*' -printf '%h\n' | sort -u)
declare -A runpaths
while IFS= read -r -d '' file; do
  # The glibc loader bootstraps itself and retains its upstream ELF layout.
  if [[ ${file##*/} == ld-linux-x86-64.so.2 ]]; then continue; fi
  if ! readelf -h "$file" >/dev/null 2>&1; then continue; fi
  if ! readelf -l "$file" | grep -q DYNAMIC; then continue; fi
  if readelf -l "$file" | grep -q INTERP; then
    patchelf --set-interpreter lib/ld-linux-x86-64.so.2 "$file"
  fi
  runpath=${runpaths[${file%/*}]-}
  if [[ -z $runpath ]]; then
    runpath='$ORIGIN'
    for directory in "${library_dirs[@]}"; do
    relative=$(realpath --relative-to="${file%/*}" "$directory")
    if [[ $relative != . ]]; then runpath+=":\$ORIGIN/$relative"; fi
    done
    runpaths[${file%/*}]=$runpath
  fi
  patchelf --set-rpath "$runpath" "$file"
done < <(find "$root/bin" "$root/lib" -type f -print0)
python scripts/metadata.py "$root"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
  -C "$root" -czf /out/pizza-runtime-x86_64.tar.gz .
cd /out
sha256sum pizza-runtime-x86_64.tar.gz > SHA256SUMS
cp "$root/share/pizza/package-versions.tsv" .
