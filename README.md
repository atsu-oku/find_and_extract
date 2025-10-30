# find_and_extract Tool

`find_and_extract.sh` is a standalone STG-to-PRD inspection and remediation helper for Linux guests. The script scans a supplied directory tree, reports staging artefacts, and offers in-place transforms plus rollback support.

## Contents

- `find_and_extract.sh` — main CLI with `scan`, `transform`, and `rollback` subcommands.
- `generate_td_agent_conf.sh` — td-agent configuration generator per host role.
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

## td-agent configuration helper

Export `TARGET_HOST` with the node name (e.g. `line-lb01p`) and run the generator:

```bash
TARGET_HOST="line-lb01p" ./generate_td_agent_conf.sh
```

The script infers `LB` / `AP` / `DB` from the hostname suffix, expands the matching templates, and writes:

- Aggregator側設定: `./td-agent_${TARGET_HOST}.conf`
- 送信側設定: `./td-agent_sender_${TARGET_HOST}.conf`

Provide `SERVICE_SLUG_OVERRIDE` if the domain slug portion should differ from the hostname prefix.

Environment overrides for the sender template:

- `FORWARD_HOST` / `FORWARD_PORT` – forward destination (defaults `172.16.161.21:24224`)
- `POS_DIR` – directory for td-agent position files (default `/var/log/td-agent/pos`)
- `NGINX_LOG_DIR`, `APACHE_LOG_DIR`, `APP_LOG_DIR`, `MYSQL_LOG_DIR`, `REDIS_LOG_DIR`

If the hostname suffix does not map to `-lb`, `-ap`, or `-db`, the generator falls back to a combined template that includes every log block (LB/AP/DB).
