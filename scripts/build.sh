#!/usr/bin/env bash
set -euo pipefail
cd /src
python -m unittest discover -s tests -p 'test_*.py'
# pacman owns dependency resolution, package signature checking and extraction.
# Rebuild from a clean package root so removed dependencies cannot survive.
rm -rf -- /runtime /build/pizza-runtime
mkdir -p /runtime/var/lib/pacman /runtime/etc /empty-hooks
mkdir -p /build
# Official container images may omit documentation through NoExtract. Rescue
# packages need their complete manuals/resources, not the builder's slim policy.
sed '/^[[:space:]]*NoExtract[[:space:]]*=/d' /etc/pacman.conf > /build/pacman-rescue.conf
python scripts/check-rescue.py > /build/rescue-packages.txt
mapfile -t packages < /build/rescue-packages.txt
pacman --config /build/pacman-rescue.conf --root /runtime --dbpath /runtime/var/lib/pacman \
  --gpgdir /etc/pacman.d/gnupg --cachedir /var/cache/pacman/pkg \
  --hookdir /empty-hooks --noscriptlet --noconfirm --needed -Sy "${packages[@]}"
root=/build/pizza-runtime
mkdir -p "$root" /out
cp -a /runtime/usr/{bin,lib,share} "$root/"
cp -a /runtime/etc "$root/etc"
rm -rf -- "$root/etc/ld.so.cache" "$root/etc/ld.so.conf" "$root/etc/ld.so.conf.d"
# Keep runtime libraries/resources/licenses wholesale; no hand-written dependency walker.
# Preserve man pages, terminfo and editor resources for offline recovery.
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
mkdir -p "$root/share/pizza"
pacman --root /runtime --dbpath /runtime/var/lib/pacman -Q > "$root/share/pizza/package-versions.tsv"
cc -O2 -march=x86-64 tests/abi-check.c -ldl -o "$root/bin/pizza-abi-check"
# Keep a conventional vi command while selecting the upstream Vim package.
[[ -e $root/bin/vi ]] || ln -s vim "$root/bin/vi"
# Expose the package's real power applets, using the conventional BusyBox init protocol.
# Do not replace these commands with shell functions or systemd-dependent wrappers.
for command in reboot poweroff halt; do
  [[ -e $root/bin/$command ]] || ln -s busybox "$root/bin/$command"
done
python scripts/check-rescue.py --runtime "$root"
cp scripts/rescue-smoke.sh "$root/share/pizza/rescue-smoke.sh"
# The package-provided last-resort shell must work without the dynamic loader.
fallback_headers=$(readelf -l "$root/bin/busybox")
fallback_dynamic=$(readelf -d "$root/bin/busybox")
if [[ $fallback_headers == *INTERP* || $fallback_dynamic == *NEEDED* ]]; then
  echo 'Rescue fallback shell must be statically linked' >&2
  exit 1
fi

# Standard patchelf; every interpreter and search path stays relative.
mapfile -t library_dirs < <(find "$root/lib" -type f -name '*.so*' -printf '%h\n' | sort -u)
declare -A runpaths
while IFS= read -r -d '' file; do
  # The glibc loader bootstraps itself and retains its upstream ELF layout.
  if [[ ${file##*/} == ld-linux-x86-64.so.2 ]]; then continue; fi
  if ! readelf -h "$file" >/dev/null 2>&1; then continue; fi
  headers=$(readelf -l "$file")
  if [[ $headers != *DYNAMIC* ]]; then continue; fi
  if [[ $headers == *INTERP* ]]; then
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
# Archives must remain readable and usable by ordinary consumers; no setuid files.
chmod -R u+rwX,go+rX,a-s,a-t "$root"
python scripts/metadata.py "$root"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
  -C "$root" -czf /out/pizza-runtime-x86_64.tar.gz .
cd /out
sha256sum pizza-runtime-x86_64.tar.gz > SHA256SUMS
cp "$root/share/pizza/package-versions.tsv" .
