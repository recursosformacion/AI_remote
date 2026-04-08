# Guía operativa de verificación (formato WordPress)

Uso recomendado en WordPress: publicar esta página como contenido técnico de soporte y mantenerla enlazada desde el artículo principal.

## Bloque 1) Estado de contenedores

Comprobar estado general:

```bash
cd /servidor
docker compose ps
```

Verificar estado detallado de OpenClaw:

```bash
docker inspect openclaw --format '{{.State.Status}} {{.State.Running}} restart={{.RestartCount}} exit={{.State.ExitCode}} started={{.State.StartedAt}}'
```

Resultado esperado:

- running true
- exit=0
- restart estable (sin incrementos continuos)

## Bloque 2) Logs de OpenClaw

```bash
docker logs --since 10m openclaw | tail -n 200
```

Buscar patrones de fallo:

- Config invalid
- not found for API version
- errores de autenticación/cuota

## Bloque 3) Verificación de proxy

```bash
tail -n 100 /servidor/data/logs/proxy-host-4_error.log
```

Si aparece connect() failed (111: Connection refused):

1. Revisar bucle de reinicio de OpenClaw.
2. Validar configuración efectiva dentro del contenedor.
3. Reiniciar solo después de corregir la causa raíz.

## Bloque 4) Variables de entorno en tiempo de ejecución

```bash
docker inspect openclaw --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E 'GEMINI_API_KEY|GOOGLE_API_KEY|GROQ_API_KEY|OPENAI_BASE_URL'
```

## Bloque 5) Modelos Gemini disponibles

```bash
docker exec openclaw sh -lc 'curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY" | head -c 1500'
```

Confirmación requerida:

- El modelo configurado está presente.
- El modelo soporta generateContent.

## Bloque 6) Prueba rápida de generación

```bash
docker exec openclaw sh -lc 'cat >/tmp/gemini-test.json <<"JSON"
{"contents":[{"parts":[{"text":"test corto"}]}]}
JSON
curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY" -H "Content-Type: application/json" --data-binary @/tmp/gemini-test.json | sed -n "1,40p"'
```

Resultado esperado:

- JSON con candidates.
- modelVersion coincide con el modelo probado.

## Bloque 7) Verificación HTTP por dominio

```bash
curl -skI --resolve openclaw.gestionproyectos.com:443:127.0.0.1 https://openclaw.gestionproyectos.com/
```

Con Basic Auth activo:

- 401 es correcto (servicio accesible y protegido).
- 502 indica fallo de upstream.

## Bloque 8) Criterio de salida

### APTO

- OpenClaw estable sin bucle de reinicio.
- Sin Config invalid en logs recientes.
- Dominio sin 502.
- Modelo primario operativo en prueba rápida.

### NO APTO

- Config invalid persistente.
- 502 intermitente con connection refused.
- Modelo ausente en ListModels.

## Nota de operación

Este runbook debe ejecutarse después de cada cambio en:

- openclaw.json
- docker-compose.yml
- configuración de proxy host
- proveedores/modelos LLM
