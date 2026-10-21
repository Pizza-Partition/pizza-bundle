#!/usr/bin/env bash
set -euo pipefail
# Run after scripts/kernel.sh against the exact package extracted for this build.
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
kernel_root=${1:-/kernel}
release=$(python -c 'import json; print(json.load(open("config/kernel.json"))["release"])')
scripts/modules.sh "$kernel_root" "$root/image" "$release" config/maintenance.json
[[ -s $root/image/etc/pizza/modules && ! -s $root/image/etc/pizza/firmware ]]
while IFS= read -r module; do
    [[ $module == /lib/modules/"$release"/*.ko ]]
    [[ $(modinfo -F vermagic "$root/image$module") == "$release "* ]]
done < "$root/image/etc/pizza/modules"
# A missing package must fail even on a host with the same kernel installed.
if scripts/modules.sh "$root/missing" "$root/bad" "$release" config/maintenance.json; then
    echo 'Missing package unexpectedly fell back to host modules' >&2; exit 1
fi
# kmod output must never smuggle an input outside the explicit package root.
mkdir "$root/bin"
cat > "$root/bin/modprobe" <<'MOCK'
#!/bin/sh
printf 'insmod /etc/hosts\n'
MOCK
chmod +x "$root/bin/modprobe"
if PATH="$root/bin:$PATH" scripts/modules.sh "$kernel_root" "$root/bad" "$release" config/maintenance.json; then
    echo 'External module path unexpectedly accepted' >&2; exit 1
fi
echo 'PASS: pinned modules, decompression, no host fallback and package boundary'
