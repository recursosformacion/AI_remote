<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $nombre = strip_tags(trim($_POST['nombre']));
    $email = filter_var(trim($_POST['email']), FILTER_SANITIZE_EMAIL);
    $oferta = strip_tags(trim($_POST['oferta']));
    $mensaje = strip_tags(trim($_POST['mensaje']));
    $empresa = isset($_POST['empresa']) ? strip_tags(trim($_POST['empresa'])) : 'No especificada';

    // CONFIGURACIÓN
    $destinatario = "info@gestionproyectos.com"; // Tu correo
    $asunto = "Nueva Oferta de Adquisición: gestionproyectos.com";

    // CUERPO DEL MENSAJE
    $contenido = "Detalles del interesado:\n";
    $contenido .= "----------------------------------\n";
    $contenido .= "Nombre: $nombre\n";
    $contenido .= "Email: $email\n";
    $contenido .= "Empresa/LinkedIn: $empresa\n";
    $contenido .= "Oferta: $oferta\n\n";
    $contenido .= "Mensaje adicional:\n$mensaje\n";
    $contenido .= "----------------------------------\n";
    $contenido .= "Enviado desde el formulario de gestionproyectos.com";

    // CABECERAS PROFESIONALES
    $headers = "From: Webmaster <webmaster@gestionproyectos.com>\r\n";
    $headers .= "Reply-To: $email\r\n";
    $headers .= "X-Mailer: PHP/" . phpversion();

    // ENVÍO
    if (mail($destinatario, $asunto, $contenido, $headers)) {
        header("Location: index.php?success=1");
        exit;
    } else {
        echo "Error al procesar el envío. Por favor, contacte directamente a info@gestionproyectos.com";
    }
} else {
    header("Location: index.php");
    exit;
}
?>