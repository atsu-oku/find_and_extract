# 🛠️ find_and_extract.sh

Automation toolkit for finding staging artefacts, converting them to production-safe values, and rolling changes back without guesswork. Designed for the migration runbooks used by the ops team.

---

## 🧭 Table of Contents

1. [Overview](#overview)
2. [✨ Key Features](#-key-features)
3. [📂 Repository Structure](#-repository-structure)
4. [🚀 Quick Start](#-quick-start)
5. [🧪 Command Reference](#-command-reference)
6. [🔧 Transform Workflow](#-transform-workflow)
7. [🛡️ Safety Nets & Exclusions](#-safety-nets--exclusions)
8. [🗃️ Logs & Artefacts](#-logs--artefacts)
9. [📚 Related Documentation](#-related-documentation)
10. [🌐 Localization & Changelog](#-localization--changelog)

---

## Overview

- **Language / Shell**: Bash 4.0+
- **Supported hosts**: RHEL / CentOS family, script executed locally
- **Working dir**: `/tmp/<user>/find_and_extract/` (auto-created, mode 700)
- **Primary outputs**: scan summaries, transform previews/apply logs, rollback metadata

---

## ✨ Key Features

- End-to-end lifecycle:
  - `scan` 🧭 read-only inventory of staging vs. production markers
  - `transform` 🔄 preview and apply conversion rules with backups and prompts
  - `rollback` ⏪ restore files from transform logs
- `/etc/profile` hygiene 🧼:
  - Converts staging IP/hostname tokens to PRD values
  - Appends `http_proxy` / `https_proxy` / `HTTP_PROXY` / `HTTPS_PROXY` with `http://172.16.162.6:3128/` when missing
- Treasure Data repo regeneration 📦:
  - Picks CentOS 6 (v3), RHEL 7 (v4), or RHEL 9 (v4) base URLs automatically
  - Switches GPG key to the S3-hosted location and verifies `repodata/repomd.xml` reachability
- Sensible defaults 🙌:
  - Skips editor artefacts (`*.save`, filenames containing `YYYYMMDD`)
  - Prompts before writing changes; mirrors backups next to originals

---

## 📂 Repository Structure

| Path | Description |
|------|-------------|
| `find_and_extract.sh` | CLI entrypoint exposing `scan`, `transform`, `rollback`. |
| `CHANGELOG.md` / `CHANGELOG_ja.md` | Release timeline (English / Japanese). |
| `docs/FIND_AND_EXTRACT_TOOL.md` | Exhaustive operator playbook (JP). |
| `docs/PROJECT_SPEC_SH.md` | Shell variant specification and safety checklist. |
| `schemas/` | JSON schemas for CLI arguments and output payloads. |
| `generate_td_agent_conf.sh` | td-agent configuration helper script. |

---

## 🚀 Quick Start

```bash
./find_and_extract.sh scan /etc
./find_and_extract.sh transform --dry-run /var
./find_and_extract.sh transform --apply /var
./find_and_extract.sh rollback --file /etc/hosts \
    /tmp/$USER/find_and_extract/$(hostname)_<timestamp>_transform.log
```

Before running:

1. ✅ Confirm read access to the target tree and sufficient `/tmp` space.
2. ✅ Ensure Bash 4+ is available. `curl` is optional but recommended.
3. ✅ For `--apply`, double-check that writing backups beside originals is acceptable.

---

## 🧪 Command Reference

| Subcommand | Purpose | Output Highlights |
|------------|---------|-------------------|
| `scan` | Read-only inventory of staging vs. production artefacts. | `<host>_<ts>_{current_infra,new_infra_stg,new_infra_prd,other,mixed}.log` |
| `transform` | Convert staging tokens to PRD equivalents. Dry-run by default. | `*_transform_preview.log`, `*_transform.log` |
| `rollback` | Restore files from transform log backups. | Summary on stdout |

### Common Options

- `-v, --verbose` – emit detailed progress logs.
- `--skip-backup-files` – ignore known backup filenames (`*.bak`, `*~`, `.swp`, etc.).
- `--dry-run` / `--apply` – control transform mode.
- `--file <path>` – scope rollback to specific entries.
- `--deletelogs` – purge `/tmp/<user>/find_and_extract/` logs.

---

## 🔧 Transform Workflow

1. **Preflight**
   - When targeting `/var`, validates `/var/www/com/ipet-ins/<system>/fuel/app/config/newproduction/` and records missing artefacts in the warnings log.
   - Preserves protected configuration files such as `/etc/nginx/nginx.conf` and `/etc/httpd/httpd.conf`.

2. **Candidate selection**
   - Mirrors `scan` traversal but additionally skips:
     - Binary or >10 MiB files
     - Backup-looking names when `--skip-backup-files` is supplied
     - `*.save` and filenames containing eight-digit dates (`YYYYMMDD`)

3. **Conversion**
   - Applies IP / hostname / token rewrites via embedded AWK.
   - `/etc/profile` receives PRD tokens and fixed proxy exports (only when absent).
   - `/etc/yum.repos.d/td.repo` is regenerated with OS-specific base URLs, S3-hosted GPG key, and connectivity testing (`curl --head`).

4. **Dry-run**
   - Outputs tidy “As-Is / To-Be” diffs to stdout and logs, ensuring reviewers see every prospective change.

5. **Apply**
   - Prompts for confirmation (`yes` / `y`). Any other response prints an invalid-input reminder and cancels.
   - Writes `*_YYYYMMDD_HHMM.bak` backups, restores permissions/ownership, and records every change in `*_transform.log`.

---

## 🛡️ Safety Nets & Exclusions

- Protected files: nginx / Apache configs and other ACL-sensitive paths are never altered.
- Explicit skips:
  - Binary files, oversize files (>10 MiB)
  - Backup or editor artefacts (including `.save` and `YYYYMMDD` patterns)
- Interrupt handling:
  - First `Ctrl+C` → cleanup of temp files, message printed.
  - Second `Ctrl+C` → forced exit after additional warning.
- td-agent repo regeneration uses `curl` to detect network issues and surfaces the status for operators.

---

## 🗃️ Logs & Artefacts

| File | Description |
|------|-------------|
| `<host>_<ts>_current_infra.log` etc. | Categorised scan results. |
| `<host>_<ts>_warnings.log` | Validation / connectivity warnings. |
| `<host>_<ts>_transform_preview.log` | Dry-run diff summaries. |
| `<host>_<ts>_transform.log` | Applied change manifest with backup metadata. |
| `*_YYYYMMDD_HHMM.bak` | Backups created during `--apply`. |

Use `--deletelogs` for log housekeeping.

---

## 📚 Related Documentation

- 📝 Operator Guide (JP): [`docs/FIND_AND_EXTRACT_TOOL.md`](docs/FIND_AND_EXTRACT_TOOL.md)
- 📘 Shell Variant Spec (JP): [`docs/PROJECT_SPEC_SH.md`](docs/PROJECT_SPEC_SH.md)
- 🧰 td-agent Config Helper: [`generate_td_agent_conf.sh`](generate_td_agent_conf.sh)
- 📦 JSON Schemas: [`schemas/`](schemas/)

---

## 🌐 Localization & Changelog

- English changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Japanese changelog: [`CHANGELOG_ja.md`](CHANGELOG_ja.md)
- Japanese README: [`README_ja.md`](README_ja.md)

Latest updates (v3.6.3.0, 2025-11-05) cover:

- `/etc/profile` proxy normalisation
- td-agent repository refresh logic with connectivity probes
- Expanded file exclusion rules to avoid editor/temporary artefacts

Happy automating! 🚀

