# Incidencias reales y resoluciones aplicadas

## Incidencia 1: 502 intermitente en dominio

### Síntoma

- El dominio de OpenClaw alterna entre carga correcta y error 502.

### Evidencia

- Logs del host proxy con `connect() failed (111: Connection refused)` al host de destino `openclaw:18789`.

### Causa raíz

- El contenedor OpenClaw entra en bucle de reinicio por configuración inválida.

### Resolución

- Corregir los campos incompatibles en `openclaw.json`.
- Reiniciar el servicio.
- Verificar que `docker inspect` muestra estado estable y el contador de reinicios no crece.

---

## Incidencia 2: Configuración inválida en comandos nativos

### Síntoma

- Mensaje repetido en logs:

  - `commands.native: Invalid input`
  - `commands.nativeSkills: Invalid input`

### Causa raíz

- Incompatibilidad entre valores de configuración y validador efectivo de la build desplegada.

### Resolución

- Ajuste de `commands.native` y `commands.nativeSkills` a formato aceptado.
- Recarga y comprobación de logs recientes sin nuevos `Config invalid`.

---

## Incidencia 3: Gemini 404 (modelo no encontrado)

### Síntoma

- Error LLM:

  - `models/gemini-1.5-flash is not found for API version v1beta`

### Diagnóstico

- La clave API sí estaba cargada y operativa.
- `ListModels` no devolvía `gemini-1.5-flash` para la cuenta actual.

### Resolución

- Sustitución de IDs por modelos vigentes:
  - `gemini-2.5-flash`
  - `gemini-2.5-pro`
- Prueba real de `generateContent` validada en runtime.

---

## Incidencia 4: Confusión entre errores de cuota y overflow

### Síntoma

- Fallos mostrados como contexto/overflow cuando la causa era límite de proveedor (TPM).

### Resolución

- Ajuste de rutas de respaldo y visibilidad de cambio de proveedor.
- Priorización de modelo principal y respaldo coherente.

---

## Lección operativa final

Siempre diagnosticar por capas:

1. Estado del contenedor (running/restart/exit).
2. Validez de configuración cargada en tiempo de ejecución.
3. Salud del proxy y errores de host de destino.
4. Disponibilidad real de modelos remotos con la clave actual.

Este orden reduce drásticamente el tiempo de resolución y evita cambios a ciegas.
