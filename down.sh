#!/usr/bin/env bash
# Stop the Home Assistant stack and disable its Tailscale Funnel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HA_PORT="${HA_PORT:-8123}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

UNIT_NAME="${UNIT_NAME:-homeassistant.service}"

command -v podman >/dev/null 2>&1 || die "podman is not installed"
sudo -v

cd "$SCRIPT_DIR"

log "Disabling Tailscale Funnel on port $HA_PORT"
funnel_failed=0
if ! sudo tailscale funnel reset; then
    printf 'warning: failed to disable Tailscale Funnel\n' >&2
    funnel_failed=1
fi

log "Stopping '$UNIT_NAME' (Quadlet)"
sudo systemctl stop "$UNIT_NAME"

(( funnel_failed == 0 )) || die "stack stopped, but Tailscale Funnel could not be disabled"
log "Done"
