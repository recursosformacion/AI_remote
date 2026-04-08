# De VPS vacío a plataforma IA en producción con OpenClaw, Docker y HTTPS

Autor: Equipo técnico Recursos Formación  
Tipo de contenido: Guía técnica paso a paso  
Nivel: Intermedio-avanzado

## Ficha editorial (WordPress)

- Identificador URL sugerido: desplegar-openclaw-vps-docker-nginx-https
- Descripción meta: Guía técnica completa para desplegar OpenClaw desde un VPS vacío con Docker, Nginx Proxy Manager, Gemini, Groq y respaldo local con Ollama.
- Extracto: Montamos una plataforma IA real en producción desde cero, resolviendo errores 502, validación de configuración y modelos Gemini no disponibles.
- Categoría sugerida: IA / DevOps
- Etiquetas sugeridas: OpenClaw, Docker, VPS, Nginx Proxy Manager, Gemini, Ollama, DevOps

## Índice

1. Objetivo y alcance
2. Arquitectura de referencia
3. Requisitos de un VPS vacío
4. Estructura del proyecto
5. Configuración técnica de OpenClaw
6. Publicación segura con Nginx Proxy Manager
7. Verificaciones de arranque
8. Incidencias reales y resolución
9. Operación y mantenimiento
10. Conclusiones

## 1) Objetivo y alcance

En este tutorial construimos un entorno IA operativo desde un VPS vacío, orientado a uso real y no a laboratorio. El resultado final incluye:

- Proxy inverso con HTTPS y control de acceso.
- OpenClaw como backend principal.
- Modelo remoto primario (Gemini).
- Cadena de respaldo (Groq y Ollama local).
- Guía operativa técnica para verificar salud y resolver incidencias.

> Nota técnica: El criterio de éxito no es solo “arranca”, sino “permanece estable y es diagnosticable”.

---

## 2) Arquitectura de referencia

La arquitectura utilizada se compone de:

1. Nginx Proxy Manager (entrada por 80/443).
2. OpenClaw (orquestación de agentes/modelos).
3. Ollama (respaldo local).
4. Servicios auxiliares opcionales (por ejemplo, web corporativa).

Flujo:

1. El cliente llega por HTTPS al dominio.
2. El proxy enruta tráfico al contenedor OpenClaw.
3. OpenClaw ejecuta modelo primario.
4. Ante error/cuota, activa la cadena de respaldo.

---

## 3) Requisitos de un VPS vacío

Requisitos mínimos recomendados:

- Linux Ubuntu/Debian reciente.
- 2 vCPU / 4 GB RAM.
- Dominio apuntando al VPS.
- Usuario con permisos sudo.

Base del sistema:

- Docker Engine.
- Docker Compose plugin.
- curl, jq y utilidades de diagnóstico.

Hardening básico:

- Firewall abierto solo para 22, 80 y 443.
- Sin exposición pública de puertos internos de backend.

---

## 4) Estructura del proyecto

Separar configuración y estado persistente evita pérdida de servicio tras reinicios:

- docker-compose.yml
- openclaw_home/
- openclaw_data/
- ollama_data/
- data/ y letsencrypt/

Esta separación permite actualizar imágenes sin perder configuración crítica.

---

## 5) Configuración técnica de OpenClaw

Archivo principal: openclaw_home/openclaw.json

Claves del diseño:

- Proveedor Google con API google-generative-ai.
- Modelos declarados explícitamente en models.providers.google.models.
- Ruta del agente con primario + respaldos reales y disponibles.
- Límites de operación ajustados:
  - contextTokens
  - compaction.reserveTokensFloor
  - heartbeat.every

Cadena validada:

- Primario: google/gemini-2.5-flash
- Respaldo 1: google/gemini-2.5-pro
- Respaldo 2: openai/llama-3.3-70b-versatile
- Respaldo 3: ollama/qwen2.5:0.5b

> Nota técnica: La disponibilidad real del modelo siempre debe verificarse con ListModels para la clave API concreta que ejecuta el contenedor.

---

## 6) Publicación segura con Nginx Proxy Manager

Configuración recomendada del host proxy:

- Host de destino: openclaw
- Puerto de destino: 18789
- Cabeceras Upgrade para WebSocket
- proxy_read_timeout alto
- Certificado TLS con Let’s Encrypt
- Basic Auth opcional para endurecer acceso

Con este esquema, el backend no queda expuesto directamente a Internet.

---

## 7) Verificaciones de arranque

Secuencia mínima de validación:

1. docker compose ps con servicios running.
2. docker inspect de openclaw sin bucle de reinicio.
3. logs sin Config invalid en ventanas recientes.
4. dominio accesible por HTTPS.
5. prueba de generación con modelo primario.

Validación de proveedor:

- Variables GEMINI_API_KEY y GOOGLE_API_KEY presentes en tiempo de ejecución.
- Endpoint v1beta/models devuelve IDs esperados.
- generateContent responde con candidates.

---

## 8) Incidencias reales y resolución

### 8.1 Error 502 intermitente

Síntoma:

- El dominio alternaba entre respuestas correctas y 502.

Diagnóstico:

- Nginx mostraba connection refused al host de destino openclaw:18789.
- Causa raíz: contenedor en reinicio continuo por config inválida.

Resolución:

- Corregir campos incompatibles en openclaw.json.
- Reiniciar servicio.
- Verificar estado running estable y contador de reinicios sin crecimiento.

### 8.2 Configuración inválida por comandos nativos

Síntoma:

- commands.native: Invalid input
- commands.nativeSkills: Invalid input

Resolución aplicada:

- Ajustar ambos campos al formato aceptado por la build en ejecución.
- Confirmar fin del bucle de reinicio.

### 8.3 Error 404 de Gemini (modelo no encontrado)

Síntoma:

- models/gemini-1.5-flash is not found for API version v1beta.

Diagnóstico:

- Clave API válida, pero modelo no disponible para la cuenta/versionado.

Resolución:

- Consultar ListModels desde el contenedor.
- Migrar a gemini-2.5-flash y gemini-2.5-pro.
- Probar generateContent con respuesta real.

---

## 9) Operación y mantenimiento

Buenas prácticas recomendadas:

- Monitorizar contador de reinicios y logs de error del proxy.
- Mantener respaldo local operativo.
- Validar cambios de configuración antes de reiniciar.
- Ejecutar pruebas rápidas tras cada modificación de modelo/proveedor.

Señal de alerta principal:

- Si reaparece 502 intermitente, revisar primero estabilidad del backend antes de tocar el proxy.

---

## 10) Conclusiones

Un despliegue IA en VPS no falla por “Docker”, sino por coherencia entre configuración, disponibilidad real de modelos y disciplina operativa.

Los tres principios que marcaron la diferencia:

1. Validar la configuración contra la build real en ejecución.
2. Verificar modelos contra ListModels de la clave API efectiva.
3. Diagnosticar por capas: contenedor, aplicación, proxy y proveedor.

Con este enfoque, pasar de VPS vacío a producción estable es totalmente replicable.

---

## Anexos para copiar/pegar

- Ver docker-compose completo en: anexos/docker-compose.yml
- Ver openclaw.json completo en: anexos/openclaw.json
- Ver host proxy de NPM en: anexos/nginx-proxy-host-openclaw.conf
- Ver plantilla de entorno en: plantillas/.env.example
