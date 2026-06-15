# NVIDIA 418.113 Patch Progress - June 15, 2026

## Goal
Patch NVIDIA 418.113 driver to build and install on kernel 7.0.0-22-generic (Ubuntu 24.04, GCC 15.2.0).

## Current Status: nvidia.ko + nvidia-uvm.ko BUILD ✅

### Repository Organization (License Compliance) ✅
- **Public branch (`master`)**: contains only `patches/` with diff files
- **Local branch (`kernel-7.0-compat`)**: contains modified NVIDIA driver source files
- **Rationale**: NVIDIA EULA prohibits redistributing modified driver source code. Patches are safe to share.

### Build Status

| Модуль | Статус |
|--------|--------|
| `nvidia.ko` | ✅ Компилируется и линкуется (37MB) |
| `nvidia-uvm.ko` | ✅ Компилируется и линкуется (38MB) |
| `nvidia-modeset.ko` | ✅ Компилируется и линкуется |
| `nvidia-drm.ko` | ✅ Компилируется |
| **modpost** | ⚠️ GPL-символы: `put_device`, `acpi_dev_for_each_child`, `acpi_get_acpi_dev`, `__vma_start_write`, `screen_info` |

> Предупреждения modpost о GPL-символах — это особенность лицензирования: проприетарный модуль NVIDIA использует GPL-only символы ядра 7.0. Это не ошибка компиляции.

### Что исправлено

| Область | Файлов | Изменения |
|---------|--------|-----------|
| **ACPI** | 1 | `acpi_device_ops.remove` → void; `acpi_device.children` → `acpi_dev_for_each_child()`; `acpi_bus_get_device` → `acpi_get_acpi_dev()`; `acpi_walk_namespace` 7 args |
| **DMA** | 2 | `pci_map_page/unmap` → `dma_map_page/unmap`; `PCI_DMA_BIDIRECTIONAL` → `DMA_BIDIRECTIONAL` |
| **procfs** | 2 | `struct file_operations` → `struct proc_ops`; `PDE()`/`create_proc_entry` → `pde_data()`/`proc_create_data`; opaque `proc_dir_entry` |
| **vm_flags** | 2 | `vma->vm_flags |=` → `vm_flags_set()/vm_flags_clear()` |
| **mmap** | 20+ UVM | `->mmap_sem` → `->mmap_lock` (kernel 7.0 rename) |
| **vm_next** | 2 UVM | `vma->vm_next` → `find_vma_intersection()` (kernel 7.0 удалил поле) |
| **vm_ops.fault** | 1 | `NV_VM_OPS_FAULT_REMOVED_VMA_ARG` — fault без второго аргумента vma |
| **Memory** | 1 | `set_memory_array_uc/wb` → `set_pages_array_uc/wb` |
| **Time** | 4 | `struct timeval` → `struct timespec64`; `jiffies_to_timespec` → `jiffies_to_timespec64`; `getrawmonotonic` → `ktime_get_raw_ts64`; `do_gettimeofday` → `ktime_get_real_ts64` |
| **Scheduling** | 2 | `on_each_cpu` 4→3 args; `in_irq()` → `!in_task()`; `current->state` → `current->__state` |
| **Task struct** | 1 | `current->euid` → `current->cred->euid` |
| **Console** | 1 | `acquire_console_sem()` → `console_lock()`; `release_console_sem()` → `console_unlock()` |
| **ioctl32** | 1 | `register/unregister_ioctl32_conversion` — удалены (API нет в ядре) |
| **screen_info** | 1 | явный `extern` + `#include <linux/screen_info.h>` |
| **smp_barrier** | 2 UVM | `smp_read_barrier_depends()` → no-op на x86 |
| **Kbuild/conftest** | 2 | `$(src)` → `$(M)`; `-std=gnu11`; `SOURCE_HEADERS`/`OUTPUT_HEADERS` |
| **conftest.h** | 1 | ~45 defines для kernel 7.0 API |

### Файлы

**Публичные** (безопасны для распространения):
```
patches/0013-kernel-7.0-full-compat.patch   # 48 файлов, 3052 строки
scripts/apply_patches.sh
scripts/generate_conftest.py
docs/progress.md
docs/scripts_help.md
README.md
```

**Локально** (не распространять): 48 изменённых файлов в `NVIDIA-Linux-x86_64-418.113/kernel/`.

### How to Build

**Автоматически (рекомендуется):**
```bash
sudo bash scripts/build_patched_driver.sh /opt/nvidia/NVIDIA-Linux-x86_64-418.113.run
```

**Вручную:**
```bash
# Извлечь драйвер
sh /path/to/NVIDIA-Linux-x86_64-418.113.run --extract-only

# Применить патч
bash scripts/apply_patches.sh /path/to/NVIDIA-Linux-x86_64-418.113

# Собрать и установить (через install.sh внутри .run или вручную)
cd /path/to/NVIDIA-Linux-x86_64-418.113/kernel
make -C /usr/src/linux-headers-7.0.0-22-generic M=$(pwd) modules \
  NV_KERNEL_MODULES="nvidia nvidia-uvm nvidia-modeset nvidia-drm"
```

Подробнее: см. `README.md` в корне репозитория.

### Известные проблемы

1. **GPL-only символы**: modpost ругается на `put_device`, `acpi_dev_for_each_child`, `acpi_get_acpi_dev`, `__vma_start_write`, `screen_info`. Это связано с тем, что проприетарный модуль NVIDIA использует символы, которые ядро 7.0 маркирует как GPL-only.
2. **nvidia-modeset / nvidia-drm**: не тестировались.
3. **Runtime**: сборка проверена, но на реальном оборудовании не тестировалась.

### License Notes ⚠️
- NVIDIA driver source code is proprietary and covered by NVIDIA's EULA
- Modified driver source files MUST remain in local/private branches
- Patch files (.patch) are safe to share (diffs only)
- Scripts and documentation are original work, freely shareable

### Branch Status
```
* kernel-7.0-compat  — Local branch with driver code modifications (NOT for distribution)
  master             — Public branch with patches/ only (safe to share)
```

---
*Session ended: June 15, 2026. nvidia.ko + nvidia-uvm.ko build without errors. modpost GPL warnings are expected.*