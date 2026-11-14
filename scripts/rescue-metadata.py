"""Select rescue packages and generate validated runtime rescue metadata."""
import argparse
import hashlib
import json
from pathlib import Path
import re


def configuration(config):
    source = json.loads((config / 'systemrescue/source.json').read_text())
    inventory = (config / 'systemrescue/packages.tsv').read_bytes()
    if hashlib.sha256(inventory).hexdigest() != source['inventory_sha256']:
        raise ValueError('SystemRescue inventory digest mismatch')
    upstream = dict(line.split('\t') for line in inventory.decode().splitlines())
    packages = []
    for line in (config / 'packages.txt').read_text().splitlines():
        name = line.split('#', 1)[0].strip()
        if not name:
            continue
        if not re.fullmatch(r'[a-z0-9][a-z0-9@+_.-]*', name):
            raise ValueError(f'Invalid package name: {name}')
        if name not in upstream:
            raise ValueError(f'Package outside SystemRescue subset: {name}')
        if name in packages:
            raise ValueError(f'Duplicate package: {name}')
        packages.append(name)
    if not packages:
        raise ValueError('Empty rescue subset')
    filesystem = json.loads((config / 'filesystem-tools.json').read_text())
    for entry in filesystem.values():
        if entry['package'] not in packages:
            raise ValueError(f'Filesystem tool package not selected: {entry["package"]}')
    return source, upstream, packages, filesystem


def validateRuntime(config, root):
    source, upstream, packages, filesystem = configuration(config)
    versions = dict(line.split(maxsplit=1) for line in
                    (root / 'share/pizza/package-versions.tsv').read_text().splitlines())
    missing = set(packages) - versions.keys()
    outside = versions.keys() - upstream.keys()
    if missing or outside:
        raise ValueError(f'Missing packages: {sorted(missing)}; '
                         f'packages outside SystemRescue: {sorted(outside)}')
    rescue = json.loads((config / 'rescue-tools.json').read_text())
    commands = dict.fromkeys(rescue['commands'], '--help')
    overrides = rescue.get('probe_overrides', {})
    if overrides.keys() - commands.keys():
        raise ValueError('Probe override outside selected rescue commands')
    commands.update(overrides)
    filesystem_commands = []
    for entry in filesystem.values():
        for command in entry['commands']:
            commands.setdefault(command, '--help')
            filesystem_commands.append(command)
    for command in commands:
        if not re.fullmatch(r'[a-zA-Z0-9_.+-]+', command):
            raise ValueError(f'Invalid command: {command}')
    for path in [*(f'bin/{name}' for name in commands), rescue['shell'], rescue['fallback_shell']]:
        target = root / path
        if not target.is_file() or not target.stat().st_mode & 0o111:
            raise ValueError(f'Missing executable: {path}')
    output = root / 'share/pizza'
    (output / 'rescue-tools.tsv').write_text(''.join(
        f'{name}\t{argument}\n' for name, argument in sorted(commands.items())))
    (output / 'filesystem-tools.txt').write_text('\n'.join(filesystem_commands) + '\n')
    (output / 'filesystem-tools.json').write_text(json.dumps(filesystem, indent=2) + '\n')
    (output / 'rescue.json').write_text(json.dumps({
        'source': source,
        'shell': rescue['shell'],
        'fallback_shell': rescue['fallback_shell'],
        'selected_packages': packages,
        'package_versions': versions,
        'version_policy': 'pinned Arch snapshot; SystemRescue versions are reference only',
    }, indent=2) + '\n')
    (output / 'systemrescue-packages.tsv').write_bytes((config / 'systemrescue/packages.tsv').read_bytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=Path('config'))
    parser.add_argument('--runtime', type=Path)
    args = parser.parse_args()
    if args.runtime is None:
        print('\n'.join(configuration(args.config)[2]))
    else:
        validateRuntime(args.config, args.runtime)


if __name__ == '__main__':
    main()
