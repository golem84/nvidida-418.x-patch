# nvidida-418.x-patch

Патчи для сборки NVIDIA 418.113 драйвера на ядре 7.0.0-22-generic (Ubuntu 24.04, GCC 15.2.0).

## Быстрый старт — автоматическая сборка

```bash
# Установи зависимости
sudo apt install makeself build-essential gcc make python3

# Запусти полную автоматическую сборку
sudo ./scripts/build_patched_driver.sh /path/to/NVIDIA-Linux-x86_64-418.113.run
```

Скрипт выполнит:
1. Распаковку `.run` пакета
2. Применение патча совместимости с kernel 7.0
3. Копирование бинарного блоба `nv-kernel.o`
4. Компиляцию модулей ядра (`nvidia`, `nvidia-uvm`, `nvidia-modeset`, `nvidia-drm`)
5. Упаковку обратно в `.run` файл

Результат: `NVIDIA-Linux-x86_64-418.113-patched.run`

## Установка драйвера

```bash
# Запусти собранный пакет от root
sudo sh /path/to/NVIDIA-Linux-x86_64-418.113-patched.run

# Перезагрузи систему
sudo reboot
```

### Контроль успешной установки

После перезагрузки проверь:

```bash
# Проверка видимости GPU и драйвера
nvidia-smi

# Проверка загруженных модулей
lsmod | grep nvidia

# Просмотр версии драйвера
cat /proc/driver/nvidia/version

# Проверка лога установки
cat /var/log/nvidia-patched-install-*.log
tail -n 50 /var/log/Xorg.0.log
```

**Признаки успеха:**
- `nvidia-smi` показывает GPU, температуру, использование памяти
- `lsmod` показывает `nvidia`, `nvidia-uvm`, `nvidia-modeset`, `nvidia-drm`
- X сервер запускается без ошибок

### Логи при неудачной установке

| Файл | Что содержит |
|------|-------------|
| `/var/log/nvidia-patched-install-*.log` | Лог установки модулей и nvidia-installer |
| `/var/log/Xorg.0.log` | Лог X сервера (ошибки GL, драйвера) |
| `/var/log/syslog` | Системные сообщения ядра |
| `dmesg \| grep nvidia` | Сообщения от модулей nvidia в кольцевом буфере ядра |

## Активация драйвера

Если после установки драйвер не активирован (используется nouveau или vesa):

```bash
# Отключи nouveau (если ещё не отключён)
echo 'blacklist nouveau' | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
echo 'options nouveau modeset=0' | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
sudo update-initramfs -u

# Переключи драйвер вручную
sudo prime-select nvidia     # для ноутбуков с Optimus
# или
sudo nvidia-xconfig          # для десктопов

# Перезагрузи
sudo reboot
```

## Откат установки

Если после перезагрузки система не загружается или X сервер падает:

```bash
# Загрузися в recovery mode (выбери "Advanced options" в GRUB → recovery → root shell)

# 1. Удали установленные модули NVIDIA
sudo rm -rf /lib/modules/$(uname -r)/kernel/drivers/video/nvidia*
sudo rm -rf /lib/modules/$(uname -r)/kernel/drivers/char/nvidia*
sudo depmod -a

# 2. Удали GL-библиотеки и X-конфиги (если nvidia-installer их установил)
sudo nvidia-uninstall 2>/dev/null || true
sudo apt purge '*nvidia*' 2>/dev/null || true

# 3. Восстанови стандартный драйвер
sudo apt install xserver-xorg-video-nouveau
sudo update-initramfs -u

# 4. Перезагрузи
sudo reboot
```

Если откат через recovery невозможен — загрузись с Live USB, примонтируй корневой раздел и выполни шаги 1-3 из chroot.

## Ручная сборка (без автоматизации)

```bash
# Извлеки оригинальный драйвер
sh /path/to/NVIDIA-Linux-x86_64-418.113.run --extract-only

# Примени патч
./scripts/apply_patches.sh /path/to/NVIDIA-Linux-x86_64-418.113

# Скопируй бинарный блоб
cp /path/to/original/kernel/nvidia/nv-kernel.o_binary \
   /path/to/NVIDIA-Linux-x86_64-418.113/kernel/nvidia/nv-kernel.o

# Собери все модули
cd /path/to/NVIDIA-Linux-x86_64-418.113/kernel
make -C /usr/src/linux-headers-7.0.0-22-generic M=$(pwd) modules \
  NV_KERNEL_MODULES="nvidia nvidia-uvm nvidia-modeset nvidia-drm"
```

## Структура

```
patches/
  0013-kernel-7.0-full-compat.patch   # Единый патч (48 файлов)
scripts/
  apply_patches.sh                    # Скрипт применения патча
  generate_conftest.py                # Генерация conftest
  build_patched_driver.sh             # Полная автоматизация сборки
docs/
  progress.md                         # Прогресс и статус
  scripts_help.md                     # Документация скриптов
```

## Статус

- **nvidia.ko** — компилируется и линкуется ✅
- **nvidia-uvm.ko** — компилируется и линкуется ✅
- **nvidia-modeset.ko** — компилируется и линкуется ✅
- **nvidia-drm.ko** — компилируется ✅
- **nv-kernel.o** — требуется из оригинального `.run` пакета
- **modpost**: предупреждения о GPL-символах (связано с проприетарным статусом драйвера, не ошибка)

## Лицензия

Патчи безопасны для распространения (содержат только diff). Модифицированные исходники NVIDIA подпадают под EULA NVIDIA.

Оригинальный драйвер: https://www.nvidia.com/download/driverResults.aspx/149896/
