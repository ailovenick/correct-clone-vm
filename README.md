# Gold Image Utils

Инструменты для подготовки эталонных образов (Template) Linux и Windows.
**Назначение:** Гарантированная очистка идентификаторов (Machine-ID, SID, Keys) и логов перед клонированием.

---

## 🔁 Workflow

1.  **Operator:** Установка ОС, софта, обновлений.
2.  **Script:** Обезличивание системы, очистка мусора, выключение.
3.  **Hypervisor:** Создание снапшота/шаблона.

---

## 🐧 Linux (Ubuntu / Debian)

### 1. Подготовка (Ручная)
Установить обязательные компоненты перед запуском скрипта:
```bash
# Агенты виртуализации (выбрать свой)
apt install qemu-guest-agent -y  # Proxmox/KVM
apt install open-vm-tools -y     # VMware
apt install hyperv-daemons -y    # Hyper-V

# Инициализация (обязательно)
apt install cloud-init -y
```

### 2. Очистка (Автоматическая)
Запуск от root. Файл `99-local.cfg` должен лежать рядом со скриптом.

```bash
chmod +x prepare-clone.sh
sudo ./prepare-clone.sh
```

**Результат:**
*   Конфиг `cloud-init` применен (оптимизация загрузки, SSH-ключи).
*   Machine-ID и Random Seed сброшены.
*   Логи и история занулены.
*   Система выключена.

<details>
<summary><strong>Manual Reference (Инструкция для ручного выполнения)</strong></summary>

Выполните команды от имени **root**:

1.  **Настройка Cloud-Init:**
    Создайте файл `/etc/cloud/cloud.cfg.d/99-local.cfg` с нужными параметрами (см. репозиторий).

2.  **Сброс идентификаторов:**
    ```bash
    # Удаляем SSH ключи (создадутся новые при загрузке)
    rm -f /etc/ssh/ssh_host_*
    
    # Сбрасываем Machine-ID
    truncate -s 0 /etc/machine-id
    rm -f /var/lib/dbus/machine-id
    
    # Сбрасываем Random Seed
    rm -f /var/lib/systemd/random-seed
    ```

3.  **Сброс имени хоста:**
    ```bash
    echo "localhost" > /etc/hostname
    echo "localhost" > /etc/mailname
    
    # Очистка /etc/hosts
    cat > /etc/hosts <<EOF
    127.0.0.1       localhost
    ::1             localhost ip6-localhost ip6-loopback
    ff02::1         ip6-allnodes
    ff02::2         ip6-allrouters
    EOF
    ```

4.  **Очистка системы:**
    ```bash
    # Очистка cloud-init
    cloud-init clean --logs
    
    # Очистка логов и истории
    journalctl --rotate --vacuum-time=1s
    history -c
    history -w
    ```

5.  **Финиш:**
    Выключите сервер командой `poweroff`.
</details>

---

## 🪟 Windows

### 1. Подготовка (Ручная)
1.  Установить драйверы (VirtIO / VMware Tools).
2.  Установить обновления ОС и софт.
3.  **Остановить службу обновлений** (`wuauserv`).

### 2. Очистка (Автоматическая)
Запуск в PowerShell (Admin):
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; .\prepare-windows.ps1
```

**Результат:**
*   Сетевой стек сброшен.
*   Временные файлы и Event Logs очищены.
*   Запущен `Sysprep /generalize /oobe /mode:vm`.

<details>
<summary><strong>Manual Reference (Инструкция для ручного выполнения)</strong></summary>

1.  **Очистка событий (Event Viewer):**
    *   Откройте `eventvwr.msc`.
    *   ПКМ по журналам *Windows Logs* (Application, Security, System) -> **Clear Log**.

2.  **Удаление мусора:**
    *   Запустите `cleanmgr` (Очистка диска).
    *   Удалите содержимое папок `C:\Windows\Temp` и `%TEMP%`.

3.  **Сброс сети (CMD от Админа):**
    ```cmd
    netsh winsock reset
    netsh int ip reset
    ipconfig /flushdns
    ```

4.  **Финальный Sysprep:**
    *   Нажмите `Win + R`, введите:
        `C:\Windows\System32\Sysprep\sysprep.exe`
    *   **System Cleanup Action:** Enter System Out-of-Box Experience (OOBE).
    *   **Generalize:** ✅ (Галочка обязательна!).
    *   **Shutdown Options:** Shutdown.
</details>