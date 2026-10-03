# HEDEF Kamu — PC acilinca TELEGRAM-WATCH.bat (surekli dinleme)
# Kullanim:
#   .\register-telegram-scheduled-task.ps1 -Register
#   .\register-telegram-scheduled-task.ps1 -Unregister
#   .\register-telegram-scheduled-task.ps1 -Status

[CmdletBinding(DefaultParameterSetName = "Register")]
param(
    [Parameter(ParameterSetName = "Register")]
    [switch]$Register,

    [Parameter(ParameterSetName = "Unregister")]
    [switch]$Unregister,

    [Parameter(ParameterSetName = "Status")]
    [switch]$Status,

    [string]$ProjectRoot = "D:\HEDEFKAMU",
    [string]$TaskName = "HEDEFKamu-TelegramWatch",
    [string]$LegacyTaskName = "HEDEFKamu-TelegramDrain",
    [int]$DelaySeconds = 45
)

$ErrorActionPreference = "Stop"

$BatPath = Join-Path $ProjectRoot "TELEGRAM-WATCH.bat"
$LogDir = Join-Path $ProjectRoot "logs"
$LogPath = Join-Path $LogDir "telegram-watch.log"

function Test-ProjectReady {
    if (-not (Test-Path $BatPath)) {
        throw "TELEGRAM-WATCH.bat bulunamadi: $BatPath"
    }
    if (-not (Test-Path (Join-Path $ProjectRoot "backend\manage.py"))) {
        throw "backend\manage.py bulunamadi: $ProjectRoot"
    }
}

function Get-DelayMmSs {
    param([int]$TotalSeconds)
    $minutes = [math]::Floor($TotalSeconds / 60)
    $seconds = $TotalSeconds % 60
    return ('{0:0000}:{1:00}' -f $minutes, $seconds)
}

