#!/bin/bash
# Automatic HDMI monitor detection and configuration for Hyprland
# Optimized for NVIDIA hybrid graphics (Intel + NVIDIA)
# HDMI ports on NVIDIA GPU, laptop screen on Intel GPU
#
# NOTE: This script handles HDMI hotplug events. For docking station
# connections, use the existing dock scripts (handle-redock.sh, predock.sh)

LOG_FILE="/tmp/auto-monitor.log"
LAPTOP_SCREEN="eDP-1"

# Safe resolution presets (learned from testing)
# 4K TVs often have issues with 4K@60Hz over HDMI, 1440p@60Hz is stable
HDMI_RESOLUTION="2560x1440"
HDMI_REFRESH="60"
HDMI_SCALE="1"

# Fallback for unknown monitors
DEFAULT_RESOLUTION="1920x1080"
DEFAULT_REFRESH="60"
DEFAULT_SCALE="1"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Ensure Hyprland instance signature is set
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1t /tmp/hypr 2>/dev/null | head -n 1)
fi

if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    log "ERROR: Could not find Hyprland instance"
    exit 1
fi

log "Starting monitor detection for hybrid graphics setup..."

# Check DRM status directly (works better with hybrid graphics)
CONNECTED_MONITORS=""
for port in /sys/class/drm/card*/status; do
    PORT_NAME=$(basename $(dirname $port))
    STATUS=$(cat $port 2>/dev/null)
    if [ "$STATUS" = "connected" ]; then
        # Extract the connector name (e.g., HDMI-A-1 from card0-HDMI-A-1)
        CONNECTOR=$(echo $PORT_NAME | sed 's/card[0-9]-//')
        CONNECTED_MONITORS="$CONNECTED_MONITORS $CONNECTOR"
        log "Found connected port: $CONNECTOR (from $PORT_NAME)"
    fi
done

log "Connected monitors via DRM: $CONNECTED_MONITORS"

# Count external monitors (excluding laptop screen)
EXTERNAL_COUNT=0
EXTERNAL_MONITORS=""

for monitor in $CONNECTED_MONITORS; do
    if [ "$monitor" != "$LAPTOP_SCREEN" ]; then
        EXTERNAL_COUNT=$((EXTERNAL_COUNT + 1))
        EXTERNAL_MONITORS="$EXTERNAL_MONITORS $monitor"
    fi
done

log "External monitors found: $EXTERNAL_COUNT ($EXTERNAL_MONITORS)"

# Always ensure laptop screen is enabled first
log "Configuring laptop screen: $LAPTOP_SCREEN"
hyprctl keyword monitor "$LAPTOP_SCREEN,3200x2000@120,0x0,2" 2>&1 | tee -a "$LOG_FILE"

if [ $EXTERNAL_COUNT -eq 0 ]; then
    log "No external monitors detected - laptop only mode"
    # Disable any previously configured external monitors
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.name != "eDP-1") | .name' | while read -r monitor; do
        if [ -n "$monitor" ]; then
            log "Disabling monitor: $monitor"
            hyprctl keyword monitor "$monitor,disable" 2>&1 | tee -a "$LOG_FILE"
        fi
    done
else
    log "Configuring external monitors..."
    
    # Position counter for multiple monitors
    X_OFFSET=1600  # Start after laptop screen (3200/2 = 1600 at scale 2)
    
    for monitor in $EXTERNAL_MONITORS; do
        log "Configuring external monitor: $monitor"
        
        # Determine resolution based on monitor type
        RESOLUTION=""
        REFRESH=""
        SCALE=""
        
        if [[ "$monitor" == HDMI* ]]; then
            # HDMI monitors (often TVs) - use safe 1440p preset
            RESOLUTION="$HDMI_RESOLUTION"
            REFRESH="$HDMI_REFRESH"
            SCALE="$HDMI_SCALE"
            log "Using HDMI preset: ${RESOLUTION}@${REFRESH} scale ${SCALE}"
            
        elif [[ "$monitor" == DP-7 ]] || [[ "$monitor" == DP-8 ]]; then
            # Known dock monitors (BenQ 4K) - use existing config
            log "Dock monitor detected ($monitor) - skipping (handled by dock scripts)"
            continue
            
        else
            # Unknown monitor - try to detect resolution intelligently
            log "Unknown monitor type: $monitor - detecting resolution..."
            
            # Get available modes from DRM
            AVAILABLE_MODES=""
            for drm_port in /sys/class/drm/card*-${monitor}/modes; do
                if [ -f "$drm_port" ]; then
                    AVAILABLE_MODES=$(cat "$drm_port" 2>/dev/null)
                    break
                fi
            done
            
            if [ -n "$AVAILABLE_MODES" ]; then
                log "Available modes: $(echo $AVAILABLE_MODES | head -c 100)..."
                
                # Check for 1440p first (preferred)
                if echo "$AVAILABLE_MODES" | grep -q "2560x1440"; then
                    RESOLUTION="2560x1440"
                    REFRESH="60"
                    SCALE="1"
                    log "Selected 1440p mode"
                # Then check for 1080p (safe fallback)
                elif echo "$AVAILABLE_MODES" | grep -q "1920x1080"; then
                    RESOLUTION="1920x1080"
                    REFRESH="60"
                    SCALE="1"
                    log "Selected 1080p mode"
                # Last resort - use first available mode
                else
                    RESOLUTION=$(echo "$AVAILABLE_MODES" | head -n1)
                    REFRESH="60"
                    SCALE="1"
                    log "Using first available mode: $RESOLUTION"
                fi
            else
                # No modes detected - use safe default
                RESOLUTION="$DEFAULT_RESOLUTION"
                REFRESH="$DEFAULT_REFRESH"
                SCALE="$DEFAULT_SCALE"
                log "No modes detected, using default: ${RESOLUTION}@${REFRESH}"
            fi
        fi
        
        # Skip if no resolution determined (e.g., dock monitors)
        if [ -z "$RESOLUTION" ]; then
            continue
        fi
        
        log "Setting monitor $monitor at position ${X_OFFSET}x0 with scale $SCALE"
        hyprctl keyword monitor "$monitor,${RESOLUTION}@${REFRESH},${X_OFFSET}x0,$SCALE" 2>&1 | tee -a "$LOG_FILE"
        
        # Calculate next position
        WIDTH=$(echo $RESOLUTION | cut -d'x' -f1)
        if [ -n "$WIDTH" ] && [ "$WIDTH" -gt 0 ] 2>/dev/null; then
            if [ "$SCALE" != "1" ] && [ -n "$SCALE" ]; then
                # Use integer math for scaling (approximate)
                case "$SCALE" in
                    "1.5") SCALED_WIDTH=$((WIDTH * 2 / 3)) ;;
                    "1.25") SCALED_WIDTH=$((WIDTH * 4 / 5)) ;;
                    "2") SCALED_WIDTH=$((WIDTH / 2)) ;;
                    *) SCALED_WIDTH=$WIDTH ;;
                esac
            else
                SCALED_WIDTH=$WIDTH
            fi
            X_OFFSET=$((X_OFFSET + SCALED_WIDTH))
        fi
    done
fi

# Send notification
if [ $EXTERNAL_COUNT -eq 0 ]; then
    notify-send "Monitor Configuration" "Laptop screen only" -t 2000 2>/dev/null
else
    notify-send "Monitor Configuration" "$EXTERNAL_COUNT external monitor(s) configured" -t 2000 2>/dev/null
fi

log "Monitor configuration complete"