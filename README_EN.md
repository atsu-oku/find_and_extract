# 🛠️ find_and_extract.sh

Automation toolkit for spotting staging artefacts, converting them to production-safe values, and rolling changes back without guesswork. This document covers the English edition; the Japanese primary README is [`README.md`](README.md).

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
- **Supported hosts**: RHEL / CentOS family (script runs locally)
- **Working directory**: `/tmp/<user>/find_and_extract/` (auto-created, mode 700)
- **Primary outputs**: scan summaries, transform previews/apply logs, rollback metadata

---

## ✨ Key Features

- End-to-end lifecycle:
  - `scan` 🧭 inventory staging vs. production signatures (read-only)
  - `transform` 🔄 preview and apply conversion rules with prompts and backups
  - `rollback` ⏪ restore files from transform-generated metadata
- `/etc/profile` hygiene 🧼:
  - Converts staging IP/hostname/`stg` tokens to PRD equivalents
  - Appends `http_proxy`, `https_proxy`, `HTTP_PROXY`, `HTTPS_PROXY` with `http://172.16.162.6:3128/` when missing
- Treasure Data repo regeneration 📦:
  - Selects CentOS 6 (v3), RHEL 7 (v4), or RHEL 9 (v4) URLs automatically
  - Switches the GPG key to the S3-hosted location and HEAD-checks `repodata/repomd.xml`
- Smart exclusions 🙌:
  - Skips editor artefacts (`*.save`, filenames containing `YYYYMMDD`)
  - Ignores binaries, large files (>10 MiB), or backup-looking names when requested

---

## 📂 Repository Structure

| Path | Description |
|------|-------------|
| `find_and_extract.sh` | CLI entrypoint exposing `scan`, `transform`, `rollback`. |
| `CHANGELOG.md` / `CHANGELOG_ja.md` | Release notes (EN / JP). |
| `docs/FIND_AND_EXTRACT_TOOL.md` | Japanese operator guide (detailed). |
| `docs/PROJECT_SPEC_SH.md` | Shell variant spec and safeguards. |
| `schemas/` | JSON schemas for CLI parameters and outputs. |
| `generate_td_agent_conf.sh` | td-agent configuration helper. |

---

## 🚀 Quick Start

```bash
./find_and_extract.sh scan /etc
./find_and_extract.sh transform --dry-run /var
./find_and_extract.sh transform --apply /var
./find_and_extract.sh rollback --file /etc/hosts     /tmp/$USER/find_and_extract/$(hostname)_<timestamp>_transform.log
```

Before running:

1. ✅ Confirm read permissions on the target tree and ensure `/tmp` has free space.
2. ✅ Make sure Bash 4+ is installed; `curl` is optional but handy for repo checks.
3. ✅ Remember that `--apply` writes `*.bak_<timestamp>` backups alongside originals.

---

## 🧪 Command Reference

| Subcommand | Purpose | Output Highlights |
|------------|---------|-------------------|
| `scan` | Read-only classification of staging vs. production artefacts. | `<host>_<timestamp>_{current_infra,new_infra_stg,new_infra_prd,other,mixed}.log` |
| `transform` | Convert staging values to PRD equivalents. Dry-run by default. | `*_transform_preview.log`, `*_transform.log` |
| `rollback` | Restore files from transform log backups. | Summary on stdout |

### Common Options

- `-v, --verbose` – emit detailed progress (including skip reasons).
- `--skip-backup-files` – ignore known backup patterns (`*.bak`, `*~`, `.swp`, etc.).
- `--dry-run` / `--apply` – control transform mode.
- `--file <path>` – narrow rollback scope.
- `--deletelogs` – purge `/tmp/<user>/find_and_extract/` logs.

---

## 🔧 Transform Workflow

1. **Preflight** – validates `/var/www/com/ipet-ins/<system>/fuel/app/config/newproduction/` when targeting `/var`, recording missing artefacts in the warnings log.
2. **Candidate selection** – mirrors `scan`, then excludes binaries, >10 MiB files, backups, `*.save`, and filenames containing eight-digit dates.
3. **Conversion** – embedded AWK rewrites IPs, hostnames, tokens; `/etc/profile` gains PRD tokens + fixed proxies; `/etc/yum.repos.d/td.repo` is regenerated via OS detection and connectivity probe.
4. **Dry-run** – formatted “As-Is / To-Be” diffs printed and saved.
5. **Apply** – prompts for confirmation (`yes` / `y`), writes `*_YYYYMMDD_HHMM.bak` backups, restores metadata, logs results.

---

## 🛡️ Safety Nets & Exclusions

- Immutable file list covers nginx / Apache configs and other sensitive paths.
- Interrupt handling cleans up temp files on the first `Ctrl+C`; a second interrupt forces exit.
- Treasure Data repo regeneration reports connectivity status before writing.

---

## 🗃️ Logs & Artefacts

| File | Description |
|------|-------------|
| `<host>_<timestamp>_current_infra.log` etc. | Categorised scan hits. |
| `<host>_<timestamp>_warnings.log` | Validation / connectivity warnings. |
| `<host>_<timestamp>_transform_preview.log` | Dry-run diff summaries. |
| `<host>_<timestamp>_transform.log` | Applied change manifest with backup metadata. |
| `*_YYYYMMDD_HHMM.bak` | Backups created during `--apply`. |

Use `--deletelogs` for log housekeeping.

---

## 📚 Related Documentation

- 📝 Operator Guide (JP): [`docs/FIND_AND_EXTRACT_TOOL.md`](docs/FIND_AND_EXTRACT_TOOL.md)
- 📘 Shell Variant Spec (JP): [`docs/PROJECT_SPEC_SH.md`](docs/PROJECT_SPEC_SH.md)
- 🧰 td-agent helper: [`generate_td_agent_conf.sh`](generate_td_agent_conf.sh)
- 📦 JSON schemas: [`schemas/`](schemas/)

---

## 🌐 Localization & Changelog

- Japanese main README: [`README.md`](README.md)
- English changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Japanese changelog: [`CHANGELOG_ja.md`](CHANGELOG_ja.md)

Latest updates (v3.6.3.0, 2025-11-05) include `/etc/profile` proxy normalisation, td-agent repo regeneration improvements, and expanded exclusion rules. Happy automating! 🚀
