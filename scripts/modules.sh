#!/usr/bin/env bash
set -euo pipefail
# Explicit roots are mandatory. Never use /lib/modules or /lib/firmware as inputs.
[[ $# == 4 ]] || { echo 'usage: modules.sh PACKAGE_ROOT OUTPUT_ROOT RELEASE PROFILE' >&2; exit 1; }
source_root=$(realpath -e -- "$1")
output_root=$(realpath -m -- "$2")
release=$3
profile=$4
[[ $source_root != / && $output_root != / && $output_root != "$source_root" && $release != */* && $release != .* ]]
modules_root="$source_root/lib/modules/$release"
[[ -f $modules_root/modules.dep && -f $modules_root/modules.builtin ]]
# The generic profile deliberately has no external firmware. Reject a profile
# change requiring it until a pinned package input and explicit copy are added.
mapfile -t drivers < <(python - "$profile" <<'PROFILE'
import json, re, sys
profile=json.load(open(sys.argv[1]))
assert profile['firmware'] == [], 'hardware firmware needs an explicit package source'
assert profile['drivers'] and all(re.fullmatch(r'[a-zA-Z0-9_]+', d) for d in profile['drivers'])
print('\n'.join(profile['drivers']))
PROFILE
)
((${#drivers[@]}))
mkdir -p "$output_root/etc/pizza"
printf '%s\n' "$release" > "$output_root/etc/pizza/kernel-version"
: > "$output_root/etc/pizza/modules"
: > "$output_root/etc/pizza/firmware"
audit_firmware() {
    local names
    names=$(modinfo --basedir "$source_root" --set-version "$release" -F firmware "$1")
    [[ -z $names ]] || { echo "Profile requires explicit hardware firmware: $1: $names" >&2; return 1; }
}
for driver in "${drivers[@]}"; do
    audit_firmware "$driver"
    dependencies=$(modprobe --dirname "$source_root" --config /dev/null --ignore-install --set-version "$release" --show-depends -- "$driver")
    while read -r action source unused; do
        case "$action" in
            builtin) continue ;;
            insmod) ;;
            '') continue ;;
            *) echo "Unexpected module action: $action" >&2; exit 1 ;;
        esac
        # Resolve symlinks before accepting the package boundary.
        source=$(realpath -e -- "$source")
        [[ $source == "$modules_root/"* ]] || { echo "Module outside package root: $source" >&2; exit 1; }
        audit_firmware "$source"
        relative=${source#"$source_root"}
        destination=${relative%.zst}
        destination=${destination%.xz}
        destination=${destination%.gz}
        [[ $destination == *.ko ]]
        if grep -Fxq -- "$destination" "$output_root/etc/pizza/modules"; then continue; fi
        mkdir -p "$output_root${destination%/*}"
        case "$source" in
            *.zst) zstd -dc -- "$source" > "$output_root$destination" ;;
            *.xz) xz -dc -- "$source" > "$output_root$destination" ;;
            *.gz) gzip -dc -- "$source" > "$output_root$destination" ;;
            *) cp -- "$source" "$output_root$destination" ;;
        esac
        printf '%s\n' "$destination" >> "$output_root/etc/pizza/modules"
    done <<< "$dependencies"
done
python - "$profile" "$output_root/etc/pizza/filesystems" <<'FILESYSTEMS'
import json, sys
from pathlib import Path
Path(sys.argv[2]).write_text('\n'.join(json.load(open(sys.argv[1]))['filesystems'])+'\n')
FILESYSTEMS
