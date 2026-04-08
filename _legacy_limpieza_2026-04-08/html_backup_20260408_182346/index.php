<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Adquisición de Dominio: gestionproyectos.com</title>
    <meta name="description" content="Oportunidad estratégica. Adquiera gestionproyectos.com, el activo digital líder para el sector del Project Management.">
    
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="styles.css">
</head>
<body class="hero-section">

    <nav class="max-w-7xl mx-auto px-8 py-8 flex justify-between items-center">
        <div class="text-2xl font-extrabold tracking-tighter text-slate-900">
            GestionProyectos<span class="text-blue-700">.com</span>
        </div>
        <div class="flex items-center gap-4">
            <div class="h-2 w-2 rounded-full bg-green-500 animate-pulse"></div>
            <span class="text-sm font-bold text-slate-500 uppercase tracking-widest">Disponible para transferencia</span>
        </div>
    </nav>

    <main class="max-w-7xl mx-auto px-8 py-12 grid lg:grid-cols-2 gap-20 items-center">
        
        <section>
            <h1 class="text-5xl md:text-6xl font-extrabold leading-[1.1] mb-8">
                La base de su futura <span class="text-blue-700">autoridad digital.</span>
            </h1>
            <p class="text-xl text-slate-600 mb-12 leading-relaxed">
                Poseer <strong>gestionproyectos.com</strong> no es solo tener una web; es ser el dueño del concepto en el mercado hispanohablante. Una inversión en branding, SEO y confianza.
            </p>

            <div class="space-y-6 mb-12">
                <div class="flex gap-4">
                    <div class="w-12 h-12 shrink-0 bg-blue-50 rounded-lg flex items-center justify-center text-blue-700 font-bold">01</div>
                    <div>
                        <h3 class="font-bold text-lg">Exact Match Domain (EMD)</h3>
                        <p class="text-slate-500 text-sm">Ventaja algorítmica natural en buscadores para la keyword principal del sector.</p>
                    </div>
                </div>
                <div class="flex gap-4">
                    <div class="w-12 h-12 shrink-0 bg-blue-50 rounded-lg flex items-center justify-center text-blue-700 font-bold">02</div>
                    <div>
                        <h3 class="font-bold text-lg">Reducción de Inversión SEM</h3>
                        <p class="text-slate-500 text-sm">Un nombre con alta relevancia aumenta el Quality Score de sus campañas de anuncios.</p>
                    </div>
                </div>
            </div>

            <div class="paypal-shield p-6 flex items-center gap-6">
                <img src="https://upload.wikimedia.org/wikipedia/commons/b/b5/PayPal.svg" alt="PayPal" class="h-5 opacity-70">
                <p class="text-xs text-slate-500 leading-tight">
                    Transacción gestionada con <strong>Protección al Comprador</strong>. 
                    Garantía total de transferencia de titularidad o devolución de fondos.
                </p>
            </div>
        </section>

        <div id="contacto" class="bg-white border border-slate-100 p-10 rounded-[2rem] shadow-xl">
            <h2 class="text-2xl font-bold mb-6">Solicitar información de venta</h2>
            <form id="offerForm" action="enviar.php" method="POST" class="space-y-6">
                <div>
                    <input type="text" id="nombre" name="nombre" placeholder="Nombre completo" class="input-field w-full p-4 rounded-xl">
                    <p id="error-nombre" class="error-text">El nombre es obligatorio.</p>
                </div>
                <div>
                    <input type="email" id="email" name="email" placeholder="Email profesional" class="input-field w-full p-4 rounded-xl">
                    <p id="error-email" class="error-text">Introduzca una dirección de correo válida.</p>
                </div>
                <div>
                    <input type="text" name="oferta" placeholder="Propuesta económica inicial" class="input-field w-full p-4 rounded-xl font-semibold">
                </div>
                <textarea name="mensaje" rows="4" placeholder="¿Representa a alguna empresa o agencia?" class="input-field w-full p-4 rounded-xl"></textarea>
                
                <button type="submit" class="w-full bg-slate-900 hover:bg-blue-700 text-white font-bold py-5 rounded-xl transition-all shadow-lg hover:shadow-blue-200">
                    Iniciar Negociación Segura
                </button>
            </form>
        </div>
    </main>

    <?php if (isset($_GET['success'])): ?>
    <div class="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center z-50">
        <div class="bg-white p-12 rounded-[2rem] max-w-sm w-full mx-4 shadow-2xl text-center">
            <h3 class="text-2xl font-extrabold mb-4">Propuesta Enviada</h3>
            <p class="text-slate-500 mb-8">Gracias por su interés en <strong>gestionproyectos.com</strong>. Nos pondremos en contacto con usted en las próximas 24 horas.</p>
            <button onclick="window.location.href='index'" class="w-full bg-blue-700 text-white font-bold py-4 rounded-xl">Cerrar</button>
        </div>
    </div>
    <?php endif; ?>

    <script>
        const form = document.getElementById('offerForm');
        form.addEventListener('submit', function(e) {
            let valid = true;
            const nombre = document.getElementById('nombre');
            const email = document.getElementById('email');

            // Reset errores
            document.querySelectorAll('.error-text').forEach(el => el.style.display = 'none');
            document.querySelectorAll('.input-field').forEach(el => el.classList.remove('border-red-500'));

            if (nombre.value.trim().length < 2) {
                document.getElementById('error-nombre').style.display = 'block';
                nombre.classList.add('border-red-500');
                valid = false;
            }
            if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value)) {
                document.getElementById('error-email').style.display = 'block';
                email.classList.add('border-red-500');
                valid = false;
            }

            if (!valid) e.preventDefault();
        });
    </script>
</body>
</html>