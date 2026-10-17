// Semana 4 (asesor, 16 de octubre): niveles de atención del cuestionario de
// Columbia (C-SSRS) con los resultados de la Dra. González (n = 1 389):
//
//   urgente      plan suicida (detalles_plan, 4 %): evaluación urgente con un
//                especialista; en el piloto, el Hospital Infantil de México.
//   comunitario  intención sin plan (intencion_llevarlo, 8,9 %): recurso
//                comunitario. Los porcentajes son independientes.
//   seguimiento  deseo de morir, ideación o método: seguimiento en la app y en
//                la escuela.
//
// Antes, pensar en un método ya era «riesgo alto». El backend decide lo mismo
// en mock_backend/app/niveles_columbia.py. Textos: BORRADORES.
import 'package:flutter/material.dart';

enum NivelColumbia { sinRiesgo, seguimiento, comunitario, urgente }

/// El nivel lo decide la pregunta más grave contestada con «sí», no cuántas.
NivelColumbia nivelColumbia(bool Function(String id) endosado) {
  if (endosado('detalles_plan')) return NivelColumbia.urgente;
  if (endosado('intencion_llevarlo')) return NivelColumbia.comunitario;
  if (endosado('desear_muerto') ||
      endosado('idea_suicidarse') ||
      endosado('como_lo_haria')) {
    return NivelColumbia.seguimiento;
  }
  return NivelColumbia.sinRiesgo;
}

extension NivelColumbiaUi on NivelColumbia {
  String get etiqueta => switch (this) {
    NivelColumbia.sinRiesgo => 'Sin indicadores',
    NivelColumbia.seguimiento => 'Seguimiento',
    NivelColumbia.comunitario => 'Atención comunitaria',
    NivelColumbia.urgente => 'Atención urgente',
  };

  Color get color => switch (this) {
    NivelColumbia.sinRiesgo => const Color(0xFF43A047),
    NivelColumbia.seguimiento => const Color(0xFFF9A825),
    NivelColumbia.comunitario => const Color(0xFFEF6C00),
    NivelColumbia.urgente => const Color(0xFFE53935),
  };

  /// Lo que lee el estudiante al terminar. BORRADOR para psicología.
  String get mensajeEstudiante => switch (this) {
    NivelColumbia.sinRiesgo =>
      'Gracias por contestar. No identificamos señales de riesgo.',
    NivelColumbia.seguimiento =>
      'Gracias por contestar con sinceridad. Seguiremos acompañándote en la '
          'app, y orientación de tu escuela también está para apoyarte.',
    NivelColumbia.comunitario =>
      'Lo que contestaste nos importa. Te recomendamos platicar pronto con '
          'alguien de un centro comunitario de salud mental; tu escuela y tu '
          'tutor te pueden ayudar a encontrarlo. Si lo necesitas ahora, llama '
          'a la Línea de la Vida: 800 911 2000 (24 horas, gratuita).',
    NivelColumbia.urgente =>
      'Se ha detectado alto riesgo. Por favor, contacta a un especialista '
          'para una evaluación más detallada; vamos a avisar a tu tutor para '
          'que te acompañe. Si estás en peligro ahora, llama al 911 o a la '
          'Línea de la Vida: 800 911 2000.',
  };
}
