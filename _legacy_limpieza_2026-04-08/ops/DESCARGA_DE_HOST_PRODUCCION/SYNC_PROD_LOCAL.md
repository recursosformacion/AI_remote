# Sync producción -> local (guía simple: motivo, acción, comando)

Esta guía está hecha para tu caso real:

- Producción es el origen de datos vivos.
- Local es copia de seguridad y análisis.
- Git lo puedes seguir usando para código, pero los datos se sincronizan con `rsync`.

> Si trabajas desde Windows, usa el lanzador `.bat` descrito en [ops/WINDOWS_SYNC_README.md](ops/WINDOWS_SYNC_README.md).

## Ruta más simple (recomendada)

### Primera vez (solo una vez)

```bash
cp /servidor/ops/sync_config.example.sh /servidor/ops/sync_config.sh
```

Edita `sync_config.sh` con tus datos (`REMOTE_HOST`, `REMOTE_USER`, `LOCAL_MIRROR_DIR`, etc.).

### Uso diario (un solo comando)

```bash
bash /servidor/ops/run_sync_safe.sh
```

Ese comando hace todo en orden:

1. Snapshot en producción
2. Simulación (`dry-run`)
3. Te pregunta si aplicar cambios reales
4. Verificación final

### Modo sin preguntas (automático)

```bash
bash /servidor/ops/run_sync_safe.sh auto
```

---

## Ruta manual (si quieres control total)

### 1) Motivo: definir quién es producción y dónde guardas la copia local

**Acción:** crear tu configuración una sola vez.

**Comando:**

```bash
cp /servidor/ops/sync_config.example.sh /servidor/ops/sync_config.sh
```

Luego edita `sync_config.sh` y rellena:

- `REMOTE_HOST` (servidor de producción)
- `REMOTE_USER` (usuario SSH)
- `REMOTE_BASE_DIR` (normalmente `/servidor`)
- `LOCAL_MIRROR_DIR` (ruta local donde guardarás la copia)
- `SSH_OPTS` (si usas puerto/clave especial)

---

### 2) Motivo: tener punto de restauración antes de sincronizar

**Acción:** crear snapshot en producción.

**Comando:**

```bash
bash /servidor/ops/pre_sync_snapshot.sh
```

**Resultado esperado:** archivo en `/servidor/ops/snapshots/`.

---

### 3) Motivo: ver qué va a cambiar sin tocar nada

**Acción:** simulación (`dry-run`).

**Comando:**

```bash
bash /servidor/ops/pull_prod_to_local.sh dry-run
```

**Resultado esperado:** listado de cambios previstos, sin escribir en disco.

---

### 4) Motivo: actualizar tu copia local con seguridad

**Acción:** aplicar sincronización real producción -> local.

**Comando:**

```bash
bash /servidor/ops/pull_prod_to_local.sh apply
```

**Resultado esperado:** espejo local actualizado.

---

### 5) Motivo: comprobar que quedó consistente

**Acción:** verificación final.

**Comando:**

```bash
bash /servidor/ops/verify_sync.sh
```

**Resultado esperado:**

- salida sin diferencias y código `0` = OK
- si marca diferencias, repetir `dry-run` y revisar exclusiones/config

## Comandos de operación diaria (manual)

```bash
# 1) Snapshot
bash /servidor/ops/pre_sync_snapshot.sh

# 2) Simular
bash /servidor/ops/pull_prod_to_local.sh dry-run

# 3) Aplicar
bash /servidor/ops/pull_prod_to_local.sh apply

# 4) Verificar
bash /servidor/ops/verify_sync.sh
```

## Reglas de seguridad (importante)

- No hacer sincronización automática en doble dirección.
- No empujar datos desde local hacia producción con `--delete`.
- Mantener `sync_excludes.txt` para evitar locks, sockets, temporales y caches.
