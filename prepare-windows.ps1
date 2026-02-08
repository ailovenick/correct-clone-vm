# ==============================================================================
# Скрипт подготовки Windows к клонированию (Sysprep)
# Назначение: Удаление уникальных идентификаторов (SID) и очистка системы перед созданием Gold Image
# ==============================================================================

# Проверка прав администратора
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Скрипт должен быть запущен от имени Администратора!"
    exit
}

Write-Host "--- Начало подготовки Windows к клонированию ---" -ForegroundColor Green

# 1. Очистка журналов событий (Event Logs)
# Удаление истории системных событий, приложений и безопасности для чистого старта клона
Write-Host "[1/5] Очистка журналов событий Windows..." -ForegroundColor Cyan
Get-EventLog -LogName * | ForEach-Object { 
    try { Clear-EventLog $_.Log } catch { Write-Warning "Не удалось очистить лог: $($_.Log)" }
}

# 2. Очистка временных файлов и корзины
# Удаление временных данных текущего пользователя, системных временных файлов и очистка корзины
Write-Host "[2/5] Удаление временных файлов и очистка корзины..." -ForegroundColor Cyan
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Clear-RecycleBin -Confirm:$false -ErrorAction SilentlyContinue

# 3. Сброс сетевых настроек
# Очистка кэша DNS и сброс стека TCP/IP для предотвращения конфликтов сетевых настроек
Write-Host "[3/5] Сброс сетевого стека..." -ForegroundColor Cyan
netsh winsock reset | Out-Null
netsh int ip reset | Out-Null
ipconfig /flushdns | Out-Null

# 4. Очистка истории PowerShell
# Удаление истории введённых команд для исключения утечки чувствительных данных
Write-Host "[4/5] Очистка истории PowerShell..." -ForegroundColor Cyan
$historyPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $historyPath) {
    Clear-Content $historyPath
}

# 5. Запуск Sysprep
# /generalize - Удаление уникальных данных (SID, GUID, имя компьютера)
# /oobe       - Перевод в режим "первого включения" (экран приветствия при загрузке клона)
# /shutdown   - Выключение ВМ по завершении процесса (обязательно для создания шаблона)
# /mode:vm    - Оптимизация для виртуальных машин (пропускает проверку оборудования, экономит время)

$sysprepPath = "$env:windir\System32\Sysprep\sysprep.exe"

if (Test-Path $sysprepPath) {
    Write-Host "[5/5] Запуск Sysprep..." -ForegroundColor Magenta
    Write-Host "ВНИМАНИЕ: Система будет выключена автоматически. После этого создавайте шаблон." -ForegroundColor Yellow
    
    # Запуск процесса подготовки
    Start-Process -FilePath $sysprepPath -ArgumentList "/generalize /oobe /shutdown /mode:vm" -Wait
} else {
    Write-Error "Критическая ошибка: Утилита Sysprep не найдена по пути $sysprepPath"
}
