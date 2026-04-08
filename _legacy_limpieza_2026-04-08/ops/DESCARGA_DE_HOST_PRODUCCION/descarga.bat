@echo off
setlocal

set "SERVER_IP=91.134.255.134"
set "SSH_USER=ocw"
set "REMOTE_APP_PATH=/servidor"
set "TARGET_DIR=D:\Proyectos\remoteIA\web"
set "ARCHIVE=%TARGET_DIR%\remoteIA-src.tgz"

if "%REMOTE_APP_PATH%"=="/servidor" (
	echo [WARN] Usando /servidor como ruta de origen.
	echo [WARN] Se descargara contenido con exclusiones para evitar secretos y datos no necesarios.
)

if exist "%ARCHIVE%" del /f /q "%ARCHIVE%"

echo [1/3] Descargando snapshot por stream desde produccion...
ssh "%SSH_USER%@%SERVER_IP%" "cd '%REMOTE_APP_PATH%' && tar --exclude='.git' --exclude='node_modules' --exclude='vendor' --exclude='.env*' --exclude='letsencrypt' --exclude='data/logs' --exclude='*.pem' --exclude='*.key' --exclude='*.crt' --exclude='*.sqlite*' -czf - ." > "%ARCHIVE%"
if errorlevel 1 (
	echo [ERROR] Fallo la descarga por SSH.
	exit /b 1
)

echo [2/3] Extrayendo en %TARGET_DIR%...
tar -xzf "%ARCHIVE%" -C "%TARGET_DIR%"
if errorlevel 1 (
	echo [ERROR] Fallo la extraccion local.
	exit /b 1
)

echo [3/3] Contenido descargado:
dir "%TARGET_DIR%" /a

echo [OK] Snapshot local listo.
endlocal
