# Development

## Edit source, then build

Start with the [source index](../src/README.md). The editable entry template is
[src/main.lua](../src/main.lua), with focused units under [core](../src/core/) and
[runtime](../src/runtime/). The largest unit currently has 286 lines.

[src/auto-play.lua](../src/auto-play.lua) is generated. Do not edit it directly:
the build replaces it. Its path remains stable for the existing loadstring.

The `-- @include path.lua` lines are expanded at build time. Units share the
entry template's lexical scope and are ordered explicitly; they are not separate
Roblox ModuleScripts. There are no extra runtime HTTP requests or module loaders.
Keep definitions before their consumers, register each new Lua unit once, and
leave a final newline. The builder rejects cycles, duplicates, missing files,
includes outside `src`, includes of the generated output, and unregistered units.

## Build and check

Python 3.9 or newer is sufficient, with no third-party packages.

```sh
python3 tools/build.py
python3 tools/build.py --check
python3 -m unittest discover -s tools
```

The build produces the standalone executable, its identical Delta text mirror,
the optional self-contained game test bundle, [source map](../dist/source-map.json)
and checksums. `--check` detects changed source or stale outputs without writing.
Test fixture names remain stable; [tests/manifest.json](../tests/manifest.json)
maps them to files. Add fixtures to that manifest and [runner](../tests/runner.lua).

The source map records the generated SHA256 and ranges mapping generated line
numbers back to each source file and line. Use the map from the same commit as
the executable when tracing an error.

## Verify behavior

Run the [Roblox suite](testing.md) after behavior changes. Python build tests
verify compilation inputs, determinism, source maps and stale artifacts; they do
not replace native Roblox tests. Historical reports remain under the archive.

See [cleanup measurements](modular-source.md) for what changed and what did not.

## Compact delivery

The build compacts only the generated executable: comments and unnecessary
whitespace are removed while code tokens, string contents, line endings, compiler
pragmas and line numbers are verified. Editable source units stay formatted.
The source map hashes the shipped compact bytes and still maps generated lines
to their original units. No runtime decompressor, obfuscator or extra request is
needed. Unsupported syntax fails the build instead of emitting uncertain output.
See [runtime and size measurements](lightweight-runtime.md).
