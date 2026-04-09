# Runbook implementacion VPS

Este runbook ejecuta el plan acordado con 2 stacks separados:
- Stack raiz AI_remote: nginx-proxy + web_dominio
- Stack facturas: docker-compose.server.yml dentro de html

## Requisitos

1. Docker Desktop o Docker Engine operativo.
2. En html debe existir .env.server con secretos reales.
3. La red externa de NPM debe existir para facturas (por defecto npm_default).
4. Para sincronizar BD de PROD en `start`, el acceso SSH a `ocw@91.134.255.134` debe funcionar en modo no interactivo (clave SSH).

## Script operativo unico

Archivo: ops/manage_stacks.ps1

### Validar configuraciones

```powershell
.\ops\manage_stacks.ps1 -Action validate
```

### Arrancar todo

```powershell
.\ops\manage_stacks.ps1 -Action start
```

Al final de `start`, el script arranca tambien el tunel cloudflared con:

```powershell
.\ops\cloudflared-windows-amd64.exe tunnel --config 'D:\RF_GIT\.cloudflared\config.yml' run
```

Si ya existe un proceso cloudflared con esa config, no lo duplica.

Al arrancar Facturas, el script intenta sincronizar la BD local con PROD por SSH (contenedor remoto `facturas-db-1`) y luego importa en `html-db-1` local.

La configuracion de esa sincronizacion se define en parametros del propio script (no en `html/.env.server`).

Ejemplo con parametros explicitos:

```powershell
.\ops\manage_stacks.ps1 -Action start -FacturasOnly `
	-SyncProdDbOnStart $true `
	-FailIfProdDbSyncFail $false `
	-ProdSshTarget "ocw@91.134.255.134" `
	-ProdSshPort 22 `
	-ProdDbContainer "facturas-db-1" `
	-ProdDbName "facturas" `
	-ProdDbUser "root" `
	-ProdDbPass "tu_password_prod" `
	-LocalDbContainer "html-db-1" `
	-LocalDbSyncUser "root" `
	-LocalDbSyncPass "tu_password_local" `
	-StartTunnelOnStart $true `
	-CloudflaredExePath "D:\Proyectos\AI_Servidor\web\ops\cloudflared-windows-amd64.exe" `
	-CloudflaredConfigPath "D:\RF_GIT\.cloudflared\config.yml"
```

Si no pasas `-LocalDbSyncPass` o `-ProdDbPass`, el script intenta usar `DB_ROOT_PASSWORD` de `html/.env.server` como fallback.

### Ver estado

```powershell
.\ops\manage_stacks.ps1 -Action status
```

### Ver logs

```powershell
.\ops\manage_stacks.ps1 -Action logs -Tail 200
```

### Parar todo

```powershell
.\ops\manage_stacks.ps1 -Action stop
```

## Operacion por stack

### Solo raiz

```powershell
.\ops\manage_stacks.ps1 -Action status -MainOnly
```

### Solo facturas

```powershell
.\ops\manage_stacks.ps1 -Action status -FacturasOnly
```

## Nota importante

No editar codigo fuente de html desde AI_remote si html se alimenta desde otro aplicativo.
En este repo solo se opera infraestructura y despliegue.

## Scripts de actualizacion separados

### Actualizar PRO

Script:

ops/deploy_prod.ps1

Ejemplo:

```powershell
.\ops\deploy_prod.ps1 `
	-SshUser "ocw" `
	-SshHost "91.134.255.134" `
	-RemotePath "/opt/facturas-prod" `
	-RemoteEnvFile ".env.server"
```

### Actualizar PRUEBAS

Script:

ops/deploy_pre.ps1

Ejemplo (solo codigo):

```powershell
.\ops\deploy_pre.ps1 `
	-SshUser "ocw" `
	-SshHost "91.134.255.134" `
	-RemotePath "/opt/facturas-pre" `
	-RemoteEnvFile ".env.pre.server"
```

Ejemplo (codigo + subir BD local actual a PRUEBAS):

```powershell
.\ops\deploy_pre.ps1 `
	-SshUser "ocw" `
	-SshHost "91.134.255.134" `
	-RemotePath "/opt/facturas-pre" `
	-RemoteEnvFile ".env.pre.server" `
	-ImportLocalDb
```

Notas:

1. La importacion de BD en PRUEBAS usa el contenedor local `html-db-1` por defecto.
2. Si tu contenedor local de BD cambia, usa `-LocalDbContainer`.
3. Los scripts no usan Git para despliegue; suben paquete por SSH/SCP y ejecutan Docker Compose en remoto.

## Flujo oficial de promocion

Circuito principal acordado:

1. Desarrollo funcional en AI_recolectorFacturas.
2. Liberacion a web/html para comprobaciones finales.
3. Subida a PRUEBAS para revision global.
4. Paso a PROD cuando PRUEBAS este validado.

Ruta excepcional permitida:

1. Promocion directa de web/html a PROD cuando se requiera.

Regla operativa:

1. PRUEBAS y PROD deben mantenerse independientes en ejecucion y datos.
2. El origen de verdad para promocion es el contenido liberado en web/html.

Ejemplo recomendado con rutas remotas de usuario (evita problemas de permisos):

```powershell
.\ops\deploy_pre.ps1 -RemotePath "/home/ocw/facturas-pre" -RemoteEnvFile ".env.pre.server"
.\ops\deploy_prod.ps1 -RemotePath "/home/ocw/facturas-prod" -RemoteEnvFile ".env.server"
```
