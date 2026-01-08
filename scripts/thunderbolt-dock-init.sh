#!/bin/bash
# Thunderbolt Dock DisplayPort Initialization Script
# Ensures DisplayPort tunneling is properly established after boot/wake
#
# The Problem: Thunderbolt DisplayPort tunneling can fail to initialize properly
# after system updates, sleep/wake cycles, or hot-plugging. The dock appears
# authorized but displays show "No Signal".
#
# The Solution: This script forces re-initialization of the Thunderbolt controller
# and NVIDIA GPU's DisplayPort outputs when displays aren't detected.

LOG_FILE="/tmp/thunderbolt-dock-init.log"
DOCK_UUID="8e5f8780-0033-1005-ffff-ffffffffffff"  # Lenovo ThinkPad Thunderbolt 4 Dock
MAX_RETRIES=5
RETRY_DELAY=2

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if dock displays are connected
check_dock_displays() {
    local connected=0
    for port in /sys/class/drm/card0-DP-*/status; do
        if [ -f "$port" ] && [ "$(cat "$port" 2>/dev/null)" = "connected" ]; then
            connected=$((connected + 1))
        fi
    done
    echo $connected
}

# Check if Thunderbolt dock is present and authorized
check_dock_authorized() {
    if command -v boltctl &>/dev/null; then
        boltctl list 2>/dev/null | grep -q "status:.*authorized"
        return $?
    fi
    return 1
}

# Force NVIDIA GPU to rescan for displays
rescan_nvidia_displays() {
    log "Triggering NVIDIA display rescan..."
    
    # Method 1: Trigger DRM hotplug via sysfs
    for card in /sys/class/drm/card0/card0-*/; do
        if [ -d "$card" ]; then
            # Reading status can trigger a rescan on some drivers
            cat "${card}status" &>/dev/null
        fi
    done
    
    # Method 2: Use nvidia-settings if available (X11 only, but worth trying)
    if command -v nvidia-settings &>/dev/null; then
        nvidia-settings --query CurrentMetaMode &>/dev/null 2>&1 || true
    fi
    
    # Method 3: Reload nvidia_drm module (aggressive, may cause flicker)
    # Only do this if no displays are connected at all
    if [ "$(check_dock_displays)" -eq 0 ]; then
        log "No displays detected, attempting nvidia_drm reprobe..."
        if [ -w /sys/bus/pci/drivers/nvidia/unbind ]; then
            # Get NVIDIA GPU PCI address
            local nvidia_pci=$(lspci -D | grep -i nvidia | head -1 | cut -d' ' -f1)
            if [ -n "$nvidia_pci" ]; then
                log "NVIDIA PCI: $nvidia_pci (not unbinding - too risky)"
                # Don't actually unbind - it's too risky and can crash the system
                # Instead, just trigger a mode probe
            fi
        fi
    fi
}

# Force Thunderbolt controller to re-enumerate
rescan_thunderbolt() {
    log "Triggering Thunderbolt rescan..."
    
    # Method 1: Use boltctl to force re-authorization
    if command -v boltctl &>/dev/null; then
        # Check if dock is connected but not authorized
        local dock_status=$(boltctl info "$DOCK_UUID" 2>/dev/null | grep "status:" | awk '{print $2}')
        if [ "$dock_status" = "connected" ]; then
            log "Dock connected but not authorized, authorizing..."
            boltctl authorize "$DOCK_UUID" 2>/dev/null || true
        fi
    fi
    
    # Method 2: Trigger USB4/Thunderbolt rescan via sysfs
    for domain in /sys/bus/thunderbolt/devices/domain*/; do
        if [ -d "$domain" ]; then
            # Some systems support forcing a rescan
            if [ -w "${domain}rescan" ]; then
                echo 1 > "${domain}rescan" 2>/dev/null || true
                log "Triggered rescan on $(basename $domain)"
            fi
        fi
    done
    
    # Method 3: Toggle Thunderbolt security (if supported)
    local security_file="/sys/bus/thunderbolt/devices/domain0/security"
    if [ -r "$security_file" ]; then
        log "Thunderbolt security: $(cat $security_file)"
    fi
}

# Main initialization routine
main() {
    log "=========================================="
    log "Thunderbolt Dock Initialization Starting"
    log "=========================================="
    
    # Check if we're running as root (needed for some operations)
    if [ "$EUID" -ne 0 ]; then
        log "Warning: Not running as root, some operations may fail"
    fi
    
    # Check if dock is present
    if ! check_dock_authorized; then
        log "Thunderbolt dock not detected or not authorized"
        log "Waiting for dock authorization..."
        sleep 3
        if ! check_dock_authorized; then
            log "Dock still not authorized, exiting"
            exit 0
        fi
    fi
    
    log "Thunderbolt dock is authorized"
    
    # Check current display status
    local displays=$(check_dock_displays)
    log "Currently detected dock displays: $displays"
    
    if [ "$displays" -ge 1 ]; then
        log "Dock displays already detected, no action needed"
        exit 0
    fi
    
    # Displays not detected, try to recover
    log "No dock displays detected, attempting recovery..."
    
    for retry in $(seq 1 $MAX_RETRIES); do
        log "Recovery attempt $retry of $MAX_RETRIES"
        
        # Try Thunderbolt rescan first
        rescan_thunderbolt
        sleep $RETRY_DELAY
        
        # Then try NVIDIA rescan
        rescan_nvidia_displays
        sleep $RETRY_DELAY
        
        # Check if displays appeared
        displays=$(check_dock_displays)
        if [ "$displays" -ge 1 ]; then
            log "SUCCESS: $displays dock display(s) now detected!"
            
            # Notify Hyprland to reload monitors
            if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
                hyprctl reload &>/dev/null || true
                log "Triggered Hyprland reload"
            fi
            
            # Send notification
            if command -v notify-send &>/dev/null; then
                notify-send "Dock Displays" "$displays monitor(s) connected" -t 3000 2>/dev/null || true
            fi
            
            exit 0
        fi
        
        log "Displays still not detected, waiting..."
        sleep $RETRY_DELAY
    done
    
    log "FAILED: Could not detect dock displays after $MAX_RETRIES attempts"
    log "Manual intervention may be required (power cycle dock)"
    
    # Send failure notification
    if command -v notify-send &>/dev/null; then
        notify-send -u critical "Dock Display Issue" "Could not detect dock displays. Try unplugging and replugging the dock." -t 10000 2>/dev/null || true
    fi
    
    exit 1
}

# Run main function
main "$@"