function Get-TaskCommandLine {
    $vbs = Join-Path $ProjectRoot "scripts\telegram-watch-hidden.vbs"
    if (Test-Path $vbs) {
        return "wscript.exe //B `"$vbs`""
    }
    return "powershell -NoProfile -WindowStyle Hidden -Command `"Start-Process -FilePath '$BatPath' -ArgumentList '/auto','__hidden__' -WindowStyle Hidden`""
}

function Get-StartupLauncherPath {
    $startup = [Environment]::GetFolderPath("Startup")
    return Join-Path $startup "HEDEFKamu-Telegram-Watch.bat"
}

function Get-LegacyStartupLauncherPath {
    $startup = [Environment]::GetFolderPath("Startup")
    return Join-Path $startup "HEDEFKamu-Telegram-Auto.bat"
}

function Register-StartupLauncher {
    $launcher = Get-StartupLauncherPath
    $vbs = Join-Path $ProjectRoot "scripts\telegram-watch-hidden.vbs"
    $content = @"
@echo off
rem HEDEF Kamu - oturum acilinca Telegram WATCH (arka plan, pencere yok)
timeout /t 45 /nobreak >nul
wscript.exe //B "$vbs"
"@
    Set-Content -Path $launcher -Value $content -Encoding UTF8
    $legacy = Get-LegacyStartupLauncherPath
    if (Test-Path $legacy) {
        Remove-Item $legacy -Force
    }
    return $launcher
}

function Unregister-StartupLauncher {
    foreach ($launcher in @(
            (Get-StartupLauncherPath),
            (Get-LegacyStartupLauncherPath)
        )) {
        if (Test-Path $launcher) {
            Remove-Item $launcher -Force
        }
    }
}

function Test-StartupLauncherExists {
    return (Test-Path (Get-StartupLauncherPath)) -or (Test-Path (Get-LegacyStartupLauncherPath))
}

function Test-TaskExists {
    param([string]$Name)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = cmd /c "schtasks /Query /TN `"$Name`" /FO LIST 2>nul"
    $ok = ($LASTEXITCODE -eq 0) -and ($out -match "TaskName")
    $ErrorActionPreference = $prev
    return $ok
}

function Remove-TaskIfExists {
    param([string]$Name)
    if (-not (Test-TaskExists -Name $Name)) { return }
    $prevEa = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    cmd /c "schtasks /Delete /TN `"$Name`" /F" 2>$null | Out-Null
    $ErrorActionPreference = $prevEa
    if (-not (Test-TaskExists -Name $Name)) {
        Write-Host "Gorev zamanlayicisi kaldirildi: $Name"
    }
}

if ($Status) {
    $hasTask = Test-TaskExists -Name $TaskName
    $hasLegacyTask = Test-TaskExists -Name $LegacyTaskName
    $hasStartup = Test-StartupLauncherExists
    if (-not $hasTask -and -not $hasLegacyTask -and -not $hasStartup) {
        Write-Host "Otomatik WATCH kurulu degil."
        Write-Host "Kurulum: KUR-TELEGRAM-ZAMANLAYICI.bat"
        exit 0
    }
    if ($hasTask) {
        Write-Host "=== Gorev Zamanlayicisi (WATCH) ==="
        schtasks /Query /TN $TaskName /V /FO LIST
        Write-Host ""
    }
    if ($hasLegacyTask) {
        Write-Host "=== Eski gorev (tek seferlik drain - kaldirin) ==="
        schtasks /Query /TN $LegacyTaskName /V /FO LIST
        Write-Host ""
    }
    if (Test-Path (Get-StartupLauncherPath)) {
        Write-Host "=== Baslangic klasoru (Startup) ==="
        Write-Host (Get-StartupLauncherPath)
        Write-Host ""
    }
    if (Test-Path (Get-LegacyStartupLauncherPath)) {
        Write-Host "=== Eski Startup launcher (tek seferlik - yenileyin) ==="
        Write-Host (Get-LegacyStartupLauncherPath)
        Write-Host ""
    }
    Write-Host "Bat : $BatPath /auto"
    Write-Host "Log : $LogPath"
    exit 0
}

if ($Unregister) {
    Remove-TaskIfExists -Name $TaskName
    Remove-TaskIfExists -Name $LegacyTaskName
    Unregister-StartupLauncher
    if (-not (Test-TaskExists -Name $TaskName) -and `
        -not (Test-TaskExists -Name $LegacyTaskName) -and `
        -not (Test-StartupLauncherExists)) {
        Write-Host "Otomatik WATCH zaten yok."
    }
    exit 0
}

if (-not $Register) {
    Write-Host "Parametre gerekli: -Register, -Unregister veya -Status"
    exit 1
}

Test-ProjectReady
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$delay = Get-DelayMmSs -TotalSeconds $DelaySeconds
$taskCmd = Get-TaskCommandLine

Remove-TaskIfExists -Name $LegacyTaskName

$schtasksOk = $false
$prevEa = $ErrorActionPreference
$ErrorActionPreference = "Continue"
cmd /c "schtasks /Create /TN `"$TaskName`" /TR `"$taskCmd`" /SC ONLOGON /DELAY $delay /RL LIMITED /F" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $schtasksOk = $true }
$ErrorActionPreference = $prevEa

if ($schtasksOk) {
    Unregister-StartupLauncher
    Write-Host ""
    Write-Host "Gorev Zamanlayicisi kuruldu (WATCH - surekli dinleme)."
    Write-Host "  Gorev adi : $TaskName"
    Write-Host "  Tetik     : Oturum acilisi + ${DelaySeconds}s"
    Write-Host "  Calistir  : TELEGRAM-WATCH.bat /auto (arka plan, gizli)"
    Write-Host "  Log       : $LogPath"
    Write-Host ""
    Write-Host "Test: Gorev Zamanlayicisi -> $TaskName -> Calistir"
    Write-Host "Kaldir: KALDIR-TELEGRAM-ZAMANLAYICI.bat"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "Gorev Zamanlayicisi kurulamadi (Erisim engellendi veya yetki yok)."
Write-Host "Yedek yontem: Windows Baslangic klasorune WATCH launcher yaziliyor..."
Write-Host ""

$launcher = Register-StartupLauncher
Write-Host "Startup launcher kuruldu (yonetici gerekmez):"
Write-Host "  $launcher"
Write-Host "  Tetik: Oturum acilisi + ${DelaySeconds}s -> TELEGRAM-WATCH.bat /auto"
Write-Host "  Log  : $LogPath"
Write-Host ""
Write-Host "Not: Gorev cubugunda pencere gorunmez; log: $LogPath"
Write-Host "Kaldir: KALDIR-TELEGRAM-ZAMANLAYICI.bat"
Write-Host ""
