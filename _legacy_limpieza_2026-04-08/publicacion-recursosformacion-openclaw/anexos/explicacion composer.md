Guía Maestra: Desplegando una Infraestructura de IA y Web con Docker Compose
En este artículo para recursosformacion.com, vamos a analizar paso a paso un archivo docker-compose.yml profesional. No solo veremos qué hace, sino por qué se configura cada línea, ideal si ya conoces Docker pero quieres dar el salto a arquitecturas interconectadas.

1. El Servidor Web (Apache + PHP)
El servicio web es el corazón de nuestro contenido público (como la web de ventas de gestionproyectos.com).

YAML
  web:
    image: php:8.2-apache
    container_name: web_dominio
    restart: always
    command: ["bash", "-lc", "a2enmod rewrite && ... apache2-foreground"]
    ports:
      - "127.0.0.1:8080:80"
    volumes:
      - ./html:/var/www/html
¿Qué está pasando aquí?
image: Usamos una imagen oficial que ya trae Apache y PHP 8.2 configurados.

command: Esta es la "magia" del inicio. Forzamos la activación del módulo rewrite (necesario para URLs bonitas) y configuramos el servidor para que sepa que, aunque él reciba tráfico en el puerto 80, en realidad viene de una conexión segura HTTPS gestionada por el proxy.

ports: Al poner 127.0.0.1:8080:80, hacemos que el puerto 8080 solo sea visible desde dentro del servidor. Nadie desde Internet puede entrar directamente; tienen que pasar obligatoriamente por nuestro "guardián" (Nginx).

volumes: Vinculamos nuestra carpeta local ./html con la del contenedor. Cualquier cambio que hagas en tus archivos .php o .css se reflejará al instante sin reiniciar Docker.

2. El Motor de IA: Ollama
Ollama nos permite ejecutar modelos de lenguaje (como GPT pero privados) en nuestro propio servidor.

YAML
  ollama:
    image: ollama/ollama:latest
    cpus: "2.0"
    ports:
      - "127.0.0.1:11434:11434"
    volumes:
      - ./ollama_data:/root/.ollama
Claves de la configuración:
cpus: "2.0": Crucial. La IA consume muchísimos recursos. Al limitar a 2 núcleos, evitamos que un proceso de IA deje al servidor web sin potencia para atender clientes.

volumes: Los modelos de IA pesan gigabytes. Sin este volumen, cada vez que actualices el contenedor tendrías que descargar los modelos de nuevo.

3. La Interfaz y la Automatización (LobeChat y OpenClaw)
Estos dos servicios son los que "consumen" la IA de Ollama.

LobeChat (ia_interfaz)
Es la cara visual. Se conecta a Ollama mediante variables de entorno:

OLLAMA_PROXY_URL: http://ollama:11434: Fíjate que no usamos una IP, usamos el nombre del servicio ollama. Docker tiene un DNS interno que comunica los contenedores por su nombre.

OpenClaw (openclaw)
Este es un servicio de agentes inteligentes.

build: No usa una imagen de internet, se construye desde tu carpeta local ./openclaw.

Variables ${...}: Aquí usamos "variables de entorno". Los tokens de Telegram o las APIs de Google no se escriben en el archivo (por seguridad), sino que se leen de un archivo oculto .env.

Privilegios: user: "1001:1001" asegura que el contenedor no corra como "root", siguiendo las mejores prácticas de seguridad.

4. El Gestor de Tráfico: Nginx Proxy Manager
Este es el "recepcionista" de todo el sistema.

YAML
  nginx-proxy:
    image: 'jc21/nginx-proxy-manager:latest'
    ports:
      - '80:80'
      - '443:443'
¿Por qué es vital?
Es el único servicio que expone los puertos reales 80 (HTTP) y 443 (HTTPS). Él recibe las visitas de los usuarios y, según el dominio que escriban, decide a qué contenedor enviarlos. Además, se encarga de renovar los certificados SSL (el candado verde) de forma automática.

5. La Red: edge_net
Al final del archivo verás la definición de networks.

YAML
networks:
  edge_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/24
¿Por qué definir una subred manual?
Al fijar el rango 172.30.0.0/24, sabemos exactamente qué IPs internas tendrán nuestros contenedores. Esto es fundamental para configurar cortafuegos o para que servicios como OpenClaw confíen solo en las peticiones que vienen de esa red específica (GATEWAY_TRUSTED_PROXIES).

Resumen de flujo
El usuario entra por HTTPS (Puerto 443).

Nginx Proxy Manager recibe la petición.

Si vas a la web, te manda al servicio web (puerto 8080).

Si vas al chat, te manda a LobeChat, que a su vez habla con Ollama por la red interna.

¿Te gustaría que profundizáramos en cómo crear el archivo .env para que todas estas claves funcionen correctamente? ¡Dínoslo en los comentarios!