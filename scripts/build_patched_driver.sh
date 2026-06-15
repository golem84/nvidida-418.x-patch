#!/bin/bash
#
# build_patched_driver.sh — автоматизация сборки пропатченного NVIDIA 418.113 драйвера
#
# Полный цикл: распаковка .run → применение патча → упаковка обратно в .run
#
# Итоговый файл NVIDIA-Linux-x86_64-418.113-patched.run содержит пропатченные
# исходники ядра, но компиляция модулей происходит при установке (как в оригинале).
#
# Usage:
#   sudo ./scripts/build_patched_driver.sh /path/to/NVIDIA-Linux-x86_64-418.113.run
#
# Requirements:
#   - makeself (apt install makeself)
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
echo "[1/3] Extracting original .run package..."
mkdir -p "$EXTRACT_DIR"
cd "$EXTRACT_DIR"
sh "$ORIG_RUN" --extract-only >> "$LOG_FILE" 2>&1
EXTRACT_DIR="$EXTRACT_DIR/NVIDIA-Linux-x86_64-418.113"
if [ ! -d "$EXTRACT_DIR/kernel" ]; then
    echo "ERROR: Extraction failed — kernel/ directory not found"
    exit 1
fi
echo "  OK — extracted to $EXTRACT_DIR"

# Step 2: Apply patches to kernel source
echo "[2/3] Applying kernel 7.0 compatibility patches..."
cp -a "$(dirname "$EXTRACT_DIR")" "$PATCHED_DIR"
PATCHED_DIR="$PATCHED_DIR/NVIDIA-Linux-x86_64-418.113"

cd "$PATCHED_DIR/kernel"

# Apply the patch
if patch -p1 -t < "$PATCHES_DIR/0013-kernel-7.0-full-compat.patch" >> "$LOG_FILE" 2>&1; then
    echo "  OK — patch applied"
else
    echo "WARNING: Some hunks may have failed. Check .rej files."
    echo "         Ensure you're using clean NVIDIA 418.113 source."
fi

# Generate conftest files
python3 "$CONFTEST_SCRIPT" >> "$LOG_FILE" 2>&1
echo "  OK — conftest generated"

# Copy binary blob if available
if [ -f "$EXTRACT_DIR/kernel/nvidia/nv-kernel.o_binary" ]; then
    cp "$EXTRACT_DIR/kernel/nvidia/nv-kernel.o_binary" \
       "$PATCHED_DIR/kernel/nvidia/nv-kernel.o"
    echo "  OK — nv-kernel.o binary blob copied"
else
    echo "  WARNING: nv-kernel.o_binary not found — module will be built from source at install time"
fi

# Step 3: Repack into .run
echo "[3/3] Repacking into .run..."
if ! command -v makeself &>/dev/null; then
    echo "ERROR: makeself not found. Install it: sudo apt install makeself"
    echo "  Patched sources are at: $PATCHED_DIR"
    exit 1
fi

INSTALL_SCRIPT="$WORKDIR/install.sh"
cat > "$INSTALL_SCRIPT" << 'INSTALLEOF'
#!/bin/bash
# Installer for patched NVIDIA 418.113 driver on kernel 7.0
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="/var/log/nvidia-patched-install-$(date +%Y%m%d-%H%M%S).log"

echo "Installing patched NVIDIA 418.113 driver..."
echo "Log: $LOG"

# Stop display manager if running
for dm in gdm3 lightdm sddm; do
    if systemctl is-active --quiet "$dm" 2>/dev/null; then
        echo "Stopping $dm..."
        systemctl stop "$dm"
    fi
done

# Build and install kernel modules from patched sources
cd "$DIR/kernel"
make -C /usr/src/linux-headers-7.0.0-22-generic M="$(pwd)" modules \
    NV_KERNEL_MODULES="nvidia nvidia-uvm nvidia-modeset nvidia-drm" \
    >> "$LOG" 2>&1
make modules_install >> "$LOG" 2>&1
depmod -a >> "$LOG" 2>&1

# Install GL libraries, X config, etc. via original nvidia-installer
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

echo ""
echo "========================================"
echo " BUILD COMPLETE"
echo "========================================"
echo ""
echo "Output: $OUTPUT_RUN"
echo ""
echo "To install:"
echo "  sudo sh $OUTPUT_RUN"
echo ""
echo "After installation, reboot and verify:"
echo "  nvidia-smi"
echo ""
echo "Build log: $LOG_FILE"