# Paquete editorial para recursosformacion.com

Este directorio contiene todo el material preparado para publicar una guía técnica completa de despliegue de OpenClaw desde un VPS vacío.

## Estructura

- `01-ARTICULO-TECNICO-COMPLETO.md`
  - Artículo principal listo para web.
  - Incluye arquitectura, instalación, configuración, validaciones y resolución de incidencias reales.

- `02-RUNBOOK-VERIFICACION.md`
  - Guía operativa paso a paso para verificar que el sistema está sano en producción.

- `03-INCIDENCIAS-REALES-Y-RESOLUCIONES.md`
  - Cronología técnica de incidencias y su resolución (502, configuración inválida, 404 de Gemini).

- `04-GUIA-WORDPRESS-SEO.md`
  - Guía editorial para WordPress: identificador URL, descripción meta, bloques, enlazado y verificación SEO.

- `anexos/docker-compose.yml`
  - Configuración completa del stack docker usado.

- `anexos/openclaw.json`
  - Configuración completa de OpenClaw (modelo primario/cadena de respaldo, latido, compactación, etc.).

- `anexos/nginx-proxy-host-openclaw.conf`
  - Config del host proxy de Nginx Proxy Manager para OpenClaw.

- `plantillas/.env.example`
  - Plantilla de variables de entorno para producción.

## Nota editorial

El artículo está redactado con tono técnico y orientado a reproducibilidad.
Se incluyen comandos y ficheros completos para que cualquier persona pueda replicar el proyecto desde cero.
