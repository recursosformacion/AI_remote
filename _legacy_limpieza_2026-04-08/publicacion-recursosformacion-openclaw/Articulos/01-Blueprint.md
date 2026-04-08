Cómo montar una infraestructura de IA Local y Web: Análisis del Docker Compose
En el mundo de la formación técnica, solemos ver servicios aislados. Pero, ¿qué pasa cuando queremos que una web de producción conviva con un motor de IA como Ollama y un sistema de agentes como OpenClaw?

Hoy destripamos el archivo de configuración que lo hace posible.

1. El Concepto: Una red privada y segura
Antes de ver el código, entiende el flujo: el tráfico entra por un "embudo" (Nginx) y se reparte internamente. Nada queda expuesto al exterior si no lo decidimos nosotros. Para ello, usamos una red interna llamada edge_net con una subred fija (172.30.0.0/24).

¿Por qué una IP fija? Porque nos permite crear reglas de confianza. Por ejemplo, decirle a la IA: "Solo acepta peticiones si vienen de esta red".

2. Los Servicios: Uno a uno
A. El Frontend (web)
Usamos php:8.2-apache. Lo más crítico aquí es el command. No solo arranca el servidor, sino que inyecta una configuración al vuelo (zz-forwarded-https.conf) para que PHP sepa que estamos bajo un certificado SSL, aunque el contenedor trabaje internamente en HTTP.

B. El Motor de IA (ollama)
Es nuestra IA local.

Recursos: Limitamos a cpus: "2.0" para que una consulta pesada a la IA no tumbe nuestra página web.

Persistencia: Mapeamos ./ollama_data para que los modelos descargados (como Llama 3) no se borren al apagar el contenedor.

C. El Agente Inteligente (openclaw)
A diferencia de los otros, este se construye (build) desde código local. Es el encargado de ejecutar tareas automáticas.

Seguridad: Corre bajo el usuario 1001, evitando privilegios de root.

Acceso al Host: Mapea la raíz del servidor (/:/host_system:ro) en modo lectura. Esto permite que la IA pueda, por ejemplo, analizar logs del sistema para ayudarnos a debugear.

D. El Guardián (nginx-proxy-manager)
Es el encargado de darnos HTTPS gratis con Let's Encrypt. Gestiona el tráfico de los puertos 80 y 443 y lo deriva al servicio correspondiente.

3. Relaciones y Dependencias
Fíjate en la etiqueta depends_on.

ia_interfaz y openclaw dependen de ollama.

¿Por qué? Porque si el motor de IA no está encendido, los agentes y el chat darán error de conexión. Docker se encarga de esperar a que el "cerebro" esté listo antes de arrancar los "músculos".

Próximo paso: Las "llaves" del sistema
Ya tenemos los contenedores, pero ahora necesitan combustible: las APIs y los modelos.

¿Te gustaría que en la siguiente fase te enseñe cómo configurar el archivo .env para tener IA gratuita de respaldo con Groq y Gemini? ¡Suscríbete para no perdértelo!