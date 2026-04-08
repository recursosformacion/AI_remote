# DESCARGA_DE_HOST_PRODUCCION

Este directorio es **zona de cuarentena** para cualquier script/archivo descargado desde el host de producción.

## Regla de uso

- Todo fichero traído desde producción debe guardarse aquí.
- No mover archivos desde aquí a `ops/` raíz sin revisión manual.
- Mantener prefijo de fecha/hora en nombre para trazabilidad.

## Convención de nombres

`YYYYMMDD_HHMMSS__HOST__ruta-origen__archivo.ext`

Ejemplo:

`20260304_180500__91.134.255.134__servidor_ops__pre_sync_snapshot.sh`

## Estado

- Carpeta de referencia local para evitar mezclar scripts operativos con descargas del host.

## Procedimientos movidos aquí (descarga desde servidor)

- `descargar_desde_host.ps1` (descarga puntual por ruta remota)
- `descarga.bat` (snapshot por stream)
- `pull_prod_to_local.sh`
- `verify_sync.sh`
- `run_sync_safe.sh`
- `run_sync_from_wsl.sh`
- `run_sync_from_wsl.ps1`
- `run_sync_windows.bat`
- `bootstrap_local_from_prod.sh`

## Compatibilidad

Los scripts antiguos en `ops/` y `descarga.bat` raíz quedaron como **wrappers** con aviso para no romper automatismos.
