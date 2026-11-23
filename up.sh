#!/usr/bin/env bash
# Start the Home Assistant stack and expose it over Tailscale Funnel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_NAME="${UNIT_NAME:-homeassistant.service}"
QUADLET_SRC="quadlet/homeassistant.container"
QUADLET_DST="/etc/containers/systemd/homeassistant.container"
CONTAINER_NAME="${CONTAINER_NAME:-homeassistant}"
HA_PORT="${HA_PORT:-8123}"
WAIT_SECONDS="${WAIT_SECONDS:-60}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v podman >/dev/null 2>&1 || die "podman is not installed"
command -v tailscale >/dev/null 2>&1 || die "tailscale is not installed"
sudo -v

cd "$SCRIPT_DIR"

# Quadlet must be a real file under /etc: the generator runs before /home is mounted at boot, so a symlink into the repo is missed.
log "Syncing Quadlet to '$QUADLET_DST'"
sudo rm -f "$QUADLET_DST"
sudo install -m 0644 "$QUADLET_SRC" "$QUADLET_DST"
sudo systemctl daemon-reload

log "Starting '$UNIT_NAME' (Quadlet)"
sudo systemctl start "$UNIT_NAME"

log "Waiting for container '$CONTAINER_NAME' to be running"
for ((i = 0; i < WAIT_SECONDS; i++)); do
    running="$(sudo podman inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || true)"
    [[ "$running" == "true" ]] && break
    sleep 1
done
[[ "${running:-}" == "true" ]] || die "container '$CONTAINER_NAME' did not start within ${WAIT_SECONDS}s"

log "Enabling Tailscale Funnel on port $HA_PORT"
sudo tailscale funnel --bg "$HA_PORT"

log "Done"
