#!/usr/bin/env bash
# study-reminder-deploy -- personal commitment-device installer for study-reminder.
#
# Clones nimapdevyash/study-reminder into a randomly-named folder (README.md
# and .git stripped), and can install a systemd --user timer that re-runs
# `check` at boot and periodically: if the deployed copy is missing or its
# loop isn't running, it gets redeployed / restarted automatically.
#
# The deployed copy's only real off switch stays daddy_please_stop, inside
# it. This tool just makes sure the copy exists and its loop is up.
#
#   ./deploy.sh deploy   # force a fresh clone into a (new) random-named dir
#   ./deploy.sh check    # ensure it exists and is running; redeploy if not
#   ./deploy.sh install  # install the boot/periodic systemd --user timer
#   ./deploy.sh uninstall-watchdog  # remove the timer (leaves the deployed copy alone)
set -euo pipefail

REPO_SLUG="nimapdevyash/study-reminder"
BRANCH="main"
BASE="${STUDY_DEPLOY_BASE:-$HOME/.local/share}"
STATE_DIR="$HOME/.local/state/study-reminder-deploy"
STATE_FILE="$STATE_DIR/target"
LOCK_FILE="$STATE_DIR/lock"
HERE="$(cd "$(dirname "$0")" && pwd)"

say() { printf '[deploy] %s\n' "$*"; }

ADJ="quiet calm brisk amber violet cedar dusty golden lucid mellow rapid silent solar tidal vivid"
NOUN="otter falcon harbor meadow lantern compass ember thicket ridge summit brook glade heron nook"

rand_word() {
  local words=($1) n=${#words[@]}
  echo "${words[$(( RANDOM % n ))]}"
}

pick_name() {
  echo "$(rand_word "$ADJ")-$(rand_word "$NOUN")"
}

target_dir() {
  mkdir -p "$STATE_DIR"
  if [ -f "$STATE_FILE" ]; then
    local t; t="$(cat "$STATE_FILE")"
    [ -n "$t" ] && { echo "$t"; return; }
  fi
  local name; name="$(pick_name)"
  while [ -e "$BASE/$name" ]; do name="$(pick_name)"; done
  local t="$BASE/$name"
  echo "$t" > "$STATE_FILE"
  echo "$t"
}

deploy() {
  local t; t="$(target_dir)"
  local tmp; tmp="$(mktemp -d)"

  say "cloning $REPO_SLUG@$BRANCH into staging dir"
  git clone -q --depth 1 -b "$BRANCH" "https://github.com/$REPO_SLUG.git" "$tmp"

  local sha; sha="$(git -C "$tmp" rev-parse HEAD)"
  rm -rf "$tmp/.git" "$tmp/README.md"
  mkdir -p "$tmp/var"
  printf '%s\n' "$sha" > "$tmp/var/installed-sha"
  chmod +x "$tmp"/*.sh 2>/dev/null || true

  rm -rf "$t"
  mkdir -p "$(dirname "$t")"
  mv "$tmp" "$t"
  say "deployed at $t"

  release_lock
  "$t/study-reminder.sh" start
}

check() {
  local t; t="$(target_dir)"
  if [ -x "$t/study-reminder.sh" ]; then
    release_lock
    "$t/study-reminder.sh" start >/dev/null 2>&1 || true
    say "ensured running at $t"
  else
    say "not found at $t -- redeploying"
    deploy
  fi
}

# the loop `study-reminder.sh start` backgrounds inherits our fds unless we
# close them first -- otherwise it holds the flock open forever (it never
# exits) and every later deploy/check call sees "in progress" indefinitely.
release_lock() {
  exec 9>&- 2>/dev/null || true
}

with_lock() {
  mkdir -p "$STATE_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || { say "another deploy is already in progress, skipping"; return 0; }
  fi
  "$1"
}

install_watchdog() {
  local unit_dir="$HOME/.config/systemd/user"
  mkdir -p "$unit_dir"
  sed "s|__DEPLOY__|$HERE/deploy.sh|" "$HERE/study-reminder-watchdog.service" \
    > "$unit_dir/study-reminder-watchdog.service"
  cp "$HERE/study-reminder-watchdog.timer" "$unit_dir/study-reminder-watchdog.timer"
  systemctl --user daemon-reload
  systemctl --user enable --now study-reminder-watchdog.timer
  say "watchdog timer installed and enabled"
  check
}

uninstall_watchdog() {
  systemctl --user disable --now study-reminder-watchdog.timer >/dev/null 2>&1 || true
  rm -f "$HOME/.config/systemd/user/study-reminder-watchdog.timer" \
        "$HOME/.config/systemd/user/study-reminder-watchdog.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  say "watchdog timer removed (deployed copy left as-is)"
}

case "${1:-check}" in
  deploy)             with_lock deploy ;;
  check)              with_lock check ;;
  install)            install_watchdog ;;
  uninstall-watchdog) uninstall_watchdog ;;
  *) echo "usage: $0 {deploy|check|install|uninstall-watchdog}" >&2; exit 1 ;;
esac
