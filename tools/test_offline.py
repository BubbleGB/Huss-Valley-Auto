#!/usr/bin/env python3
"""Run explicitly detached fixtures in CLI Luau; does not emulate the Roblox engine."""
import argparse
import json
import hashlib
import re
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CORE = ('auto-cross', 'detours', 'progression', 'reactions', 'settings', 'smart-policy', 'speed', 'tp')
RUNTIME = ('client-metrics', 'lobby-input', 'lobby-navigation', 'lobby-ui',
           'lobby-workflow', 'operation', 'server-status', 'terrain-geometry',
           'user-status', 'window-lease', 'consumables', 'progression')

def quote(value):
    sep = '='
    while ']' + sep + ']' in value:
        sep += '='
    return '[' + sep + '[' + value + ']' + sep + ']'

def program():
    source = (ROOT / 'src/auto-play.lua').read_text()
    shim = (ROOT / 'tests/offline/math.lua').read_text()
    result = ['local types=(function()\n' + shim + '\nend)()',
              'for k,v in pairs(types)do getfenv()[k]=v end',
              'local nativeTypeof=typeof; getfenv().typeof=function(v) local m=type(v)=="table" and getmetatable(v);return m and m.__type or nativeTypeof(v)end',
              'local source=' + quote(source),
              "local marker=assert(source:find('assert(game.PlaceId',1,true))",
              "local Core=assert(loadstring(source:sub(1,marker-1)..'\\nreturn Core'))()",
              'local failed=0;local passed=0;local checks=0',
              'local function run(name,body,arg) local started=os.clock();local ok,r=pcall(function()return assert(loadstring(body))()(arg)end);if ok then passed+=1;checks+=type(r)=="table" and(r.passed or 0)or 0 else failed+=1 end;print((ok and "PASS "or "FAIL ")..name.." "..(ok and ""or tostring(r)).." seconds="..(os.clock()-started))end']
    for name in CORE:
        path = ROOT / 'tests/core' / (name + '.spec.lua')
        result.append('run(' + quote('core/' + path.name) + ',' + quote(path.read_text()) + ',Core)')
    for name in RUNTIME:
        path = ROOT / 'tests/runtime' / (name + '.spec.lua')
        result.append('run(' + quote('runtime/' + path.name) + ',' + quote(path.read_text()) + ',source)')
    for path in sorted((ROOT / 'tests/offline').glob('*.spec.lua')):
        result.append('run(' + quote('offline/' + path.name) + ',' + quote(path.read_text()) + ',source)')
    result.extend(['print("RESULT passed="..passed.." failed="..failed.." checks="..checks)', 'assert(failed==0,"offline fixture failures")'])
    return '\n'.join(result)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', default='luau')
    parser.add_argument('--compiler', help='Optional luau-compile binary; compiles all standalone Lua and the assembled executable')
    parser.add_argument('--report', type=Path, help='Write machine-readable results')
    args = parser.parse_args()
    report = {'environment': 'offline-cli-luau', 'source_sha256': hashlib.sha256((ROOT / 'src/auto-play.lua').read_bytes()).hexdigest()}
    if args.compiler:
        fragments = {ROOT / 'src/main.lua', ROOT / 'src/runtime/start.lua'}
        files = sorted(p for folder in ('src', 'tests', 'vendor') for p in (ROOT / folder).rglob('*.lua') if p not in fragments)
        compiled = subprocess.run([args.compiler, '--null', *map(str, files)], text=True, capture_output=True)
        report['compilation'] = {'files': len(files), 'passed': compiled.returncode == 0}
        if compiled.returncode:
            report['success'] = False
            if args.report:
                args.report.parent.mkdir(parents=True, exist_ok=True)
                args.report.write_text(json.dumps(report, indent=2) + '\n')
            print(compiled.stdout, compiled.stderr)
            raise SystemExit(compiled.returncode)
        print('COMPILE PASS files=' + str(len(files)))
    with tempfile.TemporaryDirectory(prefix='huss-offline-') as folder:
        path = Path(folder) / 'suite.luau'
        path.write_text(program())
        completed = subprocess.run([args.luau, str(path)], text=True, capture_output=True)
        print(completed.stdout, end='')
        if completed.stderr:
            print(completed.stderr, end='')
        report['suites'] = [{'name': match[2], 'passed': match[1] == 'PASS'} for match in re.finditer(r'^(PASS|FAIL) ([^ ]+)', completed.stdout, re.M)]
        counts = re.search(r'RESULT passed=(\d+) failed=(\d+) checks=(\d+)', completed.stdout)
        if counts:
            report.update(zip(('passed', 'failed', 'checks'), map(int, counts.groups())))
        report['success'] = completed.returncode == 0
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + '\n')
        raise SystemExit(completed.returncode)
