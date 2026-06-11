# NVIDIA 418.113 Driver Patch Plan for Kernel 7.0.0-22-generic

## Host System Information
- **Kernel**: 7.0.0-22-generic (Ubuntu 15.2.0-16ubuntu1, GCC 15.2.0)
- **GPU**: NVIDIA GeForce GT 740M (GK208M) [10de:1292] at PCI 01:00.0
- **Driver**: NVIDIA-Linux-x86_64-418.113.run (located at /opt/nvidia/)

## Root Cause Analysis

The installation fails because the NVIDIA driver's kernel module build system cannot find its own internal header files during compilation. The errors are:

```
fatal error: nv-misc.h: No such file or directory
fatal error: nvtypes.h: No such file or directory
fatal error: uvmtypes.h: No such file or directory
fatal error: nv_uvm_types.h: No such file or directory
fatal error: conftest.h: No such file or directory
fatal error: nv-linux.h: No such file or directory
fatal error: nv-modeset-interface.h: No such file or directory
fatal error: nv-kthread-q.h: No such file or directory
fatal error: nv-memdbg.h: No such file or directory
fatal error: nv-procfs.h: No such file or directory
fatal error: nv-msi.h: No such file or directory
```

These headers exist in the driver source at:
- `kernel/common/inc/` - contains all NVIDIA internal headers (nv-misc.h, nvtypes.h, nv-linux.h, etc.)
- `kernel/nvidia-uvm/` - contains UVM-specific headers (uvmtypes.h, uvm_linux.h, etc.)
- `kernel/nvidia-modeset/` - contains modeset headers
- `kernel/nvidia-drm/` - contains DRM headers

## Why the Build Fails

### 1. Missing Include Paths in Kbuild
The `kernel/Kbuild` file defines:
```makefile
EXTRA_CFLAGS += -I$(src)/common/inc
EXTRA_CFLAGS += -I$(src)
```

However, `$(src)` in Kbuild context points to the kernel source tree (`/lib/modules/7.0.0-22-generic/build`), NOT the NVIDIA driver source directory. The driver source is at `M=$(CURDIR)` (the current directory where make is invoked).

### 2. Conftest Mechanism Issues
The `conftest.sh` script generates headers in `$(obj)/conftest/` but:
- It only generates kernel compatibility headers (macros.h, functions.h, types.h, etc.)
- It does NOT copy or symlink the NVIDIA internal headers from `common/inc/`
- The generated `conftest.h` is placed in `$(obj)/conftest/headers.h` but source files include `"conftest.h"` directly

### 3. Include Path Resolution
When Kbuild compiles, it uses `-I$(src)/common/inc` where `$(src)` = kernel source, so it looks for headers in `/lib/modules/7.0.0-22-generic/build/common/inc/` which doesn't exist.

The correct path should be `-I$(PWD)/common/inc` or `-I$(M)/common/inc` where `M` is the external module source directory.

## Patch Plan

### Phase 1: Fix Include Paths in Kbuild
**File**: `kernel/Kbuild`

Change:
```makefile
EXTRA_CFLAGS += -I$(src)/common/inc
EXTRA_CFLAGS += -I$(src)
```

To:
```makefile
EXTRA_CFLAGS += -I$(PWD)/common/inc
EXTRA_CFLAGS += -I$(PWD)
```

Or using the Kbuild variable for external modules:
```makefile
EXTRA_CFLAGS += -I$(M)/common/inc
EXTRA_CFLAGS += -I$(M)
```

### Phase 2: Fix conftest.h Generation/Location
**File**: `kernel/conftest.sh`

The `test_kernel_headers` function generates `headers.h` but source files include `"conftest.h"`. Options:
1. Modify conftest.sh to also generate `conftest.h` as a symlink/copy of `headers.h`
2. Or modify all source files to include `<conftest/headers.h>` instead of `"conftest.h"`

