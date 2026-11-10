#!/usr/bin/env bash
set -euo pipefail
# Run from the bundle root, in an isolated container or disposable VM only.
export PATH="$PWD/bin" LC_ALL=C
readonly SHELL_COMMAND_NOT_EXECUTABLE=126
bundle_root=$PWD
expected=$(awk 'END {print NR}' share/pizza/rescue-tools.tsv)
((expected > 0)) || { echo "Empty rescue tool manifest" >&2; exit 1; }
count=0
while IFS=$'\t' read -r command argument; do
    status=0
    "bin/$command" "$argument" </dev/null > /tmp/pizza-rescue-output 2>&1 || status=$?
    if ((status >= SHELL_COMMAND_NOT_EXECUTABLE)); then
        cat /tmp/pizza-rescue-output >&2
        echo "Rescue tool failed to start: $command ($status)" >&2
        exit 1
    fi
    ((count+=1))
done < share/pizza/rescue-tools.tsv

((count == expected)) || { echo "Rescue tool coverage: $count/$expected" >&2; exit 1; }

# Check resources and actual command behavior as well as process startup.
fixture=$(mktemp -d /tmp/pizza-rescue.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
printf 'pizza rescue fixture\n' > "$fixture/input"
bin/vim -u NONE -i NONE -n -es "$fixture/input" \
    -c 's/rescue/recovered/' -c wq
grep -Fxq 'pizza recovered fixture' "$fixture/input"
file "$fixture/input" | grep -Fq 'ASCII text'
TERM=linux infocmp linux >/dev/null
man -w ls >/dev/null
bin/busybox sh -c 'test "$(printf rescue)" = rescue'
if [[ ${PIZZA_RESCUE_IMAGE:-0} == 1 ]]; then
    # The installed image supports normal shell navigation, independently of CWD.
    (cd "$fixture" && "$bundle_root/bin/ls" . >/dev/null &&
        "$bundle_root/bin/bash" -c 'ls . >/dev/null; vim --version >/dev/null')
fi

# Only regular disposable files are formatted; never access a real block device.
truncate -s 32M "$fixture/ext4.img"
mkfs.ext4 -q -F "$fixture/ext4.img"
e2fsck -fn "$fixture/ext4.img"
truncate -s 16M "$fixture/fat.img"
mkfs.vfat "$fixture/fat.img"
fsck.vfat -n "$fixture/fat.img"
printf 'PIZZA_RESCUE_TOOLS_READY:%s\n' "$count"
