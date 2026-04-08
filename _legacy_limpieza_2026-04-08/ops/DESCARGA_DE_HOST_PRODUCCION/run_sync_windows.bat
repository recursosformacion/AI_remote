@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REMOTE_HOST=91.134.255.134"
set "REMOTE_USER=ocw"
set "REMOTE_BASE_DIR=/servidor"
set "WSL_DISTRO=Ubuntu"
set "LOCAL_MIRROR_WIN=D:\Proyectos\remoteIA\web"
set "STRICT_SNAPSHOT=0"

echo ==============================================
echo  Mirror prod -^> local (Windows + WSL)
echo ==============================================
echo Remoto: %REMOTE_USER%@%REMOTE_HOST%:%REMOTE_BASE_DIR%
echo Local : %LOCAL_MIRROR_WIN%
echo.

if "%REMOTE_HOST%"=="" (
  echo [ERROR] REMOTE_HOST esta vacio. Configuralo antes de ejecutar.
  exit /b 1
)

where wsl >nul 2>&1
if errorlevel 1 (
  echo [ERROR] WSL no esta disponible en Windows.
  exit /b 1
)

echo [1/6] Comprobando herramientas en WSL...
wsl -d %WSL_DISTRO% -e bash -lc "command -v ssh >/dev/null && command -v rsync >/dev/null"
if errorlevel 1 (
  echo [ERROR] En WSL faltan paquetes.
  exit /b 1
)

echo [2/6] Convirtiendo ruta Windows a WSL...
for /f "usebackq delims=" %%I in (`wsl -d %WSL_DISTRO% -e bash -lc "wslpath '%LOCAL_MIRROR_WIN:\=/%'"`) do set "LOCAL_MIRROR_WSL=%%I"

echo [3/6] Probando acceso SSH con usuario %REMOTE_USER%...
wsl -d %WSL_DISTRO% -e bash -lc "ssh -o BatchMode=yes %REMOTE_USER%@%REMOTE_HOST% 'echo ok'" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Fallo de autenticacion SSH.
  exit /b 1
)

echo [4/6] Snapshot remoto previo...
wsl -d %WSL_DISTRO% -e bash -lc "ssh %REMOTE_USER%@%REMOTE_HOST% 'bash %REMOTE_BASE_DIR%/ops/pre_sync_snapshot.sh'"
if errorlevel 1 if "%STRICT_SNAPSHOT%"=="1" exit /b 1

echo [5/6] Simulacion (dry-run)...
wsl -d %WSL_DISTRO% -e bash -lc "mkdir -p '%LOCAL_MIRROR_WSL%'"
for %%P in (data html letsencrypt openclaw_home ops) do (
  wsl -d %WSL_DISTRO% -e bash -lc "mkdir -p '%LOCAL_MIRROR_WSL%/%%P' && rsync -rlDz --delete --dry-run --itemize-changes '%REMOTE_USER%@%REMOTE_HOST%:%REMOTE_BASE_DIR%/%%P/' '%LOCAL_MIRROR_WSL%/%%P/'"
)

set /p APPLY=Aplicar sincronizacion real ahora? [s/N]: 
if /I not "%APPLY%"=="s" exit /b 0

echo [6/6] Aplicando sync real...
for %%P in (data html letsencrypt openclaw_home ops) do (
  wsl -d %WSL_DISTRO% -e bash -lc "mkdir -p '%LOCAL_MIRROR_WSL%/%%P' && rsync -rlDz --delete '%REMOTE_USER%@%REMOTE_HOST%:%REMOTE_BASE_DIR%/%%P/' '%LOCAL_MIRROR_WSL%/%%P/'"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\unify_npm_domain_aliases.ps1" -DbPath "%LOCAL_MIRROR_WIN%\data\database.sqlite" -Mode apply -Strategy to-local
echo Finalizado.
exit /b 0
