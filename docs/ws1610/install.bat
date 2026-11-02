@echo off
setlocal

set "ROUTER=192.168.1.1"
set "USERNAME=root"
set "FIP=%~dp0mt7981_huasifei_ws1610-fip-fixed-parts.bin"
set "SCRIPT=%~dp0install.sh"

if not exist "%FIP%" (
    echo ERROR: FIP file not found:
    echo        %FIP%
    echo Download the release files into the same folder as this .bat.
    pause
    exit /b 1
)

if not exist "%SCRIPT%" (
    echo ERROR: install.sh not found next to this .bat.
    pause
    exit /b 1
)

where ssh >nul 2>&1
if errorlevel 1 (
    echo ERROR: Windows OpenSSH client not found.
    echo Enable "OpenSSH Client" in Settings - Optional Features.
    pause
    exit /b 1
)
where scp >nul 2>&1
if errorlevel 1 (
    echo ERROR: scp not found. Enable the Windows OpenSSH client.
    pause
    exit /b 1
)

set /p "ROUTER=Router IP [192.168.1.1]: "
if "%ROUTER%"=="" set "ROUTER=192.168.1.1"

echo.
echo Uploading installer to %USERNAME%@%ROUTER% ...
scp -o StrictHostKeyChecking=no "%SCRIPT%" %USERNAME%@%ROUTER%:/tmp/install.sh
if errorlevel 1 goto fail

scp -o StrictHostKeyChecking=no "%FIP%" %USERNAME%@%ROUTER%:/tmp/mt7981_huasifei_ws1610-fip-fixed-parts.bin
if errorlevel 1 goto fail

echo.
echo Running installer...
ssh -o StrictHostKeyChecking=no %USERNAME%@%ROUTER% "sh /tmp/install.sh --yes /tmp/mt7981_huasifei_ws1610-fip-fixed-parts.bin"
if errorlevel 1 goto fail

echo.
echo Done. The router is rebooting with the new U-Boot.
pause
exit /b 0

:fail
echo.
echo ERROR: installation failed. The router was not rebooted by this script.
pause
exit /b 1
