#!/usr/bin/env bash
set -euo pipefail
cd /src
mapfile -t fields < <(python -c 'import json; d=json.load(open("config/kernel.json")); print("\n".join(d[k] for k in ["version","release","url","sha256"]))')
release=${fields[1]}
archive=/tmp/pizza-linux.pkg.tar.zst
curl --fail --location --retry 3 --output "$archive" "${fields[2]}"
curl --fail --location --retry 3 --output "$archive.sig" "${fields[2]}.sig"
printf '%s  %s\n' "${fields[3]}" "$archive" | sha256sum --check
pacman-key --verify "$archive.sig" "$archive"
mkdir -p /kernel/lib /out /kernel-smoke
bsdtar -xf "$archive" --strip-components 2 -C /kernel/lib usr/lib/modules
mv "/kernel/lib/modules/$release/vmlinuz" /kernel/vmlinuz
depmod --basedir /kernel "$release"
module=$(find "/kernel/lib/modules/$release/kernel" -name '*.ko.zst' -print -quit)
[[ $(modinfo -F vermagic "$module") == "$release "* ]]
python -c 'import json; d=json.load(open("config/kernel.json")); json.dump({"format":1,"version":d["version"],"release":d["release"],"image":"vmlinuz","modules":"lib/modules/"+d["release"],"firmware":[]},open("/kernel/kernel.json","w"),indent=2)'
chmod -R u+rwX,go+rX,a-s,a-t /kernel
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C /kernel -czf /out/pizza-kernel-x86_64.tar.gz .
cc -static -O2 -march=x86-64 -DEXPECTED_KERNEL=\""$release"\" tests/kernel-smoke.c -o /kernel-smoke/init
(cd /kernel-smoke && printf 'init\n' | cpio --create --format=newc --quiet | gzip -n > /kernel-smoke.cpio.gz)
cd /out
sha256sum pizza-*.tar.gz > SHA256SUMS
