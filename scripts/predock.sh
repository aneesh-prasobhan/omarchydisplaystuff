#!/bin/bash
# Disable external monitors and ensure laptop screen is enabled

notify-send "Preparing to undock..." "Disabling external monitors..." -t 2000

# First, ensure laptop screen is enabled (in case lid is closed)
hyprctl keyword monitor "eDP-1, 3200x2000@120, 0x0, 2"

sleep 0.5

# Then disable all external monitors
hyprctl monitors -j | jq -r '.[] | select(.name != "eDP-1") | .name' | while read -r monitor; do
    if [ -n "$monitor" ]; then
        hyprctl keyword monitor "$monitor,disable"
    fi
done

sleep 1

notify-send "Ready to undock!" "Safe to unplug dock now. Open lid if closed." -u critical -t 5000
