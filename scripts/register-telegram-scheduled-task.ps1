# HEDEF Kamu — PC acilinca TELEGRAM.bat /auto
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
    [string]$TaskName = "HEDEFKamu-TelegramDrain",
    [int]$DelaySeconds = 45
)

$ErrorActionPreference = "Stop"

$BatPath = Join-Path $ProjectRoot "TELEGRAM.bat"
$LogDir = Join-Path $ProjectRoot "logs"
$LogPath = Join-Path $LogDir "telegram-auto.log"

function Test-ProjectReady {
    if (-not (Test-Path $BatPath)) {
        throw "TELEGRAM.bat bulunamadi: $BatPath"
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
    return "cmd.exe /c `"`"$BatPath`" /auto >> `"$LogPath`" 2>&1`""
}

function Get-StartupLauncherPath {
    $startup = [Environment]::GetFolderPath("Startup")
    return Join-Path $startup "HEDEFKamu-Telegram-Auto.bat"
}

function Register-StartupLauncher {
    $launcher = Get-StartupLauncherPath
    $content = @"
@echo off
rem HEDEF Kamu — oturum acilinca Telegram kuyrugu (Startup klasoru)
timeout /t 45 /nobreak >nul
call "$BatPath" /auto
"@
    Set-Content -Path $launcher -Value $content -Encoding UTF8
    return $launcher
}

function Unregister-StartupLauncher {
    $launcher = Get-StartupLauncherPath
    if (Test-Path $launcher) {
        Remove-Item $launcher -Force
    }
}

function Test-StartupLauncherExists {
    return Test-Path (Get-StartupLauncherPath)
}

function Test-TaskExists {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = cmd /c "schtasks /Query /TN `"$TaskName`" /FO LIST 2>nul"
    $ok = ($LASTEXITCODE -eq 0) -and ($out -match "TaskName")
    $ErrorActionPreference = $prev
    return $ok
}

if ($Status) {
    $hasTask = Test-TaskExists
    $hasStartup = Test-StartupLauncherExists
    if (-not $hasTask -and -not $hasStartup) {
        Write-Host "Otomatik aktarim kurulu degil."
        Write-Host "Kurulum: KUR-TELEGRAM-ZAMANLAYICI.bat"
        exit 0
    }
    if ($hasTask) {
        Write-Host "=== Gorev Zamanlayicisi ==="
        schtasks /Query /TN $TaskName /V /FO LIST
        Write-Host ""
    }
    if ($hasStartup) {
        Write-Host "=== Baslangic klasoru (Startup) ==="
        Write-Host (Get-StartupLauncherPath)
        Write-Host ""
    }
    Write-Host "Bat : $BatPath /auto"
    Write-Host "Log : $LogPath"
    exit 0
}

if ($Unregister) {
    $prevEa = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    if (Test-TaskExists) {
        cmd /c "schtasks /Delete /TN `"$TaskName`" /F" 2>$null | Out-Null
        Write-Host "Gorev zamanlayicisi kaldirildi: $TaskName"
    }
    $ErrorActionPreference = $prevEa
    if (Test-StartupLauncherExists) {
        Unregister-StartupLauncher
        Write-Host "Startup launcher kaldirildi."
    }
    if (-not (Test-TaskExists) -and -not (Test-StartupLauncherExists)) {
        Write-Host "Otomatik aktarim zaten yok."
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

$schtasksOk = $false
$prevEa = $ErrorActionPreference
$ErrorActionPreference = "Continue"
cmd /c "schtasks /Create /TN `"$TaskName`" /TR `"$taskCmd`" /SC ONLOGON /DELAY $delay /RL LIMITED /F" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $schtasksOk = $true }
$ErrorActionPreference = $prevEa

if ($schtasksOk) {
    Unregister-StartupLauncher
    Write-Host ""
    Write-Host "Gorev Zamanlayicisi kuruldu (tercih edilen yontem)."
    Write-Host "  Gorev adi : $TaskName"
    Write-Host "  Tetik     : Oturum acilisi + ${DelaySeconds}s"
    Write-Host "  Calistir  : $BatPath /auto"
    Write-Host "  Log       : $LogPath"
    Write-Host ""
    Write-Host "Test: Gorev Zamanlayicisi -> $TaskName -> Calistir"
    Write-Host "Kaldir: KALDIR-TELEGRAM-ZAMANLAYICI.bat"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "Gorev Zamanlayicisi kurulamadi (Erisim engellendi veya yetki yok)."
Write-Host "Yedek yontem: Windows Baslangic klasorune launcher yaziliyor..."
Write-Host ""

$launcher = Register-StartupLauncher
Write-Host "Startup launcher kuruldu (yonetici gerekmez):"
Write-Host "  $launcher"
Write-Host "  Tetik: Oturum acilisi + ${DelaySeconds}s bekleme"
Write-Host "  Log  : $LogPath"
Write-Host ""
Write-Host "Not: Ilk acilista kisa bir cmd penceresi gorulebilir."
Write-Host "Kaldir: KALDIR-TELEGRAM-ZAMANLAYICI.bat"
Write-Host ""
