# study-reminder-deploy

Personal commitment-device installer for `study-reminder`
(`nimapdevyash/study-reminder`). Not distributed — this is just for my own
machine, to stop me from being able to casually kill the reminder by deleting
its folder.

## What it does

- `./deploy.sh deploy` — clones `study-reminder` fresh into a random
  readable folder name (e.g. `~/.local/share/amber-otter`) under
  `$HOME/.local/share`, strips `.git/` and `README.md` from the copy, and
  starts its loop. The chosen folder name is remembered in
  `~/.local/state/study-reminder-deploy/target`, so future runs reuse it.
- `./deploy.sh check` — the idempotent version: if the deployed copy is
  missing, redeploys it; if it's there, just makes sure its loop is running
  (`study-reminder.sh start` is already a no-op if it's already up).
- `./deploy.sh install` — installs a `systemd --user` timer
  (`study-reminder-watchdog.timer`) that runs `check` ~2 minutes after every
  boot and every 20 minutes after that.
- `./deploy.sh uninstall-watchdog` — removes the timer only. Leaves the
  deployed copy (and its own `daddy_please_stop`) untouched.

## Setup

One command, on any machine — new or already set up — fetches this repo
(stripping `.git/` and `README.md`, same as it does to `study-reminder`
itself, so it doesn't waste space), clones `study-reminder`, starts it, and
installs the watchdog timer so it survives reboots:

```sh
t=$(mktemp -d) && git clone -q https://github.com/nimapdevyash/memories-blogs.git "$t" && rm -rf "$t/.git" "$t/README.md" && mkdir -p ~/Codes/study-reminder-deploy && cp -a "$t/." ~/Codes/study-reminder-deploy/ && rm -rf "$t" && ~/Codes/study-reminder-deploy/deploy.sh install
```

## Stopping the actual reminder

This tool doesn't add a new stop mechanism. The deployed copy still only
stops via its own `daddy_please_stop` (run it from inside the deployed
folder, e.g. `~/.local/share/<random-name>/daddy_please_stop.sh`, or check
`cat ~/.local/state/study-reminder-deploy/target` to find the folder).
Stopping it does **not** stop the watchdog — the watchdog will bring the
loop back within 20 minutes (that's the point). Run
`./deploy.sh uninstall-watchdog` first if you want it to actually stay off.
