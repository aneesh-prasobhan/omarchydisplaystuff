#!/bin/bash
# Simple dock health check - notification only
# Detects if Thunderbolt dock is connected but displays aren't showing
# Does NOT modify any settings - just notifies user

# Wait for system to settle after login
sleep 5

# Check if Thunderbolt dock is connected and authorized
dock_connected() {
    boltctl list 2>/dev/null | grep -q "status:.*authorized"
}

# Check if dock displays are detected (DP-7 or DP-8 on NVIDIA GPU)
displays_detected() {
    [ "$(cat /sys/class/drm/card0-DP-7/status 2>/dev/null)" = "connected" ] || \
    [ "$(cat /sys/class/drm/card0-DP-8/status 2>/dev/null)" = "connected" ]
}

# Main check
if dock_connected; then
    if ! displays_detected; then
        notify-send -u critical "⚠️ Dock Display Issue" \
            "Thunderbolt dock is connected but monitors not detected.\n\nTry: Unplug dock cable, wait 10 seconds, replug." \
            -t 10000
        echo "[$(date)] Dock connected but displays not detected" >> /tmp/dock-health.log
    fi
fi
