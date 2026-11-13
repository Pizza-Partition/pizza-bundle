#!/usr/bin/env bash
# Shared by runtime CI and the three-repository candidate release gate.
set -euo pipefail
[[ -f /etc/arch-release && $(id -u) == 0 ]]
ln -s "$GITHUB_WORKSPACE" /src
python -m unittest discover -s tests -p 'test_*.py'
scripts/build.sh
scripts/kernel.sh
tests/modules.sh
scripts/base.sh
scripts/prepare-test-root.sh
docker build --file tests/Containerfile --tag pizza-runtime-test /testroot
docker run --rm --network none --shm-size 256m pizza-runtime-test
mkdir -p dist kernel
cp -a /out/. dist/
cp -a /kernel/. kernel/
cp /kernel-smoke.cpio.gz kernel-smoke.cpio.gz
cat dist/pizza-base-x86_64.img kernel-smoke.cpio.gz > base-test.img
timeout 300 qemu-system-x86_64 -machine q35 -accel tcg -cpu max -m 4096M -display none -serial stdio -monitor none -nic none -kernel kernel/vmlinuz -initrd base-test.img -append 'console=ttyS0 rdinit=/init panic=1' -no-reboot > kernel-smoke.log 2>&1 || { cat kernel-smoke.log; exit 1; }
cat kernel-smoke.log
grep -F 'PIZZA_BASE_READY:7.2.11-arch1-1' kernel-smoke.log
