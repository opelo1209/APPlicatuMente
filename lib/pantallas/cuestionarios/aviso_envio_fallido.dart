import 'package:flutter/material.dart';

/// Lo que el estudiante decide cuando sus respuestas no se pudieron enviar.
enum AccionEnvioFallido {
  /// Volver a intentarlo en ese momento.
  reintentar,

  /// Continuar: las respuestas quedan guardadas y se reenvían solas después.
  continuar,
}

/// Aviso honesto cuando el cuestionario no llegó al servidor.
///
/// Sustituye al comportamiento anterior, que mostraba "Cuestionario
/// completado" aunque el envío hubiera fallado. Se le dice al estudiante lo
/// que realmente pasó, sin alarmarlo y sin culparlo, y se le ofrece
/// reintentar. Sus respuestas no se pierden en ninguno de los dos casos.
Future<AccionEnvioFallido> mostrarAvisoEnvioFallido(
  BuildContext context, {
  required bool esDark,
}) async {
  final accion = await showDialog<AccionEnvioFallido>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: esDark ? const Color(0xFF1E272E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFFF7043),
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            'No pudimos guardar tus respuestas',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: esDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Parece que hay un problema de conexión. Lo que respondiste está '
            'guardado en este dispositivo y lo enviaremos en cuanto haya '
            'internet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: esDark ? Colors.grey[300] : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Si necesitas hablar con alguien ahora, no esperes a que se envíe: '
            'busca a una persona adulta de tu confianza.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: esDark ? Colors.grey[300] : Colors.black87,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(AccionEnvioFallido.continuar),
          child: Text(
            'Continuar',
            style: TextStyle(color: esDark ? Colors.grey[300] : Colors.black54),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(AccionEnvioFallido.reintentar),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF43A047),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          ),
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );

  // Si el diálogo se cierra por cualquier otra vía, se asume continuar: las
  // respuestas ya quedaron en la cola de reenvío.
  return accion ?? AccionEnvioFallido.continuar;
}
