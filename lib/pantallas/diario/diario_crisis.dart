// PROTOTIPO (Semana 2): protocolo de crisis, desde el diario o desde Serena.
//
// Se muestra cuando el motor de decisión demuestra riesgo_alto. No hay
// análisis, ni consejos, ni LLM: un mensaje fijo (lo redacta la psicóloga),
// las líneas de ayuda y el aviso de que se informa a un adulto. Colores
// tranquilos a propósito: no es una alarma para el estudiante.
import 'package:flutter/material.dart';

import 'diario_catalogo.dart';
import 'diario_estilo.dart';
import 'diario_widgets.dart';

class DiarioCrisisPantalla extends StatelessWidget {
  const DiarioCrisisPantalla({
    super.key,
    required this.mensajeFijo,
    this.onLlamar,
    this.onVolver,
  });

  final String mensajeFijo;
  final ValueChanged<LineaAyuda>? onLlamar;
  final VoidCallback? onVolver;

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    final azulNoche = c.crisisTitulo;
    return Scaffold(
      backgroundColor: c.crisisFondo,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: c.crisisCirculo,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  size: 44,
                  color: azulNoche,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Gracias por contármelo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: azulNoche,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              mensajeFijo,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.45, color: c.texto),
            ),
            const SizedBox(height: 22),
            TarjetaLineasAyuda(
              titulo: 'Habla ahora con alguien preparado',
              onLlamar: onLlamar,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.superficie,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.borde),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: azulNoche),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Por tu seguridad, vamos a avisar al equipo de apoyo para que alguien te acompañe. '
                      'Esta conversación se pausó.',
                      style: TextStyle(height: 1.35, color: c.texto),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: azulNoche),
              onPressed: onVolver,
              child: const Text('Volver al inicio'),
            ),
            const SizedBox(height: 8),
            const EtiquetaPrototipo(
              texto:
                  'Prototipo: el mensaje final, a quién se avisa y el seguimiento los define la psicóloga.',
            ),
          ],
        ),
      ),
    );
  }
}
