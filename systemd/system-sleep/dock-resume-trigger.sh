#!/bin/bash
# /usr/lib/systemd/system-sleep/dock-resume-trigger.sh
# This script is called by systemd before sleep and after wake
# It triggers the user-level dock resume handler

LOG_FILE="/tmp/system-sleep-dock.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

case "$1" in
    pre)
        log "System going to sleep ($2)"
        ;;
    post)
        log "System waking from sleep ($2)"
        
        # Wait a moment for hardware to initialize
        sleep 3
        
        # Find the user running Hyprland
        HYPR_USER=$(ps aux | grep -E 'Hyprland|hyprland' | grep -v grep | head -1 | awk '{print $1}')
        
        if [ -n "$HYPR_USER" ]; then
            log "Found Hyprland user: $HYPR_USER"
            
            # Get user's UID
            USER_UID=$(id -u "$HYPR_USER" 2>/dev/null)
            
            if [ -n "$USER_UID" ]; then
                log "Triggering dock-resume for user $HYPR_USER (UID: $USER_UID)"
                
                # Run the resume handler as the user
                su - "$HYPR_USER" -c "XDG_RUNTIME_DIR=/run/user/$USER_UID /home/$HYPR_USER/.local/bin/dock-resume-handler.sh" &
            fi
        else
            log "No Hyprland user found"
        fi
        ;;
esac

exit 0
