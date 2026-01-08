#!/bin/bash
# Dock Resume Handler - Called after system wakes from sleep
# This script runs as the user (not root) and handles Hyprland integration

LOG_FILE="/tmp/dock-resume.log"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Find Hyprland instance
find_hyprland() {
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1t /tmp/hypr 2>/dev/null | head -n 1)
    if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        log "ERROR: Could not find Hyprland instance"
        return 1
    fi
    log "Found Hyprland instance: $HYPRLAND_INSTANCE_SIGNATURE"
    return 0
}

# Wait for displays to be detected
wait_for_displays() {
    local max_wait=30
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        local displays=0
        for port in /sys/class/drm/card0-DP-*/status; do
            if [ -f "$port" ] && [ "$(cat "$port" 2>/dev/null)" = "connected" ]; then
                displays=$((displays + 1))
            fi
        done
        
        if [ $displays -ge 1 ]; then
            log "Detected $displays dock display(s) after ${waited}s"
            return 0
        fi
        
        sleep 1
        waited=$((waited + 1))
    done
    
    log "Timeout waiting for displays after ${max_wait}s"
    return 1
}

# Configure monitors in Hyprland
configure_monitors() {
    if ! find_hyprland; then
        return 1
    fi
    
    log "Configuring monitors in Hyprland..."
    
    # Get list of connected monitors from DRM
    local connected_monitors=""
    for port in /sys/class/drm/card*-*/status; do
        if [ "$(cat "$port" 2>/dev/null)" = "connected" ]; then
            local connector=$(basename $(dirname $port) | sed 's/card[0-9]-//')
            connected_monitors="$connected_monitors $connector"
        fi
    done
    
    log "Connected monitors: $connected_monitors"
    
    # Reload Hyprland config to apply monitor settings
    hyprctl reload 2>&1 | tee -a "$LOG_FILE"
    
    # Give Hyprland time to process
    sleep 2
    
    # Verify monitors are configured
    local configured=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' | wc -l)
    log "Hyprland reports $configured monitor(s) configured"
    
    return 0
}

main() {
    log "=========================================="
    log "Dock Resume Handler Starting"
    log "=========================================="
    
    # Small delay to let hardware settle
    sleep 2
    
    # Wait for displays to appear in DRM
    if wait_for_displays; then
        # Configure Hyprland
        configure_monitors
        
        # Send success notification
        notify-send "Dock Resumed" "External displays connected" -t 3000 2>/dev/null || true
    else
        log "No dock displays detected after resume"
        
        # Try running the init script as a fallback
        if [ -x "$SCRIPT_DIR/thunderbolt-dock-init.sh" ]; then
            log "Running thunderbolt-dock-init.sh as fallback..."
            "$SCRIPT_DIR/thunderbolt-dock-init.sh"
        fi
        
        # Check again
        if wait_for_displays; then
            configure_monitors
            notify-send "Dock Resumed" "External displays connected (after recovery)" -t 3000 2>/dev/null || true
        else
            notify-send -u critical "Dock Issue" "Could not detect external displays after resume" -t 10000 2>/dev/null || true
        fi
    fi
    
    log "Dock Resume Handler Complete"
}

main "$@"
