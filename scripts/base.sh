#!/usr/bin/env bash
set -euo pipefail
cd /src
release=$(python -c 'import json; print(json.load(open("config/kernel.json"))["release"])')
cp -a config/dracut/90pizza-base /usr/lib/dracut/modules.d/
mkdir -p /empty-conf
export PIZZA_BUNDLE_ROOT=/build/pizza-runtime PIZZA_MODULES_ROOT=/kernel
export PIZZA_DRIVERS='virtio_pci virtio_blk nvme ahci ext4 dummy'
dracut --conf /dev/null --confdir /empty-conf --modules pizza-base \
  --no-hostonly --no-hostonly-cmdline --no-early-microcode --nostrip --gzip \
  --kver "$release" --kmoddir "/kernel/lib/modules/$release" \
  --include /build/pizza-runtime /opt/pizza/bundle --force /out/pizza-base-x86_64.img
cp /kernel/vmlinuz /out/vmlinuz
python - <<'META'
import json
kernel=json.load(open('config/kernel.json'))
json.dump({'format':1,'kind':'pizza-base','architecture':'x86_64','profile':'wpe-platform-v2',
  'kernel_version':kernel['version'],'kernel_release':kernel['release'],
  'initramfs':'pizza-base-x86_64.img','kernel':'vmlinuz',
  'drivers':['virtio_pci','virtio_blk','nvme','ahci','ext4','dummy'],'firmware':[],
  'application_overlay':{'init':'/init','runtime_root':'/opt/pizza/bundle','panel':'/opt/pizza/panel'}},
  open('/out/base.json','w'),indent=2)
META
cd /out
sha256sum pizza-*.tar.gz pizza-base-x86_64.img vmlinuz base.json > SHA256SUMS
