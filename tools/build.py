#!/usr/bin/env python3
"""Build or check the Delta distribution using only the Python standard library."""

import argparse
import hashlib
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def text(path):
    return path.read_bytes().decode('utf-8')


def distribution():
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
        "local source=readfile('huss-auto-cross.txt')\n"
        'local suite=assert(loadstring(' + encode(runner) + '))()\n'
        'local tests=' + table + '\n'
        'local report=suite(source,tests)\n'
        "print(string.format('Huss tests: %d passed, %d failed, %d decision checks',report.passed,report.failed,report.decisionChecks))\n"
        'return report\n'
    )
    outputs = {
        'huss-auto-cross.txt': (ROOT / 'src' / 'auto-play.lua').read_bytes(),
        'huss-test-suite.txt': bundle.encode('utf-8'),
    }
    checksums = ''.join(hashlib.sha256(data).hexdigest() + '  ' + name + '\n'
                        for name, data in sorted(outputs.items()))
    outputs['SHA256SUMS'] = checksums.encode('utf-8')
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
        destination = ROOT / 'dist' / name
        if args.check:
            if not destination.exists() or destination.read_bytes() != content:
                stale.append('dist/' + name)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
    if stale:
        parser.exit(1, 'Stale distribution: ' + ', '.join(stale) + '\nRun python3 tools/build.py\n')
    print(('Checked' if args.check else 'Built') + f' distribution: {count} suites, source mirror and checksums')


if __name__ == '__main__':
    main()
