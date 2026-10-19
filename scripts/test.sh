#!/usr/bin/env bash
set -euo pipefail
# This scratch container contains only the released runtime, not the builder.
cd /opt/pizza/bundle
bin/pizza-abi-check libWPEWebKit-2.0.so.1 libEGL.so.1 libgbm.so.1
export HOME=/run/pizza TMPDIR=/tmp XDG_RUNTIME_DIR=/run/pizza XDG_CACHE_HOME=/run/pizza/cache
export WPE_DISPLAY=wpe-display-headless WPE_PLATFORM=headless EGL_PLATFORM=surfaceless
export LIBGL_ALWAYS_SOFTWARE=true WEBKIT_SKIA_ENABLE_CPU_RENDERING=1
# CI-only: the production application does not disable its sandbox.
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
export FONTCONFIG_FILE=/opt/pizza/bundle/share/fonts/fonts.conf
export XDG_DATA_DIRS=/opt/pizza/bundle/share GIO_EXTRA_MODULES=/opt/pizza/bundle/lib/gio/modules
export WEBKIT_INJECTED_BUNDLE_PATH=/opt/pizza/bundle/lib/wpe-webkit-2.0/injected-bundle
timeout 90 bin/pizza-wpe-smoke
echo 'PASS: isolated ABI, dependency loading and WPE JavaScript round trip'
