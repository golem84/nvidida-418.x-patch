# NVIDIA 418.113 Patch Scripts

Вспомогательные скрипты для патча NVIDIA 418.113 драйвера под kernel 7.0.

## Скрипты

### apply_patches.sh

Применяет единый патч `0013-kernel-7.0-full-compat.patch` (48 файлов) к чистой выгрузке драйвера, затем генерирует conftest.

```bash
./scripts/apply_patches.sh /path/to/NVIDIA-Linux-x86_64-418.113
```

### generate_conftest.py

Генерирует conftest.h — набор defines, определяющих доступность API ядра. Штатный механизм NVIDIA (conftest.sh → Kbuild) некорректно работает для внешних модулей; скрипт запускает 175 тестов напрямую.

```bash
cd /path/to/NVIDIA-Linux-x86_64-418.113/kernel
python3 /path/to/scripts/generate_conftest.py
```

**Генерирует**: `conftest/functions.h`, `conftest/types.h`, `conftest/symbols.h`, `conftest/headers.h`, `conftest/conftest.h`

## Полный цикл сборки

```bash
# 1. Извлечь драйвер
sh /path/to/NVIDIA-Linux-x86_64-418.113.run --extract-only

# 2. Применить патч + conftest
./scripts/apply_patches.sh /path/to/NVIDIA-Linux-x86_64-418.113

# 3. Скопировать бинарный блоб
cp /path/to/original/kernel/nvidia/nv-kernel.o_binary \
   /path/to/NVIDIA-Linux-x86_64-418.113/kernel/nvidia/nv-kernel.o

# 4. Собрать
cd /path/to/NVIDIA-Linux-x86_64-418.113/kernel
make -C /usr/src/linux-headers-7.0.0-22-generic M=$(pwd) modules \
  NV_KERNEL_MODULES="nvidia nvidia-uvm nvidia-modeset nvidia-drm"
```

## Требования

- Python 3.6+
- Kernel headers: `/usr/src/linux-headers-7.0.0-22` и `/usr/src/linux-headers-7.0.0-22-generic`
- GCC, совместимый с версией сборки ядра