Destripando el Código e Instalación Final
Llegamos a la fase definitiva. Ya tenemos la arquitectura clara y las APIs en nuestro .env. Ahora vamos a analizar nuestro docker-compose.yml línea a línea. No es un archivo estándar; está diseñado para ser seguro, rápido y resiliente.

1. Análisis Técnico de Nuestro docker-compose.yml
Vamos a explicar las partes más complejas de los servicios que hemos configurado para que entiendas qué estás instalando.

A. El Servidor Web (web)
command: ["bash", "-lc", "a2enmod rewrite && ..."]

No usamos el arranque por defecto de Apache. Forzamos la carga de a2enmod rewrite para que tus URLs sean amigables.

La parte de SetEnvIf X-Forwarded-Proto es vital: le dice a la web que, aunque reciba tráfico en el puerto 80, venga de donde venga, se comporte como si fuera HTTPS. Esto evita errores de seguridad al navegar.

ports: "127.0.0.1:8080:80"

Seguridad: Al poner 127.0.0.1 delante, el puerto 8080 solo es visible dentro del servidor. Nadie puede saltarse el proxy para entrar a tu web.

B. El Motor de IA (ollama)
cpus: "2.0": Es un límite físico. La IA consume mucha CPU. Con esto, garantizamos que Ollama no "secuestre" todo el servidor y deje a la web sin potencia.

volumes: Mapeamos /etc/localtime en modo :ro (solo lectura). Esto sincroniza el reloj de la IA con el del servidor para que los logs sean coherentes.

C. El Agente Inteligente (openclaw)
Este es el servicio más denso en configuración. Analicemos su environment:

OPENAI_BASE_URL: Verás que apunta a api.groq.com. ¿Por qué? Porque Groq es compatible con el estándar de OpenAI. Le "engañamos" para usar la velocidad de Groq con el código de OpenAI.

Duplicidad de Keys: Verás GEMINI_API_KEY y GOOGLE_API_KEY apuntando al mismo valor. Esto se hace por compatibilidad: diferentes partes del software buscan la misma llave con nombres distintos.

GATEWAY_TRUSTED_PROXIES: Fijado en 172.30.0.0/24. Esto le dice al agente: "Confía solo en peticiones que vengan de mi red interna de Docker".

volumes: El mapeo /:/host_system:ro permite que la IA "vea" tu servidor para darte soporte técnico, pero el :ro (Read Only) impide que pueda borrar o modificar nada. Es una ventana, no una puerta.

D. El Gestor de Tráfico (nginx-proxy)
127.0.0.1:81:81: El panel de control de Nginx solo es accesible desde el propio servidor o vía túnel SSH. Blindamos el acceso administrativo.

production-81-auth.conf: Inyectamos una configuración personalizada para añadir una capa extra de seguridad al login del proxy.

2. Configuración de Red: El porqué de la Subred fija
Al final del archivo verás:

YAML
networks:
  edge_net:
    ipam:
      config:
        - subnet: 172.30.0.0/24
¿Por qué no dejar que Docker elija la IP? Porque en la configuración de openclaw hemos declarado que confiamos en el rango 172.30.0.0/24. Si no fijamos la subred aquí, Docker podría asignar una diferente tras un reinicio y las medidas de seguridad bloquearían la comunicación entre tus propios servicios.

3. Guía de Instalación Paso a Paso
Paso 1: Crear la estructura
Ejecuta estos comandos en tu terminal para preparar el terreno:

Bash
mkdir -p html ollama_data openclaw_data openclaw_home data letsencrypt openclaw/skills
chmod -R 775 html data
Paso 2: El archivo de Agente
Asegúrate de que en ./openclaw/config.json tienes el archivo que analizamos antes, con la jerarquía de Gemini 2.5 Flash como motor principal.

Paso 3: Despliegue
Lanza el comando que construye y levanta todo el ecosistema:

Bash
docker-compose up -d
Paso 4: Activación del Proxy
Entra en http://tu-ip:81 (Panel de Nginx).

Crea un Proxy Host para tu dominio.

Apunta al contenedor ia_lobechat en el puerto 3000 para la interfaz de IA.

Repite para el contenedor web en el puerto 8080 para tu página de ventas.

Solicita el certificado SSL (Let's Encrypt) para ambos.

Conclusión Final
Hemos pasado de un simple archivo de texto a una infraestructura profesional de IA. Gracias a este despliegue:

Tienes una web rápida y segura.

Tienes una IA con "memoria de elefante" (Gemini 2.5) y fallbacks ultra-rápidos (Groq).

Todo corre bajo una red privada donde cada línea del código tiene una razón de ser: rendimiento y seguridad.

¡Ya puedes empezar a programar tus propias skills en la carpeta ./skills y ver cómo tu agente de IA empieza a operar!