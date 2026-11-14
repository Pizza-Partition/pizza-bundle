#!/usr/bin/env bash
# Shared by runtime CI and the three-repository candidate release gate.
set -euo pipefail
[[ -f /etc/arch-release && $(id -u) == 0 ]]
cd "$(dirname "${BASH_SOURCE[0]}")/.."
scripts/build-all.sh
docker build --file tests/Containerfile --tag pizza-runtime-test /testroot
docker run --rm --network none --shm-size 256m pizza-runtime-test
mkdir -p dist kernel
cp -a /out/. dist/
cp -a /kernel/. kernel/
cp /kernel-smoke.cpio.gz kernel-smoke.cpio.gz
cat dist/pizza-base-x86_64.img kernel-smoke.cpio.gz > base-test.img
timeout 300 qemu-system-x86_64 -machine q35 -accel tcg -cpu max -m 4096M -display none -serial stdio -monitor none -nic none -kernel kernel/vmlinuz -initrd base-test.img -append 'console=ttyS0 rdinit=/init panic=1' -no-reboot > kernel-smoke.log 2>&1 || { cat kernel-smoke.log; exit 1; }
cat kernel-smoke.log
release=$(python scripts/read-config.py config/kernel.json release)
grep -F "PIZZA_BASE_READY:$release" kernel-smoke.log
