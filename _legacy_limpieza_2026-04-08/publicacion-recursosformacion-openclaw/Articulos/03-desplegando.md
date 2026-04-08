Instalación, Agentes y Puesta en Marcha Final
Llegamos a la etapa final. Ya entendemos la arquitectura (Fase 1) y tenemos nuestras llaves de IA listas en el archivo .env (Fase 2). Ahora vamos a unir los puntos: instalaremos el sistema, configuraremos el agente inteligente y abriremos las puertas al tráfico seguro.

1. Preparación del Sistema de Archivos
Docker necesita que ciertas carpetas existan con los permisos adecuados antes de arrancar. Desde tu terminal, sitúate en la carpeta del proyecto y ejecuta:

Bash
# Crear estructura de carpetas para persistencia de datos
mkdir -p html ollama_data openclaw_data openclaw_home data letsencrypt openclaw/skills

# Asegurar que el servidor web y el proxy puedan escribir
chmod -R 775 html data
2. Configurando la Inteligencia: El Agente "Main"
Dentro de la carpeta openclaw, debemos tener el archivo config.json que analizamos anteriormente. Este archivo es el que le dice a OpenClaw cómo usar las APIs del .env.

El flujo de decisión (Fallbacks)
Gracias al JSON que configuramos, tu agente operará bajo esta lógica automática:

Intento 1: Consultar a Gemini 2.5 Flash (Gran memoria y precisión).

Intento 2 (Si falla Google): Consultar a Gemini 2.5 Pro.

Intento 3 (Si hay saturación): Usar Llama 3.3 en Groq (Velocidad pura).

Último recurso: Usar Qwen 2.5 en tu propia CPU (Ollama).

3. Despliegue con Docker Compose
Con todo en su sitio (docker-compose.yml, .env, config.json y la carpeta html), lanzamos el comando definitivo:

Bash
docker-compose up -d
¿Qué está pasando ahora mismo?
Ollama empezará a descargar el modelo qwen2.5:7b (o el que hayas definido).

OpenClaw se construirá desde tu código local.

Nginx Proxy Manager levantará el panel de control.

4. Configuración del Proxy (Acceso Exterior)
Tu infraestructura ya funciona internamente, pero el mundo aún no la ve. Para ello usaremos el Gestor de Tráfico:

Entra en tu navegador a http://tu-ip-del-servidor:81.

Los datos por defecto son: admin@example.com / changeme.

Ve a Hosts > Proxy Hosts y añade uno nuevo:

Domain Names: ia.tu-dominio.com

Scheme: http

Forward Hostname: ia_lobechat (el nombre del servicio en el YAML)

Forward Port: 3000

En la pestaña SSL, selecciona "Request a new SSL Certificate" y acepta los términos. ¡Ya tienes HTTPS!

5. El toque maestro: Skills e Interacción
Las "Skills"
Puedes añadir capacidades a tu IA simplemente metiendo archivos .js o .py en ./openclaw/skills. Por ejemplo, una habilidad para leer el clima o consultar tu base de datos PHP. El contenedor los detectará automáticamente gracias al volumen mapeado.

Hablando con tu IA
Vía Web: Entra en el dominio que configuraste en el proxy.

Vía Telegram: Si pusiste el token en el .env, abre Telegram, busca tu bot y escribe /start. Gracias a la configuración dmPolicy: "open", el bot te responderá usando el modelo Gemini 2.5 Flash.

Resumen Final de la Infraestructura
Hemos construido un entorno profesional que separa:

Contenido: Una web en PHP/Apache aislada.

Inteligencia: Un clúster de IA híbrido (Local + Nube).

Seguridad: Una red interna privada (edge_net) y un proxy con SSL.

Este sistema es escalable, privado y utiliza las mejores máquinas disponibles en 2026. ¡Ahora es tu turno de empezar a crear agentes que trabajen por ti!