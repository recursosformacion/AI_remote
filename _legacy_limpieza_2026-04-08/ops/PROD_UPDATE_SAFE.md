# Actualización segura a producción (checklist)

## Objetivo

Desplegar cambios de código a producción **sin sobrescribir accidentalmente** configuración sensible de `nginx` y `docker-compose`.

## Script recomendado

### Flujo actual acordado (DEV -> PROD sin Git en despliegue)

Usar este script para subir artefacto directo desde desarrollo, sin bajar nada del servidor y sin usar Git para deploy:

```powershell
./ops/deploy_dev_to_prod_direct.ps1 -RemoteHost 91.134.255.134 -RemoteUser ocw -RemoteAppDir /servidor
```

Opciones utiles:

- `-DryRun`: simulacion completa.
- `-CreateSnapshot`: snapshot remoto (solo si hace falta).
- `-BackupSensitive`: backup de `docker-compose.yml` y `data/nginx` (solo si tocas sensible).
- `-PullExternalImages`: hace `docker compose pull` antes de levantar (por defecto, no hace pull).


### Windows (PowerShell) — recomendado

Usar siempre:

```powershell
./ops/deploy_to_prod_safe.ps1 -RemoteHost 91.134.255.134 -RemoteUser ocw -RemoteAppDir /servidor -Branch main
```

### Linux/WSL (Bash)

Alternativa equivalente:

```bash
bash /servidor/ops/deploy_to_prod_safe.sh <remote_host> [remote_user] [remote_app_dir] [branch]
```

Ejemplo:

```bash
bash /servidor/ops/deploy_to_prod_safe.sh 91.134.255.134 ocw /servidor main
```

## Flujo seguro (orden)

1. Validación de repo local limpio y rama correcta.
2. Detección de cambios sensibles:
   - `docker-compose*.yml`
   - `data/nginx/*`
   - `letsencrypt/*`
3. `git push` de la rama.
4. Snapshot remoto (`pre_sync_snapshot.sh`).
5. Backup remoto adicional de:
   - `docker-compose.yml`
   - `../data/nginx` (tar comprimido)
6. `git pull --ff-only` en producción.
7. Migraciones opcionales (`MIGRATION_CMD`).
8. `docker compose pull && docker compose up -d --remove-orphans`.

## Regla para cambios sensibles

Si hay cambios en `nginx` o `docker-compose`, el script **aborta por defecto**.

Para forzar explícitamente:

```powershell
./ops/deploy_to_prod_safe.ps1 -RemoteHost 91.134.255.134 -RemoteUser ocw -RemoteAppDir /servidor -Branch main -AllowSensitiveChanges
```

## Modo simulación

```powershell
./ops/deploy_to_prod_safe.ps1 -RemoteHost 91.134.255.134 -RemoteUser ocw -RemoteAppDir /servidor -Branch main -DryRun
```

Con migraciones:

```powershell
./ops/deploy_to_prod_safe.ps1 -RemoteHost 91.134.255.134 -RemoteUser ocw -RemoteAppDir /servidor -Branch main -MigrationCmd "docker compose exec -T app npm run migrate"
```

## Nota operativa sobre Nginx Proxy Manager

Si solo hay que publicar cambios de NPM (`database.sqlite`, `data/nginx/custom`, `.htpasswd_openclaw`), usar:

- Linux/WSL: `ops/export_npm_local_to_prod.sh`
- Windows: `ops/export_npm_local_to_prod.ps1`

Así se evita mezclar un deploy de app con un cambio de configuración de NPM.
