"""Small consumer contract; provenance authenticates the complete archive."""
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
versions = dict(line.split(maxsplit=1) for line in (root / 'share/pizza/package-versions.tsv').read_text().splitlines())
metadata = {
    'format': 3,
    'kind': 'pizza-runtime',
    'profile': 'wpe-platform-v2',
    'architecture': 'x86_64',
    'working_directory': 'bundle-root',
    'runtime_versions': {'glibc': versions['glibc'].split('-')[0].split('+')[0], 'wpe-webkit': versions['wpewebkit'].split('-')[0]},
    'components': {'dynamic-loader': 'lib/ld-linux-x86-64.so.2', 'wpe-webkit': 'lib/libWPEWebKit-2.0.so.1'},
}
(root / 'runtime.json').write_text(json.dumps(metadata, indent=2) + '\n')
