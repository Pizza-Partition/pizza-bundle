import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/read-config.py'


class ReadConfigTest(unittest.TestCase):
    def run_config(self, value, *keys):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            path.write_text(json.dumps(value))
            return subprocess.run([sys.executable, str(SCRIPT), str(path), *keys], capture_output=True, text=True)

    def test_prints_fields_in_requested_order(self):
        result = self.run_config({'version': '1.0', 'release': 'test release'}, 'release', 'version')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, 'test release\n1.0\n')

    def test_rejects_missing_or_multiline_fields_without_partial_output(self):
        for data, keys in [({'ok': 'value'}, ['ok', 'missing']), ({'value': ['nested']}, ['value']), ({'value': 'line\nbreak'}, ['value'])]:
            with self.subTest(data=data):
                result = self.run_config(data, *keys)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
