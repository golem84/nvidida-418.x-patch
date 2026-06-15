#!/bin/bash
#
# build_patched_driver.sh — автоматизация сборки пропатченного NVIDIA 418.113 драйвера
#
# Полный цикл: распаковка .run → применение патча → сборка → упаковка в .run
#
# Usage:
#   sudo ./scripts/build_patched_driver.sh <path-to-NVIDIA-Linux-x86_64-418.113.run>
#
# Requirements:
#   - makeself (apt install makeself)
#   - kernel headers: /usr/src/linux-headers-7.0.0-22-generic
#   - build-essential, gcc, make
#   - Python 3
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCHES_DIR="$PROJECT_DIR/patches"
CONFTEST_SCRIPT="$SCRIPT_DIR/generate_conftest.py"
APPLY_SCRIPT="$SCRIPT_DIR/apply_patches.sh"

ORIG_RUN="$1"
if [ -z "$ORIG_RUN" ] || [ ! -f "$ORIG_RUN" ]; then
    echo "Usage: $0 <path-to-NVIDIA-Linux-x86_64-418.113.run>"
    exit 1
fi

ORIG_RUN="$(realpath "$ORIG_RUN")"
WORKDIR="$(mktemp -d /tmp/nvidia-patched-XXXXXX)"
EXTRACT_DIR="$WORKDIR/extracted"
PATCHED_DIR="$WORKDIR/patched"
OUTPUT_RUN="$WORKDIR/NVIDIA-Linux-x86_64-418.113-patched.run"
LOG_FILE="$WORKDIR/build.log"

cleanup() {
    echo "Cleaning up..."
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "========================================"
echo " NVIDIA 418.113 Patched Driver Builder"
echo "========================================"
echo "Log: $LOG_FILE"
echo ""

# Step 1: Extract original .run
echo "[1/5] Extracting original .run package..."
mkdir -p "$EXTRACT_DIR"
sh "$ORIG_RUN" --extract-only --target="$EXTRACT_DIR" >> "$LOG_FILE" 2>&1
if [ ! -d "$EXTRACT_DIR/kernel" ]; then
    echo "ERROR: Extraction failed — kernel/ directory not found"
    exit 1
fi
echo "  OK — extracted to $EXTRACT_DIR"

# Step 2: Apply patches
echo "[2/5] Applying kernel 7.0 compatibility patches..."
cp -a "$EXTRACT_DIR" "$PATCHED_DIR"
bash "$APPLY_SCRIPT" "$PATCHED_DIR" >> "$LOG_FILE" 2>&1
echo "  OK — patches applied"

# Step 3: Copy binary blob
echo "[3/5] Copying nv-kernel.o binary blob..."
if [ -f "$EXTRACT_DIR/kernel/nvidia/nv-kernel.o_binary" ]; then
    cp "$EXTRACT_DIR/kernel/nvidia/nv-kernel.o_binary" \
       "$PATCHED_DIR/kernel/nvidia/nv-kernel.o"
    echo "  OK — nv-kernel.o copied"
else
    echo "WARNING: nv-kernel.o_binary not found in original package"
    echo "  You must manually copy it before building:"
    echo "  cp <original>/kernel/nvidia/nv-kernel.o_binary \\"
    echo "     $PATCHED_DIR/kernel/nvidia/nv-kernel.o"
fi

# Step 4: Build kernel modules
echo "[4/5] Building kernel modules..."
cd "$PATCHED_DIR/kernel"
make -C /usr/src/linux-headers-7.0.0-22-generic M="$(pwd)" modules \
    NV_KERNEL_MODULES="nvidia nvidia-uvm nvidia-modeset nvidia-drm" \
    >> "$LOG_FILE" 2>&1
echo "  OK — modules built"

# Step 5: Repack into .run
echo "[5/5] Repacking into .run..."
if command -v makeself &>/dev/null; then
    INSTALL_SCRIPT="$WORKDIR/install.sh"
    cat > "$INSTALL_SCRIPT" << 'INSTALLEOF'
#!/bin/bash
# Self-installer for patched NVIDIA 418.113 driver
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="/var/log/nvidia-patched-install-$(date +%Y%m%d-%H%M%S).log"

echo "Installing patched NVIDIA 418.113 driver..."
echo "Log: $LOG"

# Stop display manager if running
if systemctl is-active gdm3 &>/dev/null; then
    echo "Stopping gdm3..."
    systemctl stop gdm3
elif systemctl is-active lightdm &>/dev/null; then
    echo "Stopping lightdm..."
    systemctl stop lightdm
elif systemctl is-active sddm &>/dev/null; then
    echo "Stopping sddm..."
    systemctl stop sddm
fi

# Install kernel modules
cd "$DIR/kernel"
make modules_install >> "$LOG" 2>&1
depmod -a >> "$LOG" 2>&1

# Run NVIDIA installer for the rest (GL libraries, X config, etc.)
cd "$DIR"
if [ -f nvidia-installer ]; then
    ./nvidia-installer --no-kernel-modules --no-precompiled-interface \
        --accept-license --silent >> "$LOG" 2>&1
fi

echo ""
echo "========================================"
echo " Installation complete!"
echo "========================================"
echo "Log: $LOG"
echo ""
echo "Next steps:"
echo "  1. Reboot: sudo reboot"
echo "  2. After reboot, verify: nvidia-smi"
echo "  3. If issues: check $LOG and /var/log/Xorg.0.log"
INSTALLEOF
    chmod +x "$INSTALL_SCRIPT"

    makeself "$PATCHED_DIR" "$OUTPUT_RUN" \
        "NVIDIA 418.113 Patched for Kernel 7.0" \
        ./install.sh \
        >> "$LOG_FILE" 2>&1
    echo "  OK — $OUTPUT_RUN"
else
    echo "WARNING: makeself not found. Install it: sudo apt install makeself"
    echo "  Patched sources are at: $PATCHED_DIR"
    echo "  To install manually, run:"
    echo "    cd $PATCHED_DIR/kernel"
    echo "    sudo make modules_install"
    echo "    sudo depmod -a"
    exit 1
fi

echo ""
echo "========================================"
echo " BUILD COMPLETE"
echo "========================================"
echo ""
echo "Output: $OUTPUT_RUN"
echo ""
echo "To install, run as root:"
echo "  sudo sh $OUTPUT_RUN"
echo ""
echo "After installation, reboot and verify:"
echo "  nvidia-smi"
echo ""
echo "Build log: $LOG_FILE"
