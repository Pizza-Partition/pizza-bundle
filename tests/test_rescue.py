import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('rescue', REPO / 'scripts/rescue-metadata.py')
rescue = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rescue)


class RescueSubsetTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / 'config'
        shutil.copytree(REPO / 'config', self.config)

    def testCheckedInSelectionIsANonemptySubset(self):
        source, upstream, packages, _ = rescue.configuration(self.config)
        self.assertEqual(source['distribution'], 'SystemRescue')
        self.assertTrue(set(packages) < upstream.keys())
        self.assertTrue({'bash', 'vim', 'nano', 'e2fsprogs', 'cryptsetup'} <= set(packages))
        self.assertNotIn('emacs-nox', packages)

    def testRejectsChangedUpstreamInventory(self):
        with (self.config / 'systemrescue/packages.tsv').open('a') as file:
            file.write('invented-package\t1.0\n')
        with self.assertRaisesRegex(ValueError, 'digest mismatch'):
            rescue.configuration(self.config)

    def testRejectsPackagesOutsideUpstream(self):
        with (self.config / 'packages.txt').open('a') as file:
            file.write('invented-package\n')
        with self.assertRaisesRegex(ValueError, 'outside SystemRescue'):
            rescue.configuration(self.config)

    def testRejectsDuplicateSelection(self):
        with (self.config / 'packages.txt').open('a') as file:
            file.write('bash\n')
        with self.assertRaisesRegex(ValueError, 'Duplicate package'):
            rescue.configuration(self.config)

    def runtime(self):
        _, _, packages, filesystems = rescue.configuration(self.config)
        root = self.root / 'runtime'
        output = root / 'share/pizza'
        output.mkdir(parents=True)
        (output / 'package-versions.tsv').write_text(''.join(f'{name} 1.0\n' for name in packages))
        tools = json.loads((self.config / 'rescue-tools.json').read_text())
        paths = {f'bin/{name}' for name in tools['commands']}
        for entry in filesystems.values():
            paths.update(f'bin/{name}' for name in entry['commands'])
        paths.update((tools['shell'], tools['fallback_shell']))
        for relative in paths:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('fixture\n')
            path.chmod(0o755)
        return root

    def testRuntimeRecordsSelectedAndResolvedPackages(self):
        root = self.runtime()
        rescue.validateRuntime(self.config, root)
        manifest = json.loads((root / 'share/pizza/rescue.json').read_text())
        self.assertEqual(set(manifest['selected_packages']), set(manifest['package_versions']))
        self.assertEqual(manifest['fallback_shell'], 'bin/busybox')
        probes = dict(line.split('\t') for line in (root / 'share/pizza/rescue-tools.tsv').read_text().splitlines())
        self.assertEqual(probes['awk'], '--help')
        self.assertEqual(probes['cryptsetup'], '--version')

    def testRejectsUnselectedProbeOverride(self):
        root = self.runtime()
        path = self.config / 'rescue-tools.json'
        tools = json.loads(path.read_text())
        tools['probe_overrides']['unselected-tool'] = '--version'
        path.write_text(json.dumps(tools))
        with self.assertRaisesRegex(ValueError, 'outside selected rescue commands'):
            rescue.validateRuntime(self.config, root)


    def testRejectsDependencyOutsideUpstream(self):
        root = self.runtime()
        with (root / 'share/pizza/package-versions.tsv').open('a') as file:
            file.write('unexpected-dependency 1.0\n')
        with self.assertRaisesRegex(ValueError, 'unexpected-dependency'):
            rescue.validateRuntime(self.config, root)

    def testRejectsMissingRuntimeTool(self):
        root = self.runtime()
        (root / 'bin/nano').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing executable: bin/nano'):
            rescue.validateRuntime(self.config, root)


if __name__ == '__main__':
    unittest.main()
