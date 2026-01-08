#!/bin/bash
# Installation script for Thunderbolt Dock Display Solution
# This script installs all components needed for reliable dock display handling

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "Thunderbolt Dock Display Solution Installer"
echo "=========================================="
echo ""

# Check if running as root for system-level installations
NEED_SUDO=false
if [ "$EUID" -ne 0 ]; then
    log_warn "Not running as root. Will use sudo for system-level installations."
    NEED_SUDO=true
fi

# 1. Install user scripts to ~/.local/bin
log_info "Installing user scripts to ~/.local/bin..."
mkdir -p ~/.local/bin

cp "$SCRIPT_DIR/scripts/thunderbolt-dock-init.sh" ~/.local/bin/
cp "$SCRIPT_DIR/scripts/dock-resume-handler.sh" ~/.local/bin/
cp "$SCRIPT_DIR/scripts/auto-monitor.sh" ~/.local/bin/
cp "$SCRIPT_DIR/scripts/handle-redock.sh" ~/.local/bin/ 2>/dev/null || true
cp "$SCRIPT_DIR/scripts/handle-undock.sh" ~/.local/bin/ 2>/dev/null || true
cp "$SCRIPT_DIR/scripts/predock.sh" ~/.local/bin/ 2>/dev/null || true
cp "$SCRIPT_DIR/scripts/dock-health-check.sh" ~/.local/bin/ 2>/dev/null || true

chmod +x ~/.local/bin/thunderbolt-dock-init.sh
chmod +x ~/.local/bin/dock-resume-handler.sh
chmod +x ~/.local/bin/auto-monitor.sh
chmod +x ~/.local/bin/handle-redock.sh 2>/dev/null || true
chmod +x ~/.local/bin/handle-undock.sh 2>/dev/null || true
chmod +x ~/.local/bin/predock.sh 2>/dev/null || true
chmod +x ~/.local/bin/dock-health-check.sh 2>/dev/null || true

log_info "User scripts installed."

# 2. Install Hyprland configs
log_info "Installing Hyprland configurations..."
mkdir -p ~/.config/hypr

# Backup existing configs
if [ -f ~/.config/hypr/monitors.conf ]; then
    cp ~/.config/hypr/monitors.conf ~/.config/hypr/monitors.conf.backup.$(date +%Y%m%d%H%M%S)
    log_info "Backed up existing monitors.conf"
fi

if [ -f ~/.config/hypr/hybrid_graphics.conf ]; then
    cp ~/.config/hypr/hybrid_graphics.conf ~/.config/hypr/hybrid_graphics.conf.backup.$(date +%Y%m%d%H%M%S)
    log_info "Backed up existing hybrid_graphics.conf"
fi

cp "$SCRIPT_DIR/config/monitors.conf" ~/.config/hypr/
cp "$SCRIPT_DIR/config/hybrid_graphics.conf" ~/.config/hypr/

log_info "Hyprland configs installed."

# 3. Check if hybrid_graphics.conf is sourced in hyprland.conf
if ! grep -q "hybrid_graphics.conf" ~/.config/hypr/hyprland.conf 2>/dev/null; then
    log_warn "hybrid_graphics.conf is not sourced in hyprland.conf"
    echo ""
    echo "Add this line to ~/.config/hypr/hyprland.conf:"
    echo "  source = ~/.config/hypr/hybrid_graphics.conf"
    echo ""
fi

# 4. Install system-level sleep hook (requires sudo)
log_info "Installing system sleep hook..."
SLEEP_HOOK_DIR="/usr/lib/systemd/system-sleep"

if [ "$NEED_SUDO" = true ]; then
    sudo mkdir -p "$SLEEP_HOOK_DIR"
    sudo cp "$SCRIPT_DIR/systemd/system-sleep/dock-resume-trigger.sh" "$SLEEP_HOOK_DIR/"
    sudo chmod +x "$SLEEP_HOOK_DIR/dock-resume-trigger.sh"
else
    mkdir -p "$SLEEP_HOOK_DIR"
    cp "$SCRIPT_DIR/systemd/system-sleep/dock-resume-trigger.sh" "$SLEEP_HOOK_DIR/"
    chmod +x "$SLEEP_HOOK_DIR/dock-resume-trigger.sh"
fi

log_info "System sleep hook installed."

# 5. Install udev rules (requires sudo)
log_info "Installing udev rules..."
UDEV_DIR="/etc/udev/rules.d"

if [ "$NEED_SUDO" = true ]; then
    sudo cp "$SCRIPT_DIR/udev/91-dock-connect.rules" "$UDEV_DIR/" 2>/dev/null || true
    sudo cp "$SCRIPT_DIR/udev/95-hdmi-hotplug.rules" "$UDEV_DIR/" 2>/dev/null || true
    sudo udevadm control --reload-rules
    sudo udevadm trigger
else
    cp "$SCRIPT_DIR/udev/91-dock-connect.rules" "$UDEV_DIR/" 2>/dev/null || true
    cp "$SCRIPT_DIR/udev/95-hdmi-hotplug.rules" "$UDEV_DIR/" 2>/dev/null || true
    udevadm control --reload-rules
    udevadm trigger
fi

log_info "Udev rules installed and reloaded."

# 6. Install user systemd service
log_info "Installing user systemd service..."
mkdir -p ~/.config/systemd/user

cp "$SCRIPT_DIR/systemd/user/dock-resume.service" ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable dock-resume.service 2>/dev/null || true

log_info "User systemd service installed."

# 7. Add dock health check to Hyprland autostart
AUTOSTART_FILE=~/.config/hypr/autostart.conf
HEALTH_CHECK_LINE="exec-once = ~/.local/bin/dock-health-check.sh"

if [ -f "$AUTOSTART_FILE" ]; then
    if ! grep -q "dock-health-check" "$AUTOSTART_FILE"; then
        echo "" >> "$AUTOSTART_FILE"
        echo "# Dock health check on login" >> "$AUTOSTART_FILE"
        echo "$HEALTH_CHECK_LINE" >> "$AUTOSTART_FILE"
        log_info "Added dock health check to autostart.conf"
    else
        log_info "Dock health check already in autostart.conf"
    fi
else
    log_warn "autostart.conf not found, creating it..."
    echo "# Dock health check on login" > "$AUTOSTART_FILE"
    echo "$HEALTH_CHECK_LINE" >> "$AUTOSTART_FILE"
fi

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "What was installed:"
echo "  ✓ User scripts in ~/.local/bin/"
echo "  ✓ Hyprland configs in ~/.config/hypr/"
echo "  ✓ System sleep hook in /usr/lib/systemd/system-sleep/"
echo "  ✓ Udev rules in /etc/udev/rules.d/"
echo "  ✓ User systemd service"
echo ""
echo "The solution will:"
echo "  • Automatically detect dock displays on boot"
echo "  • Recover displays after sleep/wake"
echo "  • Handle dock hot-plug events"
echo "  • Notify you if displays fail to connect"
echo ""
echo "To apply changes now, run:"
echo "  hyprctl reload"
echo ""
echo "To test the dock init script manually:"
echo "  ~/.local/bin/thunderbolt-dock-init.sh"
echo ""
