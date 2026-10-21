#!/usr/bin/env bash
set -euo pipefail
cd /src
# pacman owns dependency resolution, package signature checking and extraction.
# Rebuild from a clean package root so removed dependencies cannot survive.
rm -rf -- /runtime /build/pizza-runtime
mkdir -p /runtime/var/lib/pacman /runtime/etc /empty-hooks
mapfile -t packages < config/packages.txt
pacman --root /runtime --dbpath /runtime/var/lib/pacman \
  --gpgdir /etc/pacman.d/gnupg --cachedir /var/cache/pacman/pkg \
  --hookdir /empty-hooks --noscriptlet --noconfirm --needed -Sy "${packages[@]}"
root=/build/pizza-runtime
mkdir -p "$root" /out
cp -a /runtime/usr/{bin,lib,share} "$root/"
cp -a /runtime/etc "$root/etc"
rm -rf -- "$root/etc/ld.so.cache" "$root/etc/ld.so.conf" "$root/etc/ld.so.conf.d"
# Keep runtime libraries/resources/licenses wholesale; no hand-written dependency walker.
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
mkdir -p "$root/share/pizza"
pacman --root /runtime --dbpath /runtime/var/lib/pacman -Q > "$root/share/pizza/package-versions.tsv"
cc -O2 -march=x86-64 tests/abi-check.c -ldl -o "$root/bin/pizza-abi-check"
# Verify every requested command is actually supplied by the selected packages.
python - "$root" <<'TOOLS'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
config=json.load(open('config/filesystem-tools.json'))
packages=set(open('config/packages.txt').read().splitlines())
commands=[]
for entry in config.values():
    assert entry['package'] in packages, entry['package']
    for command in entry['commands']:
        path=root/'bin'/command
        assert path.is_file() and path.stat().st_mode & 0o111, f'Missing executable: {command}'
        commands.append(command)
(root/'share/pizza/filesystem-tools.txt').write_text('\n'.join(commands)+'\n')
(root/'share/pizza/filesystem-tools.json').write_text(json.dumps(config,indent=2)+'\n')
TOOLS
PKG_CONFIG_SYSROOT_DIR=/runtime PKG_CONFIG_LIBDIR=/runtime/usr/lib/pkgconfig \
    pkg-config --cflags --libs blockdev > /build/fs-smoke-flags
read -r -a fs_flags < /build/fs-smoke-flags
cc -O2 -march=x86-64 tests/fs-smoke.c "${fs_flags[@]}" -Wl,-rpath-link,/runtime/usr/lib -o "$root/bin/pizza-fs-smoke"

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
