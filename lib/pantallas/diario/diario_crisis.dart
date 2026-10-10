// PROTOTIPO (Semana 2): protocolo de crisis, desde el diario o desde Serena.
//
// Se muestra cuando el motor de decisión demuestra riesgo_alto. No hay
// análisis, ni consejos, ni LLM: un mensaje fijo (lo redacta la psicóloga),
// las líneas de ayuda y el aviso de que se informa a un adulto. Colores
// tranquilos a propósito: no es una alarma para el estudiante.
import 'package:flutter/material.dart';

import 'diario_catalogo.dart';
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
    const azulNoche = Color(0xFF0D3C78);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE9F8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  size: 44,
                  color: azulNoche,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
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
              style: const TextStyle(fontSize: 15.5, height: 1.45),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCE3EA)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: azulNoche),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Por tu seguridad, vamos a avisar al equipo de apoyo para que alguien te acompañe. '
                      'Esta conversación se pausó.',
                      style: TextStyle(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
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
