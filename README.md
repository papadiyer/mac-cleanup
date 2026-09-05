# mac-cleanup

A safe, scriptable **macOS + dev-tool garbage cleaner**. It reclaims disk space
from the native caches, logs, temp files, and developer caches that quietly pile
up on a Mac — with a **dry-run by default** so nothing is ever deleted without
you asking for it.

Pairs with **CCleaner** (required — see below): this script automates the native
and dev-tool layer, while CCleaner's GUI handles app-specific junk (browsers,
per-application caches).

## Features

- **Dry-run by default** — reports what it *would* free, deletes nothing
- **Safe native targets** — user app caches, Xcode `DerivedData`, npm/pip caches,
  old logs & temp, Trash, Homebrew stale bottles
- **`--aggressive`** — larger/optional targets: `~/.cache` (Hermes/browser
  caches), Docker prune, old system logs
- **CCleaner guard** — requires CCleaner (`com.piriform.ccleaner`) installed
- **`--json`** — machine-readable summary output

## Requirements

- macOS
- **CCleaner for Mac installed** (required by design; the script guards on it)
- Bash (built-in)
- Optional, only if you want those targets: `npm` / `pip3` / `brew` / `docker`

## Quickstart

```bash
chmod +x mac_cleanup.sh

./mac_cleanup.sh                        # dry-run (recommended first)
./mac_cleanup.sh --clean                # actually reclaim safe targets
./mac_cleanup.sh --clean --aggressive   # + big caches, Docker, system logs
./mac_cleanup.sh --json                 # machine-readable summary
```

`--help` prints usage. `--clean` is destructive, so always dry-run first and
review the target list.

## How it works

The script measures each candidate with `du`, shows the reclaimable size, and
(only in `--clean` mode) deletes it. It errs on the side of keeping recent logs
(`-mtime +N`) and never touches user documents. It is transparent about what it
removes — nothing is silently dropped.

## Contributing

Feedback, advice, and pull requests are welcome. Keep the safety posture: always
dry-run by default, never delete without showing the user first.
