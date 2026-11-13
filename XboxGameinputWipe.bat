@echo off
title Xbox & GameInput Procedural Purge v2.0 (Final Verified)
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
:: 1. AUTO-ELEVATE TO ADMINISTRATOR
:: ============================================================================
net session >nul 2>&1
if errorlevel 1 (
    echo Requesting Administrator privileges...
    set "PURGE_SELF=%~f0"
    powershell -NoProfile -Command "try { Start-Process -FilePath $env:PURGE_SELF -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1
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
echo            XBOX ^& MICROSOFT GAMEINPUT PROCEDURAL PURGE
echo  ====================================================================
echo   Executing 6-stage permanent removal and directory write-lock...
echo  --------------------------------------------------------------------

:: STAGES 1 TO 4: Processes, Services, MSI Uninstall, and Appx Stripping
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'SilentlyContinue'; " ^
    "Write-Host ''; " ^
    "Write-Host '  [STAGE 1/6] Terminating active GameInput & Xbox processes...' -FG Cyan; " ^
    "$procs = @('GameInputSvc','GameInputHost','GamingServices','GamingServicesNet','GameBar','GameBarFTServer','GameBarPresenceWriter','XboxPcApp','XboxPcAppFT','XboxAppServices'); " ^
    "foreach ($p in $procs) { Get-Process -Name $p | Stop-Process -Force }; " ^
    "Write-Host '    [OK] Active processes terminated.' -FG Green; " ^
    "" ^
    "Write-Host '  [STAGE 2/6] Backing up, stopping & locking background services...' -FG Cyan; " ^
    "foreach ($bk in @('GameInputSvc','GamingServices','GamingServicesNet')) { " ^
    "  $svcReg = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $bk; " ^
    "  $bakReg = 'C:\Windows\System32\' + $bk + '_Backup.reg'; " ^
    "  if ((Test-Path -LiteralPath $svcReg) -and (-not (Test-Path -LiteralPath $bakReg))) { " ^
    "    & reg.exe export ('HKLM\SYSTEM\CurrentControlSet\Services\' + $bk) $bakReg /y | Out-Null " ^
    "  } " ^
    "}; " ^
    "$svcs = @('GameInputSvc','XboxGipSvc','xbgm','GamingServices','GamingServicesNet','XblAuthManager','XblGameSave','XboxNetApiSvc','BcastDVRUserService'); " ^
    "foreach ($s in $svcs) { " ^
    "  Get-Service -Name ($s + '*') | Stop-Service -Force; " ^
    "  Get-Item ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $s + '*') | ForEach-Object { " ^
    "    Set-ItemProperty -LiteralPath $_.PSPath -Name 'Start' -Value 4 -Type DWord -Force; " ^
    "    & reg.exe add ('HKLM\SYSTEM\CurrentControlSet\Services\' + $_.PSChildName) /v Start /t REG_DWORD /d 4 /f 2>&1 | Out-Null " ^
    "  } " ^
    "}; " ^
    "foreach ($k in @('GameInputSvc','GamingServices','GamingServicesNet')) { " ^
    "  & sc.exe stop $k | Out-Null; " ^
    "  & sc.exe delete $k | Out-Null; " ^
    "  $rp = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $k; " ^
    "  if (Test-Path -LiteralPath $rp) { Remove-Item -LiteralPath $rp -Recurse -Force } " ^
    "}; " ^
    "Write-Host '    [OK] Services stopped, disabled (Start=4), and service keys purged.' -FG Green; " ^
    "" ^
    "Write-Host '  [STAGE 3/6] Uninstalling GameInput MSI redistributables...' -FG Cyan; " ^
    "$uPaths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'); " ^
    "$msiCount = 0; " ^
    "Get-ItemProperty $uPaths | Where-Object { $_.DisplayName -like '*GameInput*' } | ForEach-Object { " ^
    "  $guid = $_.PSChildName; " ^
    "  if ($guid -match '^\{[0-9A-Fa-f\-]+\}$') { " ^
    "    $p = Start-Process 'msiexec.exe' -ArgumentList ('/x ' + $guid + ' /qn /norestart') -Wait -NoNewWindow -PassThru; " ^
    "    if ($p -and ($p.ExitCode -eq 0 -or $p.ExitCode -eq 1605 -or $p.ExitCode -eq 3010)) { $msiCount++ } " ^
    "  } " ^
    "}; " ^
    "Write-Host ('    [OK] Uninstalled ' + $msiCount + ' MSI redistributable package(s).') -FG Green; " ^
    "" ^
    "Write-Host '  [STAGE 4/6] Stripping Appx & Provisioned Xbox/GameInput packages...' -FG Cyan; " ^
    "$pkgs = @('*GameInput*','*GamingServices*','*XboxApp*','*XboxGamingOverlay*','*XboxGameOverlay*','*XboxIdentityProvider*','*XboxSpeechToTextOverlay*','*Xbox.TCUI*','*GamingApp*'); " ^
    "$appxCount = 0; " ^
    "$provPkgs = @(Get-AppxProvisionedPackage -Online); " ^
    "foreach ($pat in $pkgs) { " ^
    "  Get-AppxPackage -AllUsers $pat | ForEach-Object { " ^
    "    if ($_.Name -ne 'Microsoft.XboxGameCallableUI') { " ^
    "      Remove-AppxPackage -Package $_.PackageFullName -AllUsers; " ^
    "      if ($?) { $appxCount++ } " ^
    "    } " ^
    "  }; " ^
    "  $provPkgs | Where-Object { $_.DisplayName -like $pat -and $_.DisplayName -ne 'Microsoft.XboxGameCallableUI' } | ForEach-Object { " ^
    "    Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null " ^
    "  } " ^
    "}; " ^
    "Write-Host ('    [OK] Stripped ' + $appxCount + ' active/provisioned Appx package(s).') -FG Green"

:: STAGES 5 & 6: Scheduled Tasks, GameDVR Hooks, System32 Neutralization & ACL Lock
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'SilentlyContinue'; " ^
    "Write-Host '  [STAGE 5/6] Removing Xbox Scheduled Tasks & GameDVR capture hooks...' -FG Cyan; " ^
    "Get-ScheduledTask -TaskPath '\Microsoft\XblGameSave\*' | ForEach-Object { " ^
    "  Disable-ScheduledTask -InputObject $_ | Out-Null; " ^
    "  Unregister-ScheduledTask -InputObject $_ -Confirm:$false " ^
    "}; " ^
    "if (-not (Test-Path 'HKCU:\System\GameConfigStore')) { New-Item -Path 'HKCU:\System\GameConfigStore' -Force | Out-Null }; " ^
    "Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Type DWord -Force; " ^
    "Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_FSEBehaviorMode' -Value 2 -Type DWord -Force; " ^
    "if (-not (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR')) { New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Force | Out-Null }; " ^
    "Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0 -Type DWord -Force; " ^
    "Write-Host '    [OK] Scheduled tasks deleted and GameDVR capture policy disabled.' -FG Green; " ^
    "" ^
    "Write-Host '  [STAGE 6/6] Neutralizing System32 binaries & locking folders...' -FG Cyan; " ^
    "$sysBins = @('C:\Windows\System32\GameInputSvc.exe','C:\Windows\System32\GameInput.dll','C:\Windows\SysWOW64\GameInput.dll'); " ^
    "foreach ($bin in $sysBins) { " ^
    "  if (Test-Path -LiteralPath $bin) { " ^
    "    & takeown.exe /f $bin /a | Out-Null; " ^
    "    & icacls.exe $bin /grant '*S-1-5-32-544:F' | Out-Null; " ^
    "    $bakFile = $bin + '.bak'; " ^
    "    if (-not (Test-Path -LiteralPath $bakFile)) { " ^
    "      Rename-Item -LiteralPath $bin -NewName (($bin | Split-Path -Leaf) + '.bak') -Force " ^
    "    } else { " ^
    "      Remove-Item -LiteralPath $bin -Force " ^
    "    } " ^
    "  } " ^
    "}; " ^
    "$lockDirs = @('C:\Program Files (x86)\Microsoft GameInput','C:\Program Files\Microsoft GameInput'); " ^
    "foreach ($dir in $lockDirs) { " ^
    "  & takeown.exe /f $dir /a 2>&1 | Out-Null; " ^
    "  & icacls.exe $dir /remove:d '*S-1-1-0' '*S-1-5-18' '*S-1-5-32-544' 2>&1 | Out-Null; " ^
    "  & icacls.exe $dir /grant:r '*S-1-5-32-544:(OI)(CI)F' 2>&1 | Out-Null; " ^
    "  if (Test-Path -LiteralPath $dir) { " ^
    "    & takeown.exe /f $dir /a /r /d y | Out-Null; " ^
    "    & icacls.exe $dir /reset /t /c | Out-Null; " ^
    "    Remove-Item -LiteralPath $dir -Recurse -Force " ^
    "  }; " ^
    "  New-Item -ItemType Directory -Path $dir -Force | Out-Null; " ^
    "  if (Test-Path -LiteralPath $dir) { " ^
    "    & icacls.exe $dir /inheritance:r | Out-Null; " ^
    "    & icacls.exe $dir /deny '*S-1-1-0:(OI)(CI)(F)' '*S-1-5-18:(OI)(CI)(F)' '*S-1-5-32-544:(OI)(CI)(F)' | Out-Null " ^
    "  } " ^
    "}; " ^
    "Write-Host '    [OK] System32 binaries renamed to .bak and Program Files folders write-locked.' -FG Green; " ^
    "" ^
    "Write-Host ''; " ^
    "Write-Host '  --------------------------------------------------------------------'; " ^
    "Write-Host '  POST-EXECUTION VERIFICATION REPORT:' -FG Yellow; " ^
    "$remSvc = Get-Service -Name 'GameInputSvc','GamingServices' | Where-Object { $_.Status -eq 'Running' }; " ^
    "$sysExe = Test-Path -LiteralPath 'C:\Windows\System32\GameInputSvc.exe'; " ^
    "Write-Host ('    * Active GameInput/GamingServices : ' + $(if ($remSvc) { 'RUNNING (Check reboot)' } else { 'NONE (Verified Clean)' })) -FG $(if ($remSvc) {'Red'} else {'Green'}); " ^
    "Write-Host ('    * System32\GameInputSvc.exe       : ' + $(if ($sysExe) { 'STILL PRESENT' } else { 'NEUTRALIZED (.bak)' })) -FG $(if ($sysExe) {'Red'} else {'Green'}); " ^
    "$locked = $true; " ^
    "foreach ($d in $lockDirs) { " ^
    "  $testWrite = Join-Path $d 'test.tmp'; " ^
    "  try { [IO.File]::WriteAllText($testWrite, 'x'); Remove-Item $testWrite -Force; $locked = $false } " ^
    "  catch [System.UnauthorizedAccessException] { } " ^
    "  catch { $locked = $false } " ^
    "}; " ^
    "Write-Host ('    * Program Files Write-Block       : ' + $(if ($locked) { 'LOCKED (Access Denied Verified)' } else { 'UNLOCKED' })) -FG $(if ($locked) {'Green'} else {'Red'})"

echo  ====================================================================
echo   Reboot your PC once to unload any remaining kernel driver handles.
echo  ====================================================================
echo.
pause
exit /b 0