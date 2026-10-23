// PROTOTIPO Semana 5 (reunión con el asesor): al empezar, el estudiante sabe
// qué ven sus papás. Como en una terapia: no leen lo que escribe, reciben un
// resumen de cómo va (mock_backend/app/resumen_tutor.py). No se le engaña
// con una «mentira blanca», y saberlo da confianza para seguir escribiendo.
//
// BORRADOR: el texto lo aprueban psicología y el asesor. Se muestra una sola
// vez (en el diario o en Serena, lo que abra primero).
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String claveAvisoConfianza = 'avisoConfianzaVisto_v1';

const String tituloAvisoConfianza = 'Así cuidamos lo que escribes';

const List<String> puntosAvisoConfianza = [
  'Lo que escribes en tu diario y en el chat con Serena es tuyo. Tus papás '
      'o tutores no leen tus palabras.',
  'Ellos reciben solo un resumen general de cómo te has sentido, por '
      'ejemplo: «esta semana hubo más días difíciles» o «aparecieron algunas '
      'palabras altisonantes». Nunca se copia lo que escribiste.',
  'Hay una excepción, para cuidarte: si escribes algo que muestre que tu '
      'vida o tu seguridad están en riesgo, el equipo de apoyo de tu escuela '
      'recibe un aviso para poder ayudarte.',
  'La idea es acompañarte, como en una terapia: lo que cuentas solo sirve '
      'para apoyarte mejor.',
];

bool debeMostrarAvisoConfianza(SharedPreferences prefs) =>
    !(prefs.getBool(claveAvisoConfianza) ?? false);

/// Muestra el aviso la primera vez y recuerda que ya se vio.
Future<void> mostrarAvisoConfianzaSiHaceFalta(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (!debeMostrarAvisoConfianza(prefs) || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AvisoConfianzaDialogo(),
  );
  await prefs.setBool(claveAvisoConfianza, true);
}

class AvisoConfianzaDialogo extends StatelessWidget {
  const AvisoConfianzaDialogo({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.lock_outline, color: esquema.primary),
      title: const Text(tituloAvisoConfianza, textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final punto in puntosAvisoConfianza)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Icon(Icons.circle, size: 6, color: esquema.primary),
                    ),
                    Expanded(child: Text(punto)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
