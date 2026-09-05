#!/bin/bash
# mac_cleanup.sh — native macOS + dev-tool garbage cleaner (GOVERNED)
#
# GOVERNANCE MODEL: fail-closed, no unsupervised deletion.
#   - READ-ONLY by default (status/dry-run) — agent-safe, deletes nothing.
#   - DESTRUCTIVE apply is HUMAN-P5-GATED: --clean requires an explicit
#     --approve=<who> token. Without it the script REFUSES and exits 1.
#     Never run --clean without a human's explicit go.
#
#   ./mac_cleanup.sh                    # read-only STATUS report (safe, agent-run)
#   ./mac_cleanup.sh --status --json    # machine-readable status
#   ./mac_cleanup.sh --clean --approve=faisal          # delete safe targets
#   ./mac_cleanup.sh --clean --aggressive --approve=faisal  # + big caches/docker
#
set -uo pipefail

MODE="status"
AGGRESSIVE=0
JSON=0
APPROVE=""

for arg in "$@"; do
  case "$arg" in
    --clean) MODE="clean" ;;
    --status) MODE="status" ;;
    --aggressive) AGGRESSIVE=1 ;;
    --json) JSON=1 ;;
    --approve=*) APPROVE="${arg#--approve=}" ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $arg (see --help)"; exit 1 ;;
  esac
done

# --- FAIL-CLOSED GATE: --clean without explicit human approval refuses ---
GOVERNANCE_REFUSED=0
if [ "$MODE" = "clean" ] && [ -z "$APPROVE" ]; then
  echo "[GOVERNANCE] Destructive cleanup requires explicit human approval."
  echo "[GOVERNANCE] Re-run with --approve=<who> (your P5 approval token)."
  echo "[GOVERNANCE] FAIL-CLOSED: refusing to delete anything. (dry-run below)"
  MODE="status"
  GOVERNANCE_REFUSED=1
fi

# --- CCleaner detection (OPTIONAL companion; engine is native) ---
if [ -d "/Applications/CCleaner.app" ]; then
  CC_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /Applications/CCleaner.app/Contents/Info.plist 2>/dev/null || echo "?")
else
  CC_VERSION="not-installed"
fi

before=$(df -k / | tail -1 | awk '{print $4}')
echo "mac_cleanup | mode=${MODE} aggressive=${AGGRESSIVE} CCleaner=${CC_VERSION} approve=${APPROVE:-<none>}"
echo "Disk free: $((before/1024)) MB"
echo

freed_bytes=0
report() { # label bytes  (dry/status = measure+show; clean = delete+show)
  local label="$1" bytes="$2" n
  n=$(( bytes / 1024 / 1024 ))
  printf "  ( %-5s ) %6s MB   %s\n" "$([ "$MODE" = "clean" ] && echo yes || echo DRY)" "$n" "$label"
  [ "$MODE" = "clean" ] && freed_bytes=$((freed_bytes + bytes))
}

sz(){ du -k "$1" 2>/dev/null | tail -1 | awk '{print $1*1024}'; }
# SAFETY GUARD (defense-in-depth): a target must never be the root, the home dir,
# or a mount point — this is the catastrophic-wipe case. Refuses (exit 1) if so.
assert_safe_target(){
  local t="$1"
  [ "$t" = "/" ] && { echo "[SAFETY] Refusing to delete filesystem root: $t"; exit 1; }
  [ "$t" = "$HOME" ] && { echo "[SAFETY] Refusing to delete home dir: $t"; exit 1; }
  [ -z "$t" ] && { echo "[SAFETY] Empty target — refusing."; exit 1; }
}
clean_dir(){ local d="$1"; local b; b=$(sz "$d"); [ "$MODE" = "clean" ] && { assert_safe_target "$d"; find "$d" -mindepth 1 -delete 2>/dev/null; }; report "cache dir: $d" "$b"; }
clean_old(){ local d="$1" age="$2" label="$3"; local n; n=$(find "$d" -type f -mtime "+$age" 2>/dev/null | wc -l | awk '{print $1}'); [ "$MODE" = "clean" ] && { assert_safe_target "$d"; find "$d" -type f -mtime "+$age" -delete 2>/dev/null; }; report "$label ($n files > $age days)" 0; }

echo "== TIER-A: re-downloadable caches (lowest risk) =="
clean_dir "$HOME/Library/Caches"
clean_dir "$HOME/Library/Developer/Xcode/DerivedData"
if command -v npm >/dev/null && [ -d "$HOME/.npm/_cacache" ]; then b=$(sz "$HOME/.npm/_cacache"); [ "$MODE" = "clean" ] && npm cache clean --force >/dev/null 2>&1; report "npm cache" "$b"; fi
if command -v pip3 >/dev/null; then b=$(sz "$HOME/Library/Caches/pip" 2>/dev/null); [ "$MODE" = "clean" ] && pip3 cache purge >/dev/null 2>&1; report "pip cache" "$b"; fi
clean_dir "$HOME/.Trash"

echo "== TIER-B: logs/tmp (recent kept, needs care) =="
clean_old "$HOME/Library/Logs" 2 "User logs"
clean_old "$TMPDIR" 2 "User tmp (old)"
clean_old "/tmp" 2 "System tmp (old)"
if command -v brew >/dev/null; then b=0; [ "$MODE" = "clean" ] && brew cleanup -s >/dev/null 2>&1; report "Homebrew stale bottles" "${b:-0}"; fi

if [ "$AGGRESSIVE" = 1 ]; then
  echo "== TIER-A+ (aggressive caches) =="
  clean_dir "$HOME/.cache"
  clean_old "/Library/Logs" 3 "System logs (old)"
  if command -v docker >/dev/null; then b=1139000000; [ "$MODE" = "clean" ] && docker system prune -f >/dev/null 2>&1; report "Docker prune" "$b"; fi
fi

echo
if [ "$MODE" = "status" ]; then
  echo "STATUS: read-only. Nothing deleted. Destructive apply (--clean) is"
  echo "HUMAN-P5-GATED: needs --approve=<who>. Agent may report but must never"
  echo "delete unsupervised. Run '--clean --approve=faisal' to apply ON YOUR GO."
  echo
  echo "NOT AUTO-TOUCHED (never clean these):"
  echo "  - User documents/data (movies/OneDrive/CloudStorage)"
  echo "  - ~/Library/Containers (app sandboxes, enterprise/Intune-managed)"
  echo "  - ~/Library/Group Containers (cloud/enterprise data)"
  echo "  - /Library (system, needs sudo)"
else
  echo "APPLIED with approval from: ${APPROVE}"
fi

after=$(df -k / | tail -1 | awk '{print $4}')
echo "Disk free after:  $((after/1024)) MB"

if [ "$JSON" = 1 ]; then
  printf '{"mode":"%s","aggressive":%s,"ccleaner":"%s","approve":"%s","free_before_mb":%d,"free_after_mb":%d,"freed_mb":%d}\n' \
    "$MODE" "$AGGRESSIVE" "$CC_VERSION" "${APPROVE:-}" $((before/1024)) $((after/1024)) $((freed_bytes/1024/1024))
fi

# FAIL-CLOSED: signal refusal so callers/agents never mistake it for a success.
if [ "$GOVERNANCE_REFUSED" = 1 ]; then
  echo "GOVERNANCE: EXIT 1 — refused destructive cleanup (no action taken)."
  exit 1
fi
exit 0
