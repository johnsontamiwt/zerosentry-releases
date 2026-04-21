@echo off
REM ============================================================
REM  ZeroMaster Forensics Snapshot
REM  Run AS ADMINISTRATOR when web UI is stuck on 404 (before reboot)
REM  Auto-detects install path from script location.
REM ============================================================

setlocal enabledelayedexpansion

REM --- Self-elevate to admin if not already ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting admin privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM --- Resolve paths ---
set "ZM_DIR=%~dp0.."
pushd "%ZM_DIR%"
set "ZM_DIR=%CD%"
popd
set "OUT_DIR=%ZM_DIR%\forensics"
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

REM --- Timestamp (locale-safe via PowerShell) ---
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set TS=%%i
set "OUT=%OUT_DIR%\snap_%TS%.txt"

echo Writing snapshot to: %OUT%
echo.

echo ============================================================ > "%OUT%"
echo  ZeroMaster Forensics Snapshot >> "%OUT%"
echo  Time: %date% %time% >> "%OUT%"
echo  Install dir: %ZM_DIR% >> "%OUT%"
echo ============================================================ >> "%OUT%"

echo. >> "%OUT%"
echo === [1] Task Scheduler: ZeroMaster === >> "%OUT%"
schtasks /Query /TN "ZeroMaster" /V /FO LIST >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo === [2] All python.exe processes === >> "%OUT%"
tasklist /v /fi "IMAGENAME eq python.exe" >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo === [3] Port 5000 listener (PID + state) === >> "%OUT%"
netstat -ano -p TCP >> "%OUT%.netstat.tmp" 2>&1
findstr ":5000" "%OUT%.netstat.tmp" >> "%OUT%"
echo. >> "%OUT%"
echo --- Port 8090 (device API) --- >> "%OUT%"
findstr ":8090" "%OUT%.netstat.tmp" >> "%OUT%"
echo. >> "%OUT%"
echo --- Port 10005 (device FTP) --- >> "%OUT%"
findstr ":10005" "%OUT%.netstat.tmp" >> "%OUT%"
del "%OUT%.netstat.tmp"

echo. >> "%OUT%"
echo === [4] python.exe memory / handles === >> "%OUT%"
wmic process where "name='python.exe'" get ProcessId,WorkingSetSize,HandleCount,ThreadCount,CommandLine /format:list >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo === [5] Curl localhost 127.0.0.1:5000 === >> "%OUT%"
echo --- GET / --- >> "%OUT%"
curl -v -m 10 http://127.0.0.1:5000/ >> "%OUT%" 2>&1
echo. >> "%OUT%"
echo --- GET /login --- >> "%OUT%"
curl -v -m 10 http://127.0.0.1:5000/login >> "%OUT%" 2>&1
echo. >> "%OUT%"
echo --- GET /dashboard --- >> "%OUT%"
curl -v -m 10 http://127.0.0.1:5000/dashboard >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo === [6] MySQL service === >> "%OUT%"
sc query MySQL80 >> "%OUT%" 2>&1
sc query MySQL >> "%OUT%" 2>&1
sc query MySQL84 >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo === [7] Disk free (C:) === >> "%OUT%"
wmic logicaldisk where "DeviceID='C:'" get Size,FreeSpace,Caption /format:list >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo === [8] app.log size + tail === >> "%OUT%"
if exist "%ZM_DIR%\app.log" (
    dir "%ZM_DIR%\app.log" >> "%OUT%"
    echo. >> "%OUT%"
    echo --- Last 300 lines of app.log --- >> "%OUT%"
    powershell -NoProfile -Command "Get-Content -Path '%ZM_DIR%\app.log' -Tail 300" >> "%OUT%" 2>&1
) else (
    echo app.log NOT FOUND at %ZM_DIR%\app.log >> "%OUT%"
)

echo. >> "%OUT%"
echo === [9] flask.log tail (if exists) === >> "%OUT%"
if exist "%ZM_DIR%\flask.log" (
    dir "%ZM_DIR%\flask.log" >> "%OUT%"
    powershell -NoProfile -Command "Get-Content -Path '%ZM_DIR%\flask.log' -Tail 200" >> "%OUT%" 2>&1
) else (
    echo flask.log not present >> "%OUT%"
)

echo. >> "%OUT%"
echo === [10] TCP summary (CLOSE_WAIT / TIME_WAIT counts) === >> "%OUT%"
powershell -NoProfile -Command "netstat -an | Select-String -Pattern 'CLOSE_WAIT|TIME_WAIT|LISTENING|ESTABLISHED' | Group-Object { ($_ -split '\s+')[-1] } | Select-Object Name,Count | Format-Table -AutoSize | Out-String" >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo === [11] System uptime === >> "%OUT%"
powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime" >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo === [12] ZeroMaster version === >> "%OUT%"
if exist "%ZM_DIR%\app.py" (
    findstr /C:"APP_VERSION" "%ZM_DIR%\app.py" >> "%OUT%" 2>&1
) else (
    dir "%ZM_DIR%\app.*" >> "%OUT%" 2>&1
)

REM --- Export Event Logs (small date window) ---
echo. >> "%OUT%"
echo === [13] Exporting Event Logs to %OUT_DIR% === >> "%OUT%"
wevtutil epl Application "%OUT_DIR%\app_events_%TS%.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 172800000]]]" 2>>"%OUT%"
wevtutil epl System      "%OUT_DIR%\sys_events_%TS%.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 172800000]]]" 2>>"%OUT%"
wevtutil epl "Microsoft-Windows-TaskScheduler/Operational" "%OUT_DIR%\taskscheduler_%TS%.evtx" 2>>"%OUT%"

echo.
echo ============================================================
echo  Snapshot complete.
echo  Text report: %OUT%
echo  Event logs:  %OUT_DIR%\*_%TS%.evtx
echo ============================================================
echo.
echo Zip the whole '%OUT_DIR%' folder and send to developer.
echo.
pause
