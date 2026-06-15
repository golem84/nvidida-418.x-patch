# nvidida-418.x-patch

Патчи для сборки NVIDIA 418.113 драйвера на ядре 7.0.0-22-generic (Ubuntu 24.04, GCC 15.2.0).

## Как использовать (одна команда)

```bash
# 1. Клонируй репозиторий
git clone https://github.com/golem84/nvidida-418.x-patch.git
cd nvidida-418.x-patch

# 2. Установи зависимости
sudo apt install makeself python3

# 3. Запусти автоматическую сборку
sudo bash scripts/build_patched_driver.sh /opt/nvidia/NVIDIA-Linux-x86_64-418.113.run
```

Скрипт сделает всё автоматически:
1. Распакует `.run` пакет
2. Применит патч совместимости с kernel 7.0
3. Сгенерирует conftest
4. Скопирует бинарный блоб `nv-kernel.o`
5. Упакует обратно в `NVIDIA-Linux-x86_64-418.113-patched.run`

**Компиляция модулей ядра происходит при установке** — так же, как в оригинальном драйвере.

## Установка драйвера

```bash
sudo sh /path/to/NVIDIA-Linux-x86_64-418.113-patched.run
sudo reboot
```

### Контроль успешной установки

```bash
nvidia-smi                     # GPU, температура, память
lsmod | grep nvidia            # Загруженные модули
cat /proc/driver/nvidia/version  # Версия драйвера
```

### Логи при неудачной установке

| Файл | Что содержит |
|------|-------------|
| `/var/log/nvidia-patched-install-*.log` | Лог установки модулей и nvidia-installer |
| `/var/log/Xorg.0.log` | Лог X сервера |
| `/var/log/syslog` | Системные сообщения ядра |
| `dmesg \| grep nvidia` | Сообщения от модулей nvidia |

### Активация драйвера

```bash
# Отключи nouveau (если не отключён)
echo 'blacklist nouveau' | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
echo 'options nouveau modeset=0' | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
sudo update-initramfs -u

# Для ноутбуков с Optimus:
sudo prime-select nvidia
# Для десктопов:
sudo nvidia-xconfig

sudo reboot
```

### Откат установки

Если после перезагрузки система не загружается — загрузи recovery mode (GRUB → Advanced → recovery → root shell):

```bash
# 1. Удали модули NVIDIA
sudo rm -rf /lib/modules/$(uname -r)/kernel/drivers/video/nvidia*
sudo rm -rf /lib/modules/$(uname -r)/kernel/drivers/char/nvidia*
sudo depmod -a

# 2. Удали GL-библиотеки и X-конфиги
sudo nvidia-uninstall 2>/dev/null || true
sudo apt purge '*nvidia*' 2>/dev/null || true

# 3. Восстанови nouveau
sudo apt install xserver-xorg-video-nouveau
sudo update-initramfs -u

sudo reboot
```

## Ручное применение патча (без makeself)

Если `makeself` недоступен, можно применить патч вручную:

```bash
# 1. Извлеки драйвер
sh /path/to/NVIDIA-Linux-x86_64-418.113.run --extract-only

# 2. Примени патч
bash scripts/apply_patches.sh /path/to/NVIDIA-Linux-x86_64-418.113

# 3. Скопируй бинарный блоб
cp /path/to/extracted/kernel/nvidia/nv-kernel.o_binary \
   /path/to/NVIDIA-Linux-x86_64-418.113/kernel/nvidia/nv-kernel.o

# 4. Собери и установи модули
cd /path/to/NVIDIA-Linux-x86_64-418.113/kernel
make -C /usr/src/linux-headers-7.0.0-22-generic M=$(pwd) modules \
  NV_KERNEL_MODULES="nvidia nvidia-uvm nvidia-modeset nvidia-drm"
sudo make modules_install
sudo depmod -a
```

## Структура репозитория

```
patches/
  0013-kernel-7.0-full-compat.patch   # Патч (48 файлов)
scripts/
  build_patched_driver.sh             # 🚀 Полная автоматизация (рекомендуется)
  apply_patches.sh                    # Только применение патча
  generate_conftest.py                # Генерация conftest
docs/
  progress.md                         # Прогресс и статус
```

## Статус сборки модулей

- **nvidia.ko** — OK
- **nvidia-uvm.ko** — OK
- **nvidia-modeset.ko** — OK
- **nvidia-drm.ko** — OK
- **nv-kernel.o** — требуется из оригинального `.run` пакета
- **modpost**: предупреждения о GPL-символах (не ошибка, особенность лицензирования)

## Лицензия

Патчи безопасны для распространения (содержат только diff). Модифицированные исходники NVIDIA подпадают под EULA NVIDIA.

Оригинальный драйвер: https://www.nvidia.com/download/driverResults.aspx/149896/