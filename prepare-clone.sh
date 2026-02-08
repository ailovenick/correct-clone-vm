#!/bin/bash

# Настройка цветов для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Проверка наличия прав суперпользователя
if [ "$EUID" -ne 0 ]; then
  error "Запуск невозможен: требуются права root (sudo)."
  exit 1
fi

# --- Подготовка (Рекомендация) ---
# Перед запуском убедитесь, что установлены агенты интеграции и cloud-init, а также что они настроены на автоматический запуск при загрузке.:
# Hyper-V: hyperv-daemons | VMware: open-vm-tools | KVM: qemu-guest-agent | Proxmox: qemu-guest-agent | VirtualBox: guest-additions | Cloud-init: cloud-init 

# --- Настройка Cloud-init ---
# Cloud-init используется для конфигурации системы при первой загрузке (hostname, ключи, сеть)
if [ -f "99-local.cfg" ]; then
    log "Конфигурация cloud-init: копирование 99-local.cfg в /etc/cloud/cloud.cfg.d/..."
    cp 99-local.cfg /etc/cloud/cloud.cfg.d/99-local.cfg
    chmod 644 /etc/cloud/cloud.cfg.d/99-local.cfg
    log "Конфигурация успешно применена."
else
    log "Внимание: 99-local.cfg не найден. Настройка cloud-init пропущена."
fi

# --- Начало процесса очистки ---

log "Остановка службы системного журнала (rsyslog) для освобождения файлов логов..."
systemctl stop rsyslog 2>/dev/null

log "Очистка данных cloud-init (сброс состояния для выполнения при следующем старте)..."
if command -v cloud-init >/dev/null 2>&1; then
    cloud-init clean --logs
else
    log "cloud-init не установлен, пропуск шага."
fi

log "Удаление уникальных SSH-ключей хоста (будут пересозданы при загрузке)..."
# Удаление ключей гарантирует, что у каждого клона будут свои уникальные ключи шифрования
rm -vf /etc/ssh/ssh_host_*

log "Сброс Machine ID и Hostname (критично для уникальности идентификации)..."
# Удаление machine-id в /var/lib/dbus (старый путь)
if [ -f /var/lib/dbus/machine-id ]; then
    rm -v /var/lib/dbus/machine-id
fi
# Зануление /etc/machine-id (современный путь). 
# Файл должен существовать пустым, чтобы systemd сгенерировал новый при загрузке.
truncate -s 0 /etc/machine-id

# Сброс имени хоста до дефолтного, чтобы клоны не наследовали имя мастера
echo "localhost" > /etc/hostname

# Очистка /etc/hosts (оставляем только базовый localhost)
# cloud-init при первом запуске сам добавит нужные записи, если manage_etc_hosts: true
cat <<EOF > /etc/hosts
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# Сброс почтового имени (если файл существует)
if [ -f /etc/mailname ]; then
    echo "localhost" > /etc/mailname
fi

# Удаление seed-файла генератора случайных чисел для обеспечения энтропии у клонов
rm -f /var/lib/systemd/random-seed
log "Machine ID, Hostname, /etc/hosts и Random Seed успешно сброшены."

log "Очистка кэша пакетного менеджера и временных директорий..."
apt-get clean
rm -rfv /var/lib/apt/lists/*
rm -rfv /tmp/*
rm -rfv /var/tmp/*

log "Ротация и агрессивная очистка системных журналов..."
# Сжатие текущих логов и удаление всего, что старше 1 секунды
journalctl --rotate
journalctl --vacuum-time=1s
# Обнуление текстовых файлов логов в /var/log без удаления самих файлов (сохранение прав доступа)
find /var/log -type f -exec truncate -s 0 {} \;

log "Очистка истории команд (bash, zsh и др.)..."
# Поиск и зануление файлов истории для всех пользователей, включая root
find /home /root -maxdepth 2 -name ".*_history" -type f -exec truncate -s 0 {} \;
# Очистка истории текущего сеанса терминала
history -c
history -w

log "Подготовка завершена. Система готова к созданию шаблона/клонированию."
log "Автоматическое выключение через 10 секунд (отмена: Ctrl+C)..."
sleep 10

poweroff