"""Small consumer contract; provenance authenticates the complete archive."""
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
versions = dict(line.split(maxsplit=1) for line in (root / 'share/pizza/package-versions.tsv').read_text().splitlines())
metadata = {
    'format': 3,
    'kind': 'pizza-runtime',
    'profile': 'cpu-maint-v1',
    'architecture': 'x86_64',
    'working_directory': 'bundle-root',
    'runtime_versions': {'glibc': versions['glibc'].split('-')[0].split('+')[0]},
    'components': {'dynamic-loader': 'lib/ld-linux-x86-64.so.2',
                   'rescue-shell': 'bin/bash', 'fallback-shell': 'bin/busybox'},
    'rescue': {'distribution': 'SystemRescue',
               'manifest': 'share/pizza/rescue.json'},
}
(root / 'runtime.json').write_text(json.dumps(metadata, indent=2) + '\n')
