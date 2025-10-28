# find_and_extract Tool

`find_and_extract.sh` is a standalone STG-to-PRD inspection and remediation helper for Linux guests. The script scans a supplied directory tree, reports staging artefacts, and offers in-place transforms plus rollback support.

## Contents

- `find_and_extract.sh` — main CLI with `scan`, `transform`, and `rollback` subcommands.
- `CHANGELOG.md` — release history for the shell tool.
- `docs/` — operator guide and enhancement notes.
- `schemas/find_and_extract_schema.json` — JSON schema describing CLI options and transform results.

## Usage

```bash
./find_and_extract.sh scan /etc
./find_and_extract.sh transform --dry-run /etc
./find_and_extract.sh transform --apply /var
./find_and_extract.sh rollback --file /etc/hosts /tmp/<user>/find_and_extract/<host>_<ts>_transform.log
```

See `docs/PROJECT_SPEC_SH.md` and `docs/FIND_AND_EXTRACT_TOOL.md` for detailed behaviour, safety checks, and rollback guidance.
