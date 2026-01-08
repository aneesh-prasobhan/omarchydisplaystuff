# Omarchy Display Setup for ThinkPad P16 Gen3

Complete monitor configuration for Omarchy Linux (Hyprland) with Thunderbolt dock and hybrid graphics.

**Now includes automatic recovery after sleep/wake and system updates!**

## Hardware Setup

- **Laptop**: Lenovo ThinkPad P16 Gen3 / T16g Gen3
- **Internal Display**: Samsung 3200x2000@120Hz OLED (eDP-1)
- **GPUs**: 
  - Intel Arrow Lake-S (card1/i915) - handles laptop display
  - NVIDIA RTX PRO 1000 (card0/nvidia-open) - handles dock displays
- **Dock**: Lenovo ThinkPad Thunderbolt 4 Dock
- **External Monitors**: 2x BenQ PD2705U 4K (3840x2160@60Hz)

## Display Routing

```
                    ┌─────────────────────────────────────┐
                    │         ThinkPad P16 Gen3           │
                    │                                     │
                    │  ┌─────────┐      ┌─────────────┐   │
                    │  │ Intel   │      │   NVIDIA    │   │
                    │  │ iGPU    │      │    GPU      │   │
                    │  │ (card1) │      │  (card0)    │   │
                    │  └────┬────┘      └──────┬──────┘   │
                    │       │                  │          │
                    │    eDP-1              DP-5,6,7,8    │
                    │       │              HDMI-A-1       │
                    └───────┼──────────────────┼──────────┘
                            │                  │
                     ┌──────┴──────┐    ┌──────┴──────┐
                     │   Laptop    │    │ Thunderbolt │
                     │   Screen    │    │    Dock     │
                     │ 3200x2000   │    │             │
                     └─────────────┘    │  DP-7  DP-8 │
                                        └───┬─────┬───┘
                                            │     │
                                      ┌─────┴─┐ ┌─┴─────┐
                                      │ BenQ  │ │ BenQ  │
                                      │ 4K    │ │ 4K    │
                                      └───────┘ └───────┘
```

**Important**: Dock displays (DP-7, DP-8) are dynamically created MST ports on the NVIDIA GPU when the Thunderbolt dock is connected.

## Quick Installation (Recommended)

Run the automated installer:

```bash
cd /home/aneesh/Code/scripts/omarchydisplaystuff
chmod +x install-dock-solution.sh
./install-dock-solution.sh
```

This installs everything including:
- User scripts to `~/.local/bin/`
- Hyprland configs to `~/.config/hypr/`
- System sleep hook for automatic recovery after wake
- Udev rules for hot-plug detection
- User systemd service

## Manual Installation

### 1. Copy Scripts

```bash
# Create directories
mkdir -p ~/.local/bin

# Copy scripts and make executable
cp scripts/*.sh ~/.local/bin/
chmod +x ~/.local/bin/*.sh
```

### 2. Copy Hyprland Configs

```bash
# Monitors configuration
cp config/monitors.conf ~/.config/hypr/

# Hybrid graphics environment
cp config/hybrid_graphics.conf ~/.config/hypr/

# Add to autostart (merge with existing if needed)
cat config/autostart.conf >> ~/.config/hypr/autostart.conf
```

### 3. Source configs in hyprland.conf

Add these lines to `~/.config/hypr/hyprland.conf`:

```conf
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/hybrid_graphics.conf
```

### 4. Install Udev Rules (requires sudo)

```bash
sudo cp udev/95-hdmi-hotplug.rules /etc/udev/rules.d/
sudo cp udev/91-dock-connect.rules /etc/udev/rules.d/

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### 5. Install Required Packages

```bash
# On Arch/Omarchy
sudo pacman -S nvidia-open nvidia-utils bolt jq libnotify

