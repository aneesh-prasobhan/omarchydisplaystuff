#!/bin/bash
# Disable all external monitors (anything except eDP-1) on undock

# Get Hyprland instance signature properly (check /run/user/1000/hypr/ first, then /tmp/hypr)
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 /run/user/1000/hypr/ 2>/dev/null | head -n 1)
    
    # If not found, try /tmp/hypr as fallback
    if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1t /tmp/hypr 2>/dev/null | head -n 1)
    fi
fi

# Get all monitors except laptop screen and disable them
hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.name != "eDP-1") | .name' | while read -r monitor; do
    if [ -n "$monitor" ]; then
        hyprctl keyword monitor "$monitor,disable"
    fi
done
