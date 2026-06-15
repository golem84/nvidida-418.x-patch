# NVIDIA 418.113 Kernel 7.0 Compatibility Patches

Единый патч для сборки NVIDIA 418.113 драйвера на kernel 7.0.0-22-generic (Ubuntu 24.04).

## Патч

| Файл | Файлов | Описание |
|------|--------|----------|
| `0013-kernel-7.0-full-compat.patch` | 48 | Все исправления для kernel 7.0 |

## Что исправляет (48 файлов)

- **ACPI**: `acpi_device_ops.remove` (void), `acpi_device.children` → `acpi_dev_for_each_child()`, `acpi_bus_get_device` → `acpi_get_acpi_dev()`, `acpi_walk_namespace` (7 args)
- **DMA**: `pci_map_page/unmap` → `dma_map_page/unmap`, `PCI_DMA_` → `DMA_`
- **procfs**: `struct proc_ops`, `pde_data()`, opaque `proc_dir_entry`
- **vm_flags**: `vm_flags_set()/vm_flags_clear()`
- **mmap**: `mmap_sem` → `mmap_lock` (20+ файлов UVM)
- **vm_next**: → `find_vma_intersection()` (kernel 7.0 удалил `vm_next`)
- **Memory**: `set_pages_array_uc/wb`
- **Time**: `struct timespec64`, `ktime_get_raw_ts64`, `jiffies_to_timespec64`
- **Scheduling**: `on_each_cpu` (3 args), `!in_task()`, `current->__state`
- **Прочее**: `console_lock`, `task->cred->euid`, `screen_info`, `ioctl32` removed, `smp_read_barrier_depends` fallback

## License Notice

Патчи **безопасны для публичного распространения**. Содержат только diff и не включают существенных фрагментов проприетарного кода NVIDIA. Модифицированные исходники драйвера подпадают под EULA NVIDIA и не должны распространяться.

## См. также

- `../README.md` — полная инструкция по сборке и установке
- `../docs/progress.md` — прогресс и статус
