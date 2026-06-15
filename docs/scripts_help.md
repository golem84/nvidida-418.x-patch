# NVIDIA 418.113 Patch Scripts

Вспомогательные скрипты для патча NVIDIA 418.113 драйвера под kernel 7.0.

Скрипты вызываются автоматически из `build_patched_driver.sh`. Ручной запуск нужен только при отладке.

## Скрипты

### apply_patches.sh

Применяет единый патч `0013-kernel-7.0-full-compat.patch` (48 файлов) к чистой выгрузке драйвера, затем генерирует conftest.

```bash
bash scripts/apply_patches.sh /path/to/NVIDIA-Linux-x86_64-418.113
```

### generate_conftest.py

Генерирует conftest.h — набор defines, определяющих доступность API ядра. Штатный механизм NVIDIA (conftest.sh → Kbuild) некорректно работает для внешних модулей; скрипт запускает тесты напрямую.

```bash
cd /path/to/NVIDIA-Linux-x86_64-418.113/kernel
python3 /path/to/scripts/generate_conftest.py
```

**Генерирует**: `conftest/patches.h`, `conftest/functions.h`, `conftest/types.h`, `conftest/symbols.h`, `conftest/headers.h`, `conftest/conftest.h`

### build_patched_driver.sh (рекомендуется)

Полная автоматизация: распаковка `.run` → патч → упаковка в `.run`.

```bash
sudo bash scripts/build_patched_driver.sh /opt/nvidia/NVIDIA-Linux-x86_64-418.113.run
```

Подробнее: см. `README.md` в корне репозитория.

## Требования

- Python 3.6+
- Kernel headers: `/usr/src/linux-headers-7.0.0-22` и `/usr/src/linux-headers-7.0.0-22-generic`
- GCC, совместимый с версией сборки ядра