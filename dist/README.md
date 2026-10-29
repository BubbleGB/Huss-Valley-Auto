# Ready to run

| File | Use |
| --- | --- |
| [huss-auto-cross.txt](huss-auto-cross.txt) | Main script: copy to the Delta workspace and execute |
| [huss-test-suite.txt](huss-test-suite.txt) | Optional full test run against the main script in that workspace |
| [source-map.json](source-map.json) | Map generated executable lines back to editable source |
| [SHA256SUMS](SHA256SUMS) | Checksums for generated distribution files |

The main panel starts paused. Press **Start** to play, **Stop** to pause or **X**
to unload. See the [usage guide](../docs/usage.md) for the controls and behavior.

These files are generated from [src/](../src/) and [tests/](../tests/).
Rebuild with `python3 tools/build.py` from the repository root.