# Ensure nvidia-drm is loaded with modeset
# Add to kernel cmdline: nvidia_drm.modeset=1
```

## File Descriptions

### Scripts (`~/.local/bin/`)

| File | Purpose |
|------|---------|
| `auto-monitor.sh` | Main monitor detection and configuration script |
| `dock-health-check.sh` | Runs at login, notifies if dock displays aren't detected |
| `handle-redock.sh` | Triggered when dock is connected (reloads Hyprland) |
| `handle-undock.sh` | Triggered when dock is disconnected |
| `predock.sh` | Prepares for undocking |

### Configs (`~/.config/hypr/`)

| File | Purpose |
|------|---------|
| `monitors.conf` | Monitor positions, resolutions, and workspace assignments |
| `hybrid_graphics.conf` | WLR_DRM_DEVICES setting for hybrid GPU setup |
| `autostart.conf` | Autostart entries including dock-health-check |

### Udev Rules (`/etc/udev/rules.d/`)

| File | Purpose |
|------|---------|
| `95-hdmi-hotplug.rules` | Triggers auto-monitor.sh on HDMI hotplug |
| `91-dock-connect.rules` | Triggers handle-redock.sh on dock connection |

## Monitor Layout

```
    eDP-1          DP-8           DP-7
  ┌────────┐   ┌──────────┐   ┌──────────┐
  │ Laptop │   │  BenQ    │   │  BenQ    │
  │ 3200x  │   │  4K      │   │  4K      │
  │ 2000   │   │  Center  │   │  Right   │
  │ @120Hz │   │  @60Hz   │   │  @60Hz   │
  │ scale 2│   │ scale1.5 │   │ scale1.5 │
  └────────┘   └──────────┘   └──────────┘
    0,0         1600,0         4160,0
```

### Resolution Settings

| Monitor | Resolution | Refresh | Scale | Position |
|---------|------------|---------|-------|----------|
| eDP-1 | 3200x2000 | 120Hz | 2.0 | 0,0 |
| DP-8 | 3840x2160 | 60Hz | 1.5 | 1600,0 |
| DP-7 | 3840x2160 | 60Hz | 1.5 | 4160,0 |
| HDMI-A-1 | 2560x1440 | 60Hz | 1.0 | (fallback for TV) |

### Workspace Assignments

| Workspace | Monitor |
|-----------|---------|
| 1 | eDP-1 (laptop) |
| 2 | DP-8 (center) |
| 3 | DP-7 (right) |
| 4 | HDMI-A-1 |

## Troubleshooting

### Dock connected but no displays

**Symptom**: Thunderbolt dock shows as authorized, USB/ethernet work, but monitors show "No Signal"

**Cause**: Thunderbolt DisplayPort tunneling state got stuck

**Solution**:
1. Shutdown laptop (not reboot)
2. Unplug Thunderbolt cable
3. If dock has power adapter, unplug that too
4. Wait 30 seconds
5. Reconnect dock power
6. Plug Thunderbolt cable into laptop (while OFF)
7. Boot laptop

### Check current status

```bash
# DRM port status
for p in /sys/class/drm/card*-*/status; do echo "$(dirname $p | xargs basename): $(cat $p)"; done

# Hyprland monitors
hyprctl monitors

# Thunderbolt dock status
boltctl list

# View logs
cat /tmp/auto-monitor.log
```

### Manual monitor configuration

```bash
# Force configure monitors
hyprctl keyword monitor "eDP-1,3200x2000@120,0x0,2"
hyprctl keyword monitor "DP-8,3840x2160@60,1600x0,1.5"
hyprctl keyword monitor "DP-7,3840x2160@60,4160x0,1.5"

# Reload Hyprland
hyprctl reload
```

### Port names changed?

If DP-7/DP-8 don't work, check which ports the monitors appear on:

```bash
# Find connected ports
for p in /sys/class/drm/card*-*/status; do 
  [ "$(cat $p)" = "connected" ] && dirname $p | xargs basename
done
```

Then update `monitors.conf` with the correct port names.

## Key Environment Variables

In `hybrid_graphics.conf`:

```conf
env = WLR_DRM_DEVICES,/dev/dri/card1:/dev/dri/card0
```

This tells Hyprland to use both GPUs, with Intel (card1) as primary.

## Dependencies

- `hyprland` - Wayland compositor
- `nvidia-open` - NVIDIA open kernel modules (required for RTX PRO 1000)
- `bolt` - Thunderbolt device manager
- `jq` - JSON processor (for parsing hyprctl output)
- `libnotify` - Desktop notifications

## Notes

- The dock displays appear on the **NVIDIA GPU** (card0), not Intel
- DP-7 and DP-8 are **dynamically created** MST ports when dock is connected
- First-time Thunderbolt authorization: `boltctl enroll <device-uuid>`
- Kernel parameter `nvidia_drm.modeset=1` may be required

---

*Last updated: 2026-01-05*
*Tested on: Omarchy Linux, Kernel 6.17.9, Hyprland*
