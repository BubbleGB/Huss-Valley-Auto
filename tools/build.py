#!/usr/bin/env python3
"""Build or check the Delta distribution using only the Python standard library."""

import argparse
import hashlib
import json
from pathlib import Path
import re
from runpy import run_path


ROOT = Path(__file__).resolve().parents[1]
lexer = run_path(str(Path(__file__).with_name('luau_compact.py')))
compact = lexer['compact']


def text(path):
    return path.read_bytes().decode('utf-8')


def assemble(root=ROOT):
    """Assemble the ordered, comment-free source manifest in one lexical scope."""
    root = Path(root).resolve()
    source_root = (root / 'src').resolve()
    generated = source_root / 'auto-play.lua'
    visited, segments, chunks = set(), [], []
    line_number = 1
    manifest = json.loads(text(source_root / 'manifest.json'))
    if not isinstance(manifest, dict) or manifest.get('version') != 1 or not isinstance(manifest.get('units'), list) or not manifest['units']:
        raise ValueError('Invalid source manifest')
    for name in manifest['units']:
        if not isinstance(name, str) or not name.endswith('.lua'):
            raise ValueError('Invalid source unit')
        path = (source_root / name).resolve()
        if not path.is_relative_to(source_root):
            raise ValueError('Source outside src: ' + str(path))
        if path == generated:
            raise ValueError('Cannot include the generated executable')
        if path in visited:
            raise ValueError('Duplicate source unit: ' + str(path))
        if not path.is_file():
            raise ValueError('Missing source unit: ' + str(path))
        value = text(path)
        if any(kind == 'comment' for kind, _ in lexer['tokens'](value)):
            raise ValueError('Production source contains comments: ' + str(path))
        if value and not value.endswith('\n'):
            raise ValueError('Source unit needs a final newline: ' + str(path))
        visited.add(path)
        count = len(value.splitlines(keepends=True))
        if count:
            segments.append({'generated_line': line_number, 'source': path.relative_to(root).as_posix(),
                             'source_line': 1, 'lines': count})
        chunks.append(value)
        line_number += count
    expected = {p.resolve() for p in source_root.rglob('*.lua') if p.resolve() != generated}
    if visited != expected:
        raise ValueError('Unregistered source units: ' + ', '.join(str(p.relative_to(root)) for p in sorted(expected - visited)))
    code = ''.join(chunks)
    mapping = {'version': 1, 'entry': 'src/manifest.json', 'generated': 'src/auto-play.lua',
               'sha256': hashlib.sha256(code.encode('utf-8')).hexdigest(), 'segments': segments}
    return code, mapping


def distribution():
    source, mapping = assemble()
    source = compact(source)
    mapping['format'] = 'compact, line-preserving'
    mapping['sha256'] = hashlib.sha256(source.encode('utf-8')).hexdigest()
    tests = ROOT / 'tests'
    runner = text(tests / 'runner.lua')
    cases = re.findall(r"\{'(huss-[^']+\.spec\.lua)','([^']+)'\}", runner)
    manifest = json.loads(text(tests / 'manifest.json'))
    if not cases or len(cases) != len({name for name, _ in cases}):
        raise ValueError('Runner must contain unique test cases')
    if set(manifest) != {name for name, _ in cases}:
        raise ValueError('Test manifest and runner cases differ')
    paths = []
    for name, _ in cases:
        path = (tests / manifest[name]).resolve()
        if not path.is_relative_to(tests.resolve()) or not path.is_file():
            raise ValueError('Missing or invalid fixture path: ' + name)
        paths.append(path)
    fixtures = {p.resolve() for folder in ('core', 'runtime')
                for p in (tests / folder).glob('*.spec.lua')}
    if set(paths) != fixtures or len(paths) != len(set(paths)):
        raise ValueError('Every fixture must appear exactly once in the manifest')
    encode = lambda value: json.dumps(value, ensure_ascii=False, separators=(',', ':'))
    table = '{' + ','.join('[' + encode(name) + ']=' + encode(text(path))
                           for (name, _), path in zip(cases, paths)) + '}'
    bundle = (
        'local source=game:HttpGet("https://raw.githubusercontent.com/BubbleGB/Huss-Valley-Auto/main/src/auto-play.lua")\n'
        'local suite=assert(loadstring(' + encode(runner) + '))()\n'
        'local tests=' + table + '\n'
        'local report=suite(source,tests)\n'
        "print(string.format('Huss tests: %d passed, %d failed, %d decision checks',report.passed,report.failed,report.decisionChecks))\n"
        'return report\n'
    )
    outputs = {
        'src/auto-play.lua': source.encode('utf-8'),
        'dist/source-map.json': (json.dumps(mapping, indent=2) + '\n').encode('utf-8'),
        'dist/huss-auto-cross.txt': source.encode('utf-8'),
        'dist/huss-test-suite.txt': bundle.encode('utf-8'),
    }
    checksums = ''.join(hashlib.sha256(data).hexdigest() + '  ' + Path(name).name + '\n'
                        for name, data in sorted(outputs.items()) if name.startswith('dist/'))
    outputs['dist/SHA256SUMS'] = checksums.encode('utf-8')
    return outputs, len(cases)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Fail if dist files are stale; do not write')
    args = parser.parse_args()
    try:
        outputs, count = distribution()
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, 'Build failed: ' + str(error) + '\n')
    stale = []
    for name, content in outputs.items():
        destination = ROOT / name
        if args.check:
            if not destination.exists() or destination.read_bytes() != content:
                stale.append(name)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
    if stale:
        parser.exit(1, 'Stale distribution: ' + ', '.join(stale) + '\nRun python3 tools/build.py\n')
    print(('Checked' if args.check else 'Built') + f' distribution: {count} suites, compiled source, source map and checksums')


if __name__ == '__main__':
    main()
