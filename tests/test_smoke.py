"""Probe failures must stop before any disposable filesystem smoke operation."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/rescue-smoke.sh'


class RescueSmokeTest(unittest.TestCase):
    def runProbe(self, argument, output, status):
        with tempfile.TemporaryDirectory() as home:
            root = Path(home)
            (root / 'bin').mkdir()
            (root / 'share/pizza').mkdir(parents=True)
            (root / 'share/pizza/rescue-tools.tsv').write_text(f'probe\t{argument}\n')
            for name in ('awk', 'mktemp', 'rm', 'cat'):
                (root / 'bin' / name).symlink_to(shutil.which(name))
            probe = root / 'bin/probe'
            probe.write_text(f'#!/bin/sh\nprintf "%s" "{output}"\nexit {status}\n')
            probe.chmod(0o755)
            # Reaching the semantic phase is observable without running editors
            # or formatting anything, even if the startup phase succeeds.
            sentinel = root / 'bin/vim'
            sentinel.write_text('#!/bin/sh\nexit 88\n')
            sentinel.chmod(0o755)
            return subprocess.run(['/bin/bash', str(SCRIPT)], cwd=root,
                                  text=True, capture_output=True, timeout=5)

    def testFailedVersionProbeIsRejected(self):
        result = self.runProbe('--version', 'missing runtime resource', 1)
        self.assertEqual(result.returncode, 1)
        self.assertIn('Rescue tool probe failed: probe (1)', result.stderr)

    def testEmptySuccessfulProbeIsRejected(self):
        result = self.runProbe('--help', '', 0)
        self.assertEqual(result.returncode, 1)
        self.assertIn('Rescue tool probe failed', result.stderr)

    def testHelpUsageExitStillReachesSemanticChecks(self):
        result = self.runProbe('--help', 'Usage: probe', 1)
        self.assertEqual(result.returncode, 88)
        self.assertNotIn('Rescue tool probe failed', result.stderr)


if __name__ == '__main__':
    unittest.main()
