# Automatic HDMI Monitor Detection for Hyprland

## Overview
This setup provides automatic detection and configuration of HDMI monitors for Hyprland on hybrid graphics systems (Intel + NVIDIA).

## Components

### 1. Auto-Monitor Script
**Location:** `~/.local/bin/auto-monitor.sh`

**Features:**
- Detects connected monitors via DRM (Direct Rendering Manager)
- Works with NVIDIA hybrid graphics (PRIME)
- Automatically configures resolution, position, and scaling
- Logs all actions to `/tmp/auto-monitor.log`
- Sends desktop notifications on monitor changes

**How it works:**
- Scans `/sys/class/drm/` for connected displays
- Reads preferred resolution from DRM modes
- Configures monitors using `hyprctl`
- Handles laptop screen (eDP-1) + external monitors

### 2. Udev Rule
**Location:** `/etc/udev/rules.d/95-hdmi-hotplug.rules`

**Purpose:** Automatically triggers the script when monitors are connected/disconnected

**Rule:**
```
ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="/usr/bin/su aneesh -c '/home/aneesh/.local/bin/auto-monitor.sh'"
```

## Usage

### Manual Trigger
Run the script manually to detect and configure monitors:
```bash
~/.local/bin/auto-monitor.sh
```

### Automatic Detection
Simply plug in or unplug your HDMI cable - the system will automatically:
1. Detect the connection change via udev
2. Run the auto-monitor script
3. Configure the display
4. Show a notification

### Check Logs
View detection and configuration logs:
```bash
cat /tmp/auto-monitor.log
```

### Check Current Monitors
```bash
hyprctl monitors
```

## Troubleshooting

### Monitor not detected
1. Check if the monitor is physically connected:
   ```bash
   cat /sys/class/drm/card0-HDMI-A-1/status
   ```
   Should show "connected"

2. Check the log file:
   ```bash
   tail -20 /tmp/auto-monitor.log
   ```

3. Manually run the script:
   ```bash
   ~/.local/bin/auto-monitor.sh
   ```

### Workspace moved to wrong monitor
Move workspace back to laptop screen:
```bash
hyprctl dispatch moveworkspacetomonitor <workspace_number> eDP-1
```

Move workspace to external monitor:
```bash
hyprctl dispatch moveworkspacetomonitor <workspace_number> HDMI-A-1
```

### Reload udev rules
After modifying the udev rule:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Hybrid Graphics Notes

Your system uses:
- **Intel GPU (card1):** Runs Hyprland and laptop display (eDP-1)
- **NVIDIA GPU (card0):** Handles HDMI/DisplayPort outputs and rendering offload

The `WLR_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1` environment variable allows Hyprland to access both GPUs.

## Related Scripts

- `~/.local/bin/predock.sh` - Prepare for undocking (disable external monitors)
- `~/.local/bin/handle-undock.sh` - Handle undocking event
- `~/.local/bin/handle-redock.sh` - Handle docking event

## Configuration Files

- `~/.config/hypr/monitors.conf` - Static monitor configuration
- `/etc/udev/rules.d/91-dock-connect.rules` - Thunderbolt dock detection
- `/etc/udev/rules.d/95-hdmi-hotplug.rules` - HDMI hotplug detection