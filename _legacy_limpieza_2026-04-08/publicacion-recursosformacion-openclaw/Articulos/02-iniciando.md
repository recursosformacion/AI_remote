El archivo .env y la jerarquía de APIs (Actualizado 2026)
Una vez estructurados los contenedores, necesitamos configurar el "combustible" que los hace inteligentes. En esta fase, configuraremos el archivo .env y entenderemos por qué hemos elegido este orden de prioridad en los modelos.

1. El archivo .env (Configuración Maestra)
Crea un archivo llamado .env en la raíz de tu proyecto. Este archivo contiene tus credenciales privadas. Importante: Asegúrate de no compartirlo nunca.

Bash
# --- MOTOR PRINCIPAL (Google Gemini) ---
# Usamos Gemini 2.5 por su ventana de contexto superior
AISTUDIO_API_KEY=AIzaxxxxx...

# --- RESPALDO DE ALTA VELOCIDAD (Groq) ---
# Llama 3.3 para respuestas instantáneas
GROQ_API_KEY=gsk_xxxxx...

# --- OTROS PROVEEDORES Y MENSAJERÍA ---
OPENROUTER_API_KEY=sk-or-v1-xxxxx...
XAI_API_KEY=xai-xxxxx...
TELEGRAM_BOT_TOKEN=8337xxxxx...
2. Por qué esta jerarquía (Análisis del JSON)
Según la configuración de nuestro agente (config.json), el sistema no elige el modelo al azar. Sigue una lógica de rendimiento vs. contexto:

A. El líder: Gemini 2.5 Flash
ID en JSON: google/gemini-2.5-flash

Por qué: En 2026, las máquinas 1.5 han quedado obsoletas. La serie 2.5 ofrece una ventana de contexto masiva. Es nuestra "máquina por defecto" porque puede leer documentos largos y recordar historiales de chat extensos sin "alucinar" o perder el hilo.

B. El especialista en velocidad: Groq (Llama 3.3)
ID en JSON: openai/llama-3.3-70b-versatile

El matiz: Aunque Groq es extremadamente rápido, su ventana de contexto es más limitada comparada con Gemini. Por eso, en el JSON lo configuramos como fallback. Si la tarea es corta y rápida, o si Gemini agota su cuota, Groq toma el control.

C. La red de seguridad local: Ollama
ID en JSON: ollama/qwen2.5:0.5b

Función: Es el último recurso. Si no hay internet o las APIs externas fallan, el pequeño modelo Qwen (de solo 0.5b parámetros) responderá desde tu propia CPU. Es ligero y garantiza que el sistema nunca esté totalmente caído.

3. ¿Cómo obtener las llaves en 2026?
Para que tu docker-compose funcione, necesitas darte de alta en estos servicios (todos tienen capas gratuitas):

Google AI Studio: Accede a aistudio.google.com. Allí generas la AISTUDIO_API_KEY. Es fundamental para usar Gemini 2.5.

Groq Cloud: En console.groq.com. Obtendrás la GROQ_API_KEY. Recuerda que aquí usamos el modelo llama-3.3-70b-versatile.

Telegram BotFather: Busca a @BotFather en Telegram para obtener tu TELEGRAM_BOT_TOKEN. Esto activará la capacidad del agente de responderte por chat móvil, como vimos en el JSON (channels.telegram.enabled: true).

4. Gestión de Contexto y Seguridad
En el JSON que manejamos, hay una sección llamada Compaction:

reserveTokensFloor: 6000: Esto le dice a OpenClaw que siempre guarde un margen de maniobra para que la IA no se colapse al llegar al límite de memoria.

trustedProxies: Hemos configurado la red 172.30.0.0/24. Esto significa que el sistema solo aceptará peticiones de "confianza" que vengan de nuestra propia red interna de Docker.

Siguiente paso: Ahora que tenemos las llaves puestas en la cerradura, en la Fase 3 veremos cómo arrancar el motor, inyectar las "skills" (habilidades) y verificar que nuestro bot de Telegram está vivo.