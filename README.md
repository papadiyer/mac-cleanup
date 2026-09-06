# mac-cleanup

A safe, scriptable **macOS + dev-tool garbage cleaner**. It reclaims disk space
from the native caches, logs, temp files, and developer caches that quietly pile
up on a Mac — with a **dry-run by default** so nothing is ever deleted without
you asking for it.

Pairs with **CCleaner** (optional — see below): this script automates the native
and dev-tool layer, while CCleaner's GUI handles app-specific junk (browsers,
per-application caches). The script **detects** CCleaner if it's installed, but
runs perfectly well without it — the engine is native.

## Features

- **Dry-run by default** — reports what it *would* free, deletes nothing
- **Safe native targets** — user app caches, Xcode `DerivedData`, npm/pip caches,
  old logs & temp, Trash, Homebrew stale bottles
- **`--aggressive`** — larger/optional targets: `~/.cache` (Hermes/browser
  caches), Docker prune, old system logs
- **CCleaner detected (optional)** — the script notes if CCleaner `com.piriform.ccleaner`
  is installed; runs fine without it (engine is native).
- **`--json`** — machine-readable summary output

## Requirements

- macOS
- Bash (built-in)
- CCleaner for Mac **optional** (detected if present; not required — engine is native)
- Optional, only if you want those targets: `npm` / `pip3` / `brew` / `docker`

## Quickstart

```bash
chmod +x mac_cleanup.sh

./mac_cleanup.sh                           # read-only STATUS report (safe, no delete)
./mac_cleanup.sh --status --json           # machine-readable status
./mac_cleanup.sh --clean --approve=YOU     # reclaim safe targets (HUMAN-APPROVED only)
./mac_cleanup.sh --clean --aggressive --approve=YOU   # + big caches, Docker, system logs
```

`--help` prints usage.

## Governance (fail-closed)

This tool is **human-gated** — it never deletes on its own.

- **Agent-safe (read-only):** `--status` / default reports disk free, what's
  reclaimable, and why. Deletes nothing. An agent may run this freely to inform
  a human.
- **Destructive = P5 gate:** any deletion (`--clean`, `--aggressive`) requires an
  explicit **`--approve=<who>`** token representing human authorization. Without
  it the script **refuses and exits 1** (fail-closed) — it will not write a
  single byte.
- **Never auto-touched:** user documents/data (movies, CloudStorage),
  `~/Library/Containers` (app sandboxes, enterprise/Intune-managed),
  `~/Library/Group Containers`, and system paths. Only caches/logs/temp/dev-tool
  junk is candidate.

So the flow is: **agent reports (status) → human reviews → human approves →
clean runs** (with the approving identity logged). That matches the principle
that `rm` is a P5-level action requiring human approval.

## How it works

The script measures each candidate with `du`, shows the reclaimable size, and
(only in `--clean` mode) deletes it. It errs on the side of keeping recent logs
(`-mtime +N`) and never touches user documents. It is transparent about what it
removes — nothing is silently dropped.

## Contributing

Feedback, advice, and pull requests are welcome. Keep the safety posture: always
dry-run by default, never delete without showing the user first.

## License

This project is released under the [MIT License](./LICENSE). You are free to use,
modify, and distribute it per the terms of that license.
