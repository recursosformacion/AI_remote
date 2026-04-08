# Runbook: volver al flujo correcto (dev -> prod)

## Objetivo

Rehacer el entorno local desde producción **una sola vez**, y después volver al flujo habitual:

1. Desarrollo y pruebas en local.
2. Versionado con Git.
3. Despliegue controlado a producción.

## Scripts incluidos

- [ops/bootstrap_local_from_prod.sh](ops/bootstrap_local_from_prod.sh)
- [ops/start_local_dev.sh](ops/start_local_dev.sh)
- [ops/deploy_to_prod_safe.sh](ops/deploy_to_prod_safe.sh)
- [ops/deploy_to_prod_safe.ps1](ops/deploy_to_prod_safe.ps1)

## Fase A (una sola vez): clonar producción a desarrollo

Ejecutar en tu máquina local (WSL):

```bash
bash /servidor/ops/bootstrap_local_from_prod.sh 91.134.255.134 ocw dry-run
```

Si la simulación se ve correcta:

```bash
bash /servidor/ops/bootstrap_local_from_prod.sh 91.134.255.134 ocw apply
```

Resultado:

- Copia local reconstruida en `/mnt/d/Proyectos/remoteIA/web`.
- Variables de producción guardadas en `.env.prod.snapshot`.
- `.env.dev` creado si no existía.

## Fase B: preparar entorno de pruebas local

1. Editar `.env.dev` y cambiar credenciales/servicios a sandbox.
2. Verificar que no se envían correos/SMS/webhooks reales.

Arranque local:

```bash
bash /servidor/ops/start_local_dev.sh /mnt/d/Proyectos/remoteIA/web up
```

Comprobar estado:

```bash
bash /servidor/ops/start_local_dev.sh /mnt/d/Proyectos/remoteIA/web ps
```

## Fase C: volver al flujo habitual con Git

Desde tu repo local:

1. Crea rama de trabajo.
2. Commit de cambios.
3. Test local.
4. Merge cuando esté validado.

## Fase D: despliegue seguro a producción

Desde tu repo local limpio y en rama objetivo (PowerShell):

```powershell
./ops/deploy_to_prod_safe.ps1 -RemoteHost 91.134.255.134 -RemoteUser ocw -RemoteAppDir /servidor -Branch main
```

Primero puedes simular:

```powershell
./ops/deploy_to_prod_safe.ps1 -RemoteHost 91.134.255.134 -RemoteUser ocw -RemoteAppDir /servidor -Branch main -DryRun
```

Si necesitas migraciones, define comando:

```powershell
./ops/deploy_to_prod_safe.ps1 -RemoteHost 91.134.255.134 -RemoteUser ocw -RemoteAppDir /servidor -Branch main -MigrationCmd "docker compose exec -T app npm run migrate"
```

Alternativa Bash/WSL equivalente:

```bash
bash /servidor/ops/deploy_to_prod_safe.sh 91.134.255.134 ocw /servidor main
```

## Reglas de oro

- Producción no se usa para desarrollar.
- No hacer sync bidireccional automática.
- Backup/snapshot antes de cada cambio relevante en prod.
- Despliegues a prod solo desde código versionado y validado en local.
