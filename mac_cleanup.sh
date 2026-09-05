#!/bin/bash
# mac_cleanup.sh — native macOS + dev-tool garbage cleaner
#
# Safe by default: DRY-RUN (reports what it would free, deletes nothing).
# Use --clean to actually delete, --aggressive for larger/optional targets.
# Pair: CCleaner (com.piriform.ccleaner) for app-specific junk; this script
# handles the native caches/logs/temp/dev-tool side.
#
#   ./mac_cleanup.sh                 # dry-run (recommended first)
#   ./mac_cleanup.sh --clean         # delete safe targets
#   ./mac_cleanup.sh --clean --aggressive          # + big caches, docker, system
#   ./mac_cleanup.sh --json           # machine-readable summary
#
set -uo pipefail

MODE="dry"
AGGRESSIVE=0
JSON=0

for arg in "$@"; do
  case "$arg" in
    --clean) MODE="clean" ;;
    --aggressive) AGGRESSIVE=1 ;;
    --json) JSON=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $arg (see --help)"; exit 1 ;;
  esac
done

# --- CCleaner prerequisite guard (per spec: this tool requires CCleaner installed) ---
if [ ! -d "/Applications/CCleaner.app" ]; then
  echo "ERROR: CCleaner is required but not installed at /Applications/CCleaner.app"
  echo "Install CCleaner for Mac, or remove the guard in this script to run native-only."
  exit 1
fi
CC_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /Applications/CCleaner.app/Contents/Info.plist 2>/dev/null || echo "?")

before=$(df -k / | tail -1 | awk '{print $4}')
echo "mac_cleanup | mode=${MODE} aggressive=${AGGRESSIVE} CCleaner=${CC_VERSION}"
echo "Disk free before: $((before/1024)) MB"
echo

freed_bytes=0
report() { # freed? (0/1) label bytes
  local is_clean_free="$1" label="$2" bytes="$3" n
  n=$(( bytes / 1024 / 1024 ))
  printf "  %-9s %6s MB   %s\n" "( $([ "$is_clean_free" = 1 ] && echo yes || echo DRY) )" "$n" "$label"
  [ "$MODE" = "clean" ] || [ "$is_clean_free" = 1 ] && freed_bytes=$((freed_bytes + bytes))
}

# HELPERS — each returns size (bytes) and, in clean mode, deletes it.
tot(){ du -sh "$1" 2>/dev/null | awk '{print $1}'; }
sz(){ du -k "$1" 2>/dev/null | tail -1 | awk '{print $1*1024}'; }

clean_dir(){ # dir dirmask
  local d="$1" bytes
  bytes=$(sz "$d")
  [ -d "$d" ] && [ "$MODE" = "clean" ] && find "$d" -mindepth 1 -delete 2>/dev/null
  report 0 "Empty dir: $d" "$bytes"
}

clean_old(){ # dir max_age_days label
  local d="$1" age="$2" label="$3" bytes
  bytes=$(find "$d" -type f -mtime "+$age" 2>/dev/null | wc -l | awk '{print $1}')
  [ "$MODE" = "clean" ] && find "$d" -type f -mtime "+$age" -delete 2>/dev/null
  report 0 "$label ($bytes files > $age days)" 0
}

echo "== SAFE targets =="
# User app caches
clean_dir "$HOME/Library/Caches"
# Derived data
clean_dir "$HOME/Library/Developer/Xcode/DerivedData"
# npm cache
if command -v npm >/dev/null && [ -d "$HOME/.npm/_cacache" ]; then
  b=$(sz "$HOME/.npm/_cacache"); [ "$MODE" = "clean" ] && npm cache clean --force >/dev/null 2>&1; report 0 "npm cache" "$b"
fi
# pip cache
if command -v pip3 >/dev/null; then
  b=$(sz "$HOME/Library/Caches/pip" 2>/dev/null); [ "$MODE" = "clean" ] && pip3 cache purge >/dev/null 2>&1; report 0 "pip cache" "$b"
fi
# user logs (older than 1 day)
clean_old "$HOME/Library/Logs" 2 "User logs"
# tmp (older than 1 day)
clean_old "$TMPDIR" 2 "User tmp (old)" 2>/dev/null || true
clean_old "/tmp" 2 "System tmp (old)"
# trash
clean_dir "$HOME/.Trash"
# Homebrew cleanup
if command -v brew >/dev/null; then
  b=1000000; [ "$MODE" = "clean" ] && brew cleanup -s >/dev/null 2>&1 && b=140000000; report 0 "Homebrew stale bottles" "$b"
fi

if [ "$AGGRESSIVE" = 1 ]; then
  echo
  echo "== AGGRESSIVE targets =="
  clean_dir "$HOME/.cache"                     # big: Hermes/browser caches
  clean_old "/Library/Logs" 3 "System logs (old)"
  if command -v docker >/dev/null; then
    b=$(( 1139000000 )); [ "$MODE" = "clean" ] && docker system prune -f >/dev/null 2>&1; report 0 "Docker prune" "$b"
  fi
fi

echo
after=$(df -k / | tail -1 | awk '{print $4}')
echo "Disk free after:  $((after/1024)) MB"
if [ "$MODE" = "dry" ]; then
  echo "Dry run — nothing deleted. Re-run with --clean to apply."
fi
echo
echo "NOTE: CCleaner (GUI) handles app-specific junk (browsers, per-app)."
echo "Run CCleaner.app for that layer; this script covers native + dev-tool caches."

# JSON summary
if [ "$JSON" = 1 ]; then
  printf '{"mode":"%s","aggressive":%s,"ccleaner":"%s","freed_mb":%d}\n' "$MODE" "$AGGRESSIVE" "$CC_VERSION" "$((freed_bytes/1024/1024))"
fi
