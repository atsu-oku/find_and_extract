# find_and_extract Tool

`find_and_extract.sh` lets operators audit staging artefacts, convert them to production values, and roll changes back safely. This directory contains the Bash CLI, documentation, schemas, and helper scripts that accompany the tool.

## Repository Layout

- `find_and_extract.sh` – main Bash entry point (`scan`, `transform`, `rollback`).
- `CHANGELOG.md` – release timeline.
- `docs/` – operator guide (`FIND_AND_EXTRACT_TOOL.md`) and lightweight spec (`PROJECT_SPEC_SH.md`).
- `schemas/` – JSON schema for CLI options and transform output.
- `generate_td_agent_conf.sh` – td-agent configuration helper script.

## CLI Usage

```bash
./find_and_extract.sh scan /etc
./find_and_extract.sh transform --dry-run /var
./find_and_extract.sh transform --apply /var
./find_and_extract.sh rollback --file /etc/hosts \
    /tmp/$USER/find_and_extract/$(hostname)_<timestamp>_transform.log
```

Highlights:

- `scan` is read-only and reports staging vs. production signatures.
- `transform --dry-run` previews replacements. `--apply` now prompts to clone `fuel/app/config/newstaging/` into `newproduction/` (when needed) and only then applies PRD substitutions, writing backups and a rollback log.
- `rollback` consumes the transform log and restores the recorded backups. Use `--file` to limit the scope.

Consult the guides in `docs/` for deeper operational details and rollout procedures.
