"""Build-contract tests; no Roblox or third-party dependencies."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('huss_build', Path(__file__).with_name('build.py'))
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class ModuleBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'src/core').mkdir(parents=True)
        (self.root / 'src/main.lua').write_text('local Core = {}\n')
        (self.root / 'src/core/sample.lua').write_text('Core.answer = 42\n')
        (self.root / 'src/finish.lua').write_text('return Core\n')
        self.manifest=['main.lua','core/sample.lua','finish.lua']
        self.write_manifest(self.manifest)

    def write_manifest(self, units):
        (self.root / 'src/manifest.json').write_text(json.dumps({'version': 1, 'units': units}) + '\n')

    def test_module_compiler_is_available(self):
        self.assertTrue(callable(getattr(build, 'assemble', None)), 'builder must compile editable source modules')

    def test_expansion_preserves_code_and_maps_every_line(self):
        code, mapping = build.assemble(self.root)
        self.assertEqual(code, 'local Core = {}\nCore.answer = 42\nreturn Core\n')
        self.assertEqual(build.assemble(self.root), (code, mapping))
        self.assertEqual(mapping['segments'][1], {'generated_line': 2, 'source': 'src/core/sample.lua', 'source_line': 1, 'lines': 1})
        (self.root / 'src/core/sample.lua').write_text('Core.answer = 43\n')
        self.assertIn('Core.answer = 43', build.assemble(self.root)[0])

    def test_real_source_map_matches_every_generated_line(self):
        root = Path(__file__).resolve().parents[1]
        code, mapping = build.assemble(root)
        generated = code.splitlines(keepends=True)
        covered = []
        for segment in mapping['segments']:
            original = (root / segment['source']).read_text().splitlines(keepends=True)
            first = segment['generated_line'] - 1
            start = segment['source_line'] - 1
            count = segment['lines']
            self.assertEqual(generated[first:first + count], original[start:start + count])
            covered.extend(range(first, first + count))
        self.assertEqual(covered, list(range(len(generated))))

    def test_duplicate_units_are_rejected(self):
        self.write_manifest(self.manifest+['core/sample.lua'])
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            build.assemble(self.root)

    def test_escape_missing_generated_and_unregistered_sources_are_rejected(self):
        for include, error in [('../../outside.lua', 'outside'), ('core/missing.lua', 'Missing'), ('auto-play.lua', 'generated')]:
            with self.subTest(include=include):
                self.write_manifest(self.manifest+[include])
                with self.assertRaisesRegex(ValueError, error):
                    build.assemble(self.root)
        self.write_manifest(self.manifest)
        (self.root / 'src/core/unused.lua').write_text('return 1\n')
        with self.assertRaisesRegex(ValueError, 'Unregistered'):
            build.assemble(self.root)

    def test_missing_newline_cannot_merge_lua_tokens(self):
        (self.root / 'src/core/sample.lua').write_text('Core.answer = 42')
        with self.assertRaisesRegex(ValueError, 'newline'):
            build.assemble(self.root)

    def test_production_comments_are_rejected(self):
        (self.root / 'src/core/sample.lua').write_text('Core.answer = 42 -- comment\n')
        with self.assertRaisesRegex(ValueError, 'comment'):
            build.assemble(self.root)

    def test_check_detects_changed_module_and_never_rewrites_outputs(self):
        project = Path(__file__).resolve().parents[1]
        checkout = self.root / 'project'
        shutil.copytree(project, checkout, ignore=shutil.ignore_patterns('__pycache__'))
        command = [sys.executable, str(checkout / 'tools/build.py')]
        first = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(first.returncode, 0, first.stderr)
        generated = checkout / 'src/auto-play.lua'
        before = generated.read_bytes()
        module = next((checkout / 'src/core').glob('*.lua'))
        module.write_bytes(module.read_bytes() + b'Core.auditMarker = true\n')
        checked = subprocess.run(command + ['--check'], capture_output=True, text=True)
        self.assertNotEqual(checked.returncode, 0)
        self.assertIn('Stale', checked.stderr)
        self.assertEqual(generated.read_bytes(), before)
        rebuilt = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(rebuilt.returncode, 0, rebuilt.stderr)
        self.assertNotEqual(generated.read_bytes(), before)
        self.assertEqual(subprocess.run(command + ['--check'], capture_output=True).returncode, 0)


if __name__ == '__main__':
    unittest.main()