Option 1 is less invasive. Add to `test_kernel_headers`:
```bash
# After generating headers.h
cp "$OUTPUT/conftest/headers.h" "$OUTPUT/conftest/conftest.h"
```

### Phase 3: Ensure Headers Available During Build
The NVIDIA internal headers in `common/inc/` must be accessible. Options:
1. Copy headers to kernel build directory during build (in Kbuild)
2. Use `-I$(M)/common/inc` in EXTRA_CFLAGS (preferred)

### Phase 4: Kernel 7.x Compatibility Fixes
Kernel 7.0 introduced changes that may require:
- Updated `conftest.sh` compile tests for new kernel APIs
- Check for removed/changed kernel functions (prio_tree, etc.)
- Verify `get_user_pages` / `get_user_pages_remote` signatures
- Check `vm_fault` structure changes
- Verify `proc_dir_entry` and `file_operations` changes

### Phase 5: DKMS Support for Kernel Recompilation
**File**: `kernel/dkms.conf`

Update to ensure proper rebuild on kernel updates:
```makefile
PACKAGE_NAME="nvidia"
PACKAGE_VERSION="418.113"
BUILT_MODULE_NAME[0]="nvidia"
DEST_MODULE_LOCATION[0]="/kernel/drivers/video"
BUILT_MODULE_NAME[1]="nvidia-uvm"
DEST_MODULE_LOCATION[1]="/kernel/drivers/video"
BUILT_MODULE_NAME[2]="nvidia-modeset"
DEST_MODULE_LOCATION[2]="/kernel/drivers/video"
BUILT_MODULE_NAME[3]="nvidia-drm"
DEST_MODULE_LOCATION[3]="/kernel/drivers/video"
AUTOINSTALL="yes"
MAKE[0]="KERNELRELEASE=${kernelver} modules"
CLEAN="make clean"
```

## Implementation Steps

### Step 1: Create Patched Kbuild
```bash
cd /home/andrew/projects/nvidida-418.x-patch
mkdir -p patches
cp NVIDIA-Linux-x86_64-418.113/kernel/Kbuild patches/Kbuild.original
# Edit patches/Kbuild with fixed include paths
```

### Step 2: Patch conftest.sh
```bash
cp NVIDIA-Linux-x86_64-418.113/kernel/conftest.sh patches/conftest.sh.original
# Edit to generate conftest.h
```

### Step 3: Test Build
```bash
cd NVIDIA-Linux-x86_64-418.113/kernel
# Apply patches
make SYSSRC=/lib/modules/7.0.0-22-generic/build SYSOUT=/lib/modules/7.0.0-22-generic/build modules
```

### Step 4: Create DKMS Package
```bash
# Copy patched source to /usr/src/nvidia-418.113/
# Run dkms add/build/install
```

## Files to Patch

1. **kernel/Kbuild** - Fix include paths (PRIMARY FIX)
2. **kernel/conftest.sh** - Generate conftest.h 
3. **kernel/dkms.conf** - Ensure proper DKMS integration
4. **kernel/common/inc/nv-linux.h** - May need kernel 7.x compatibility defines
5. **kernel/nvidia-uvm/uvm_linux.h** - Verify includes work with new paths

## Testing Checklist

- [ ] Module compiles without header errors
- [ ] Module loads successfully (`insmod nvidia.ko`)
- [ ] GPU is detected (`nvidia-smi`)
- [ ] DKMS rebuild works on kernel upgrade simulation
- [ ] X11/Wayland works with driver

## Notes

The driver version 418.113 is legacy (from 2019) and officially supports kernels up to ~5.4. Running on kernel 7.0 requires backporting compatibility fixes. The main issues are:
1. Include path resolution (fixed by Phase 1)
2. Kernel API changes since 2019 (Phase 4)
3. GCC 15 compatibility (warnings/errors from stricter compiler)

Consider upgrading to a newer legacy driver branch (470.x or 525.x) if possible, as they have better kernel 6.x/7.x support.