@echo off
title Xbox & GameInput Procedural Restore v2.0 (Final Verified)
setlocal DisableDelayedExpansion

:: ============================================================================
:: 0. ENSURE 64-BIT HOST (PREVENT WOW64 SYSTEM32 REDIRECTION)
:: ============================================================================
if defined PROCESSOR_ARCHITEW6432 (
    if exist "%SystemRoot%\Sysnative\cmd.exe" (
        "%SystemRoot%\Sysnative\cmd.exe" /c ""%~f0" %*"
        exit /b %errorLevel%
    )
)

:: ============================================================================
:: 1. AUTO-ELEVATE TO ADMINISTRATOR (Single-Window Hand-off)
:: ============================================================================
net session >nul 2>&1
if errorlevel 1 (
    echo Requesting Administrator privileges...
    set "RESTORE_SELF=%~f0"
    powershell -NoProfile -Command "try { Start-Process -FilePath $env:RESTORE_SELF -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Administrator privileges were declined.
        pause
        exit /b 1
    )
    exit /b 0
)

cd /d "%~dp0"
cls
echo.
echo  ====================================================================
echo           XBOX ^& MICROSOFT GAMEINPUT PROCEDURAL RESTORE
echo  ====================================================================
echo   Executing 6-stage directory unlock, binary, and service restore...
echo  --------------------------------------------------------------------

:: STAGES 1 TO 3: Directory Unlock, System32 Binary Restore, and Service Recovery
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'SilentlyContinue'; " ^
    "Write-Host ''; " ^
    "Write-Host '  [STAGE 1/6] Removing Program Files ACL locks & restoring permissions...' -FG Cyan; " ^
    "$lockDirs = @('C:\Program Files (x86)\Microsoft GameInput','C:\Program Files\Microsoft GameInput'); " ^
    "foreach ($dir in$lockDirs) { " ^
    "  & takeown.exe /f $dir /a 2>&1 | Out-Null; " ^
    "  & icacls.exe $dir /remove:d '*S-1-1-0' '*S-1-5-18' '*S-1-5-32-544' 2>&1 | Out-Null; " ^
    "  & icacls.exe $dir /inheritance:e 2>&1 | Out-Null; " ^
    "  & icacls.exe $dir /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' 2>&1 | Out-Null; " ^
    "  if (Test-Path -LiteralPath $dir) { " ^
    "    & takeown.exe /f $dir /a /r /d y 2>&1 | Out-Null; " ^
    "    & icacls.exe $dir /reset /t /c 2>&1 | Out-Null; " ^
    "    $items = @(Get-ChildItem -LiteralPath$dir -Force); " ^
    "    if ($items.Count -eq 0) { Remove-Item -LiteralPath$dir -Force } " ^
    "  } " ^
    "}; " ^
    "Write-Host '    [OK] Program Files write-locks removed and inheritance restored.' -FG Green; " ^
    "" ^
    "Write-Host '  [STAGE 2/6] Restoring System32 & SysWOW64 GameInput binaries...' -FG Cyan; " ^
    "$sysBins = @('C:\Windows\System32\GameInputSvc.exe','C:\Windows\System32\GameInput.dll','C:\Windows\SysWOW64\GameInput.dll'); " ^
    "foreach ($bin in$sysBins) { " ^
    "  $bak =$bin + '.bak'; " ^
    "  if (Test-Path -LiteralPath $bak) { " ^
    "    & takeown.exe /f $bak /a | Out-Null; " ^
    "    & icacls.exe $bak /grant '*S-1-5-32-544:F' | Out-Null; " ^
    "    if (Test-Path -LiteralPath $bin) { " ^
    "      & takeown.exe /f $bin /a | Out-Null; " ^
    "      & icacls.exe $bin /grant '*S-1-5-32-544:F' | Out-Null; " ^
    "      Remove-Item -LiteralPath $bin -Force " ^
    "    }; " ^
    "    Move-Item -LiteralPath $bak -Destination$bin -Force " ^
    "  }; " ^
    "  if (-not (Test-Path -LiteralPath $bin)) { " ^
    "    & sfc.exe /scanfile=$bin 2>&1 | Out-Null " ^
    "  }; " ^
    "  if (Test-Path -LiteralPath $bin) { " ^
    "    & icacls.exe $bin /setowner 'NT SERVICE\TrustedInstaller' 2>&1 | Out-Null; " ^
    "    & icacls.exe $bin /reset 2>&1 | Out-Null " ^
    "  } " ^
    "}; " ^
    "Write-Host '    [OK] System32 & SysWOW64 binaries restored from .bak / WinSxS.' -FG Green; " ^
    "" ^
    "Write-Host '  [STAGE 3/6] Restoring service registry keys & startup states...' -FG Cyan; " ^
    "foreach ($bk in @('GameInputSvc','GamingServices','GamingServicesNet')) { " ^
    "  $bakReg = 'C:\Windows\System32\' +$bk + '_Backup.reg'; " ^
    "  if (Test-Path -LiteralPath $bakReg) { " ^
    "    & reg.exe import $bakReg 2>&1 | Out-Null " ^
    "  } " ^
    "}; " ^
    "if ((-not (Test-Path -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\GameInputSvc')) -and (Test-Path -LiteralPath 'C:\Windows\System32\GameInputSvc.exe')) { " ^
    "  & sc.exe create GameInputSvc binPath= 'C:\Windows\System32\GameInputSvc.exe' type= own start= demand error= normal DisplayName= 'GameInput Service' 2>&1 | Out-Null " ^
    "}; " ^
    "$svcs = @('GameInputSvc','XboxGipSvc','xbgm','GamingServices','GamingServicesNet','XblAuthManager','XblGameSave','XboxNetApiSvc','BcastDVRUserService'); " ^
    "foreach ($s in$svcs) { " ^
    "  Get-Item ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $s + '*') | ForEach-Object { " ^
    "    Set-ItemProperty -LiteralPath $_.PSPath -Name 'Start' -Value 3 -Type DWord -Force; " ^
    "    & reg.exe add ('HKLM\SYSTEM\CurrentControlSet\Services\' + $_.PSChildName) /v Start /t REG_DWORD /d 3 /f 2>&1 | Out-Null " ^
    "  } " ^
    "}; " ^
    "Write-Host '    [OK] Service registry backups imported and set to Manual (Start=3).' -FG Green"

