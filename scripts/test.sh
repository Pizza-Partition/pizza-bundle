#!/usr/bin/env bash
set -euo pipefail
root=${1:?runtime root required}
# Isolated root, with upstream's compiled-in /usr paths redirected to the bundle.
isolation=$(mktemp -d)
trap 'rm -rf "$isolation"' EXIT
mkdir -p "$isolation/opt/pizza" "$isolation/usr" "$isolation/etc" "$isolation/tmp" "$isolation/run/pizza" "$isolation/dev"
cp -a "$root" "$isolation/opt/pizza/bundle"
ln -s /opt/pizza/bundle/lib "$isolation/usr/lib"
ln -s /opt/pizza/bundle/share "$isolation/usr/share"
ln -s /opt/pizza/bundle/bin "$isolation/bin"
ln -s /opt/pizza/bundle/lib "$isolation/lib"
ln -s /opt/pizza/bundle/lib "$isolation/lib64"
# /proc is required by WPE; mount it in the container's private mount namespace.
mkdir -p "$isolation/proc"
mount --bind /proc "$isolation/proc"
trap 'umount -l "$isolation/proc"; rm -rf "$isolation"' EXIT
# Only pseudo devices needed by WebKit; no disks or other host devices enter the chroot.
for device in null zero random urandom; do
  touch "$isolation/dev/$device"
  mount --bind "/dev/$device" "$isolation/dev/$device"
done
mkdir -p "$isolation/dev/shm"
mount -t tmpfs -o size=256m tmpfs "$isolation/dev/shm"
cleanup() {
  umount -l "$isolation/dev/shm"
  for device in null zero random urandom; do umount -l "$isolation/dev/$device"; done
  umount -l "$isolation/proc"
  rm -rf "$isolation"
}
trap cleanup EXIT
chroot "$isolation" /bin/sh -c 'cd /opt/pizza/bundle && bin/pizza-abi-check libWPEWebKit-2.0.so.1 libEGL.so.1 libgbm.so.1'
# The smoke test exercises WebKit's WebProcess, JavaScript engine and message round trip.
# Sandbox is disabled only inside this isolated CI test, not in the product.
timeout 90 chroot "$isolation" /bin/sh -c '
  cd /opt/pizza/bundle
  export HOME=/run/pizza TMPDIR=/tmp XDG_RUNTIME_DIR=/run/pizza XDG_CACHE_HOME=/run/pizza/cache
  export WPE_DISPLAY=wpe-display-headless WPE_PLATFORM=headless EGL_PLATFORM=surfaceless
  export LIBGL_ALWAYS_SOFTWARE=true WEBKIT_SKIA_ENABLE_CPU_RENDERING=1
  export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
  export FONTCONFIG_FILE=/opt/pizza/bundle/share/fonts/fonts.conf
  export XDG_DATA_DIRS=/opt/pizza/bundle/share GIO_EXTRA_MODULES=/opt/pizza/bundle/lib/gio/modules
  export WEBKIT_INJECTED_BUNDLE_PATH=/opt/pizza/bundle/lib/wpe-webkit-2.0/injected-bundle
  exec bin/pizza-wpe-smoke
'
echo 'PASS: isolated ABI, dependency loading and WPE JavaScript round trip'
