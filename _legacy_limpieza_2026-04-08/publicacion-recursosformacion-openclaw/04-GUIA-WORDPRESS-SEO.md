# Guía de publicación en WordPress (SEO + maquetación)

## 1) Ajustes recomendados de la entrada

- Tipo: Entrada (post)
- Categoría: IA / DevOps
- Etiquetas: OpenClaw, Docker, VPS, Nginx Proxy Manager, Gemini, Ollama, DevOps
- Imagen destacada: diagrama simple de arquitectura (proxy + openclaw + ollama)

## 2) SEO en página (campos sugeridos)

### Título SEO

De VPS vacío a plataforma IA en producción con OpenClaw, Docker y HTTPS

### Identificador URL

desplegar-openclaw-vps-docker-nginx-https

### Descripción meta

Guía técnica completa para desplegar OpenClaw desde un VPS vacío con Docker, Nginx Proxy Manager, Gemini, Groq y respaldo local con Ollama.

### Frase clave objetivo

desplegar OpenClaw en VPS

## 3) Estructura de bloques recomendada

1. Párrafo introductorio (objetivo y alcance).
2. Encabezados H2 por bloque técnico.
3. Bloques de código para comandos y configuración.
4. Bloque de aviso para incidencias críticas (502, Config invalid, model not found).
5. Llamada a la acción final hacia la guía operativa y anexos.

## 4) Enlazado interno recomendado

Añadir enlaces desde el artículo principal hacia:

- 02-RUNBOOK-VERIFICACION.md
- 03-INCIDENCIAS-REALES-Y-RESOLUCIONES.md
- anexos/docker-compose.yml
- anexos/openclaw.json

Si se publican como páginas separadas, enlazar con anchor text descriptivo:

- “guía operativa paso a paso”
- “configuración completa de OpenClaw”
- “resolución de incidencias reales”

## 5) Verificación antes de publicar

- Revisar comandos para que coincidan con rutas reales del servidor.
- Verificar que no se han publicado secretos en capturas o bloques de texto.
- Confirmar que los anexos corresponden al estado validado actual.
- Comprobar legibilidad móvil (bloques de código largos).

## 6) CTA recomendado (cierre del artículo)

Si quieres replicar este despliegue exactamente, utiliza la guía operativa y los anexos completos incluidos en esta guía. Con ellos puedes validar estado, detectar errores de configuración y corregir incidencias de proveedor sin depender de prueba y error.