:: STAGES 4 TO 6: GameDVR Policies, Appx/MSI Re-registration, & Service Start
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'SilentlyContinue'; " ^
    "Write-Host '  [STAGE 4/6] Restoring GameDVR policies & Xbox Scheduled Tasks...' -FG Cyan; " ^
    "if (-not (Test-Path 'HKCU:\System\GameConfigStore')) { New-Item -Path 'HKCU:\System\GameConfigStore' -Force | Out-Null }; " ^
    "Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 1 -Type DWord -Force; " ^
    "Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_FSEBehaviorMode' -Value 0 -Type DWord -Force; " ^
    "if (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR') { " ^
    "  Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Force; " ^
    "  $polKey = Get-Item -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; " ^
    "  if ($polKey.ValueCount -eq 0 -and$polKey.SubKeyCount -eq 0) { " ^
    "    Remove-Item -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Force " ^
    "  } " ^
    "}; " ^
    "Get-ScheduledTask -TaskPath '\Microsoft\XblGameSave\*' | ForEach-Object { Enable-ScheduledTask -InputObject $_ | Out-Null }; " ^
    "if ((-not (Get-ScheduledTask -TaskName 'XblGameSaveTask' -ErrorAction SilentlyContinue)) -and (Test-Path -LiteralPath 'C:\Windows\System32\XblGameSaveTask.exe')) { " ^
    "  $act = New-ScheduledTaskAction -Execute 'C:\Windows\System32\XblGameSaveTask.exe' -Argument 'standby'; " ^
    "  $prin = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest; " ^
    "  Register-ScheduledTask -TaskPath '\Microsoft\XblGameSave\' -TaskName 'XblGameSaveTask' -Action $act -Principal$prin -Force | Out-Null " ^
    "}; " ^
    "Write-Host '    [OK] GameDVR policies unlocked and XblGameSave task restored.' -FG Green; " ^
    "" ^
    "Write-Host '  [STAGE 5/6] Re-registering Xbox Appx & GameInput packages...' -FG Cyan; " ^
    "$pkgs = @('*GameInput*','*GamingServices*','*XboxApp*','*XboxGamingOverlay*','*XboxGameOverlay*','*XboxIdentityProvider*','*XboxSpeechToTextOverlay*','*Xbox.TCUI*','*GamingApp*'); " ^
    "$regCount = 0; " ^
    "foreach ($pat in$pkgs) { " ^
    "  Get-ChildItem -Path 'C:\Program Files\WindowsApps' -Filter $pat -Directory -Force | ForEach-Object { " ^