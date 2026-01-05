#!/bin/bash
# Re-enable monitors when dock is connected

sleep 2  # Give hardware time to settle

# Find Hyprland instance signature (check /run/user/1000/hypr/ first, then /tmp/hypr)
export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 /run/user/1000/hypr/ 2>/dev/null | head -n 1)

# If not found, try /tmp/hypr as fallback
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1t /tmp/hypr 2>/dev/null | head -n 1)
fi

# Reload Hyprland configuration to re-detect monitors
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    sudo -u aneesh HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE" /usr/bin/hyprctl reload
    
    sleep 1
    
    # Send notification
    sudo -u aneesh DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus" /usr/bin/notify-send "Dock connected" "Monitors re-enabled" -t 2000
fi
