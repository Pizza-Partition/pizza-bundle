#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
release=$(python scripts/read-config.py config/kernel.json release)
root=/build/pizza-base
rm -rf -- "$root"
mkdir -p "$root" /out
# All inputs are package-built trees. No host scan, dracut or implicit firmware lookup.
scripts/modules.sh /kernel "$root" "$release" config/maintenance.json
mkdir -p "$root"/{proc,sys,dev,run,tmp,opt/pizza}
chmod 1777 "$root/tmp"
cp -a /build/pizza-runtime "$root/opt/pizza/bundle"
cp -a /build/pizza-runtime/etc/. "$root/etc/"
mkdir -p "$root/usr"
ln -s /opt/pizza/bundle/bin "$root/bin"
ln -s /opt/pizza/bundle/bin "$root/sbin"
ln -s /opt/pizza/bundle/bin "$root/usr/bin"
ln -s /opt/pizza/bundle/bin "$root/usr/sbin"
ln -s /opt/pizza/bundle/lib "$root/usr/lib"
ln -s /opt/pizza/bundle/share "$root/usr/share"
ln -s /opt/pizza/bundle/lib "$root/lib64"
# Rescue commands must work after cd into an arbitrary mountpoint. Only the
# image copy uses the conventional absolute loader; the portable archive keeps
# its relative interpreter. RUNPATH stays relative to each executable/library.
while IFS= read -r -d '' file; do
    headers=$(readelf -l "$file" 2>/dev/null) || continue
    if [[ $headers == *INTERP* ]]; then
        patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 "$file"
    fi
done < <(find "$root/opt/pizza/bundle/bin" "$root/opt/pizza/bundle/lib" -type f -print0)
# No /init: the consumer or the boot-test overlay supplies it.
find "$root" -exec touch -h -d @0 -- {} +
(cd "$root" && find . -print0 | LC_ALL=C sort -z | cpio --null --create --format=newc --reproducible --owner=0:0 --quiet | gzip -n > /out/pizza-base-x86_64.img)
cp /kernel/vmlinuz /out/vmlinuz
python - <<'META'
import json
kernel=json.load(open('config/kernel.json'))
profile=json.load(open('config/maintenance.json'))
json.dump({'format':1,'kind':'pizza-base','architecture':'x86_64',**profile,
  'kernel_version':kernel['version'],'kernel_release':kernel['release'],
  'initramfs':'pizza-base-x86_64.img','kernel':'vmlinuz',
  'application_overlay':{'init':'/init','runtime_root':'/opt/pizza/bundle'}},
  open('/out/base.json','w'),indent=2)
META
cd /out
sha256sum pizza-*.tar.gz pizza-base-x86_64.img vmlinuz base.json > SHA256SUMS
