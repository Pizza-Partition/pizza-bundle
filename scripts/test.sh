#!/usr/bin/env bash
set -euo pipefail
# WORKDIR was moved from the build directory; relative PT_INTERP resolves from CWD.
run_checks() {
  local root=$PWD
  export PATH="$root/bin"
  export HOME=/run/pizza TMPDIR=/tmp XDG_RUNTIME_DIR=/run/pizza XDG_CACHE_HOME=/run/pizza/cache
  export WPE_DISPLAY=wpe-display-headless WPE_PLATFORM=headless EGL_PLATFORM=surfaceless
  export LIBGL_ALWAYS_SOFTWARE=true WEBKIT_SKIA_ENABLE_CPU_RENDERING=1
  # CI-only; production startup retains sandbox enforcement.
  export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
  export FONTCONFIG_FILE="$root/share/fonts/fonts.conf"
  export XDG_DATA_DIRS="$root/share" GIO_EXTRA_MODULES="$root/lib/gio/modules"
  export WEBKIT_INJECTED_BUNDLE_PATH="$root/lib/wpe-webkit-2.0/injected-bundle"
  bin/pizza-abi-check libWPEWebKit-2.0.so.1 libEGL.so.1 libgbm.so.1
  timeout 90 bin/pizza-wpe-smoke
}
run_checks
# Move the whole tree again, with neither a loader nor library left at its old location.
mkdir -p /moved
mv "$PWD" /moved/portable-runtime
cd /moved/portable-runtime
export PATH="$PWD/bin"
# Upstream WPE has compiled-in libexec/resource paths; the RAM image also supplies aliases.
# These are image integration, not fixed paths in ELF interpreters or RUNPATHs.
for alias in /usr/lib /lib /lib64; do bin/ln -sfn "$PWD/lib" "$alias"; done
bin/ln -sfn "$PWD/share" /usr/share
bin/ln -sfn "$PWD/bin" /bin
run_checks
echo 'PASS: moved runtime, relative interpreter/RUNPATH, ABI and WPE JavaScript round trips'
