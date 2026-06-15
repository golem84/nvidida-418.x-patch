#!/bin/bash
#
# apply_patches.sh - Apply NVIDIA 418.113 kernel 7.0 compatibility patches
#
# Применяет единый патч 0013 к чистой выгрузке драйвера NVIDIA 418.113,
# затем генерирует conftest файлы.
#
# Usage:
#   ./apply_patches.sh <path-to-nvidia-driver-source>
#
# Example:
#   ./apply_patches.sh ../NVIDIA-Linux-x86_64-418.113
#
# Requirements:
#   - patches/0013-kernel-7.0-full-compat.patch
#   - Целевая директория — чистая выгрузка NVIDIA 418.113 драйвера
#   - Python 3 для генерации conftest
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="${SCRIPT_DIR}/../patches"
CONFTEST_SCRIPT="${SCRIPT_DIR}/generate_conftest.py"

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-nvidia-driver-source>"
    exit 1
fi

NVIDIA_DIR="$1"

if [ ! -d "$PATCHES_DIR" ]; then
    echo "ERROR: Patches directory not found: $PATCHES_DIR"
    exit 1
fi

if [ ! -d "$NVIDIA_DIR/kernel" ]; then
    echo "ERROR: NVIDIA kernel directory not found: $NVIDIA_DIR/kernel"
    exit 1
fi

echo "========================================"
echo "NVIDIA 418.113 Kernel 7.0 Patch Applied"
echo "========================================"
echo ""
echo "Target: $NVIDIA_DIR"

# Apply single patch
PATCH_FILE="$PATCHES_DIR/0013-kernel-7.0-full-compat.patch"
if [ ! -f "$PATCH_FILE" ]; then
    echo "ERROR: Patch not found: $PATCH_FILE"
    exit 1
fi

echo ""
echo "Applying 0013-kernel-7.0-full-compat.patch (26 files)..."
cd "$NVIDIA_DIR/kernel"

if patch -p1 -t < "$PATCH_FILE"; then
    echo "  OK — all hunks applied successfully"
else
    echo "WARNING: Some hunks may have failed. Check .rej files."
    echo "         Ensure you're using clean NVIDIA 418.113 source."
fi

echo ""
echo "Generating conftest files..."
cd "$NVIDIA_DIR/kernel"
if [ -f "$CONFTEST_SCRIPT" ]; then
    python3 "$CONFTEST_SCRIPT"
fi

echo ""
echo "========================================"
echo "Done! Next steps:"
echo "========================================"
echo ""
echo "  1. Copy nv-kernel.o binary blob:"
echo "     cp <original>/kernel/nvidia/nv-kernel.o_binary \\"
echo "        $NVIDIA_DIR/kernel/nvidia/nv-kernel.o"
echo ""
echo "  2. Build:"
echo "     cd $NVIDIA_DIR/kernel"
echo "     make -C /usr/src/linux-headers-7.0.0-22-generic M=\$(pwd) modules \\"
echo '       NV_KERNEL_MODULES="nvidia nvidia-uvm nvidia-modeset nvidia-drm"'
echo ""