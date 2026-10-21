#!/usr/bin/env bash
set -euo pipefail
# Executed inside a scratch root containing only the package-built runtime.
run_checks() {
  export PATH="$PWD/bin"
  bin/pizza-abi-check libblockdev.so.3 libbd_fs.so.3
  bin/pizza-fs-smoke
  local command status count=0
  while IFS= read -r command; do
    [[ -x bin/$command ]]
    status=0
    "bin/$command" --help > /tmp/pizza-tool-output 2>&1 || status=$?
    if ((status >= 126)); then
      cat /tmp/pizza-tool-output >&2
      echo "Tool failed to start: $command ($status)" >&2
      return 1
    fi
    ((count+=1))
  done < share/pizza/filesystem-tools.txt
  echo "PIZZA_FILESYSTEM_TOOLS_READY:$count"
}
run_checks
mkdir -p /moved
mv "$PWD" /moved/portable-runtime
cd /moved/portable-runtime
export PATH="$PWD/bin"
for alias in /usr/lib /lib /lib64; do bin/ln -sfn "$PWD/lib" "$alias"; done
bin/ln -sfn "$PWD/share" /usr/share
for alias in /bin /sbin /usr/bin /usr/sbin; do bin/ln -sfn "$PWD/bin" "$alias"; done
run_checks
echo 'PASS: moved runtime, relative interpreter/RUNPATH and self-contained filesystem tools and libblockdev ABI'
