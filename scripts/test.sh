#!/usr/bin/env bash
set -euo pipefail
# Executed inside a scratch root containing only the package-built runtime.
runChecks() {
  export PATH="$PWD/bin"
  bin/pizza-abi-check
  bin/bash share/pizza/rescue-smoke.sh
}
runChecks
mkdir -p /moved
mv "$PWD" /moved/portable-runtime
cd /moved/portable-runtime
export PATH="$PWD/bin"
for alias in /usr/lib /lib /lib64; do bin/ln -sfn "$PWD/lib" "$alias"; done
bin/ln -sfn "$PWD/share" /usr/share
for alias in /bin /sbin /usr/bin /usr/sbin; do bin/ln -sfn "$PWD/bin" "$alias"; done
runChecks
echo 'PASS: moved runtime, relative interpreter/RUNPATH and SystemRescue filesystem rescue subset'
