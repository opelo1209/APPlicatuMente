import 'package:flutter_test/flutter_test.dart';
import 'package:aptm/pantallas/cuestionarios/cuestionarios_modulo1.dart';
import 'package:aptm/pantallas/cuestionarios/niveles_columbia.dart';

Map<String, dynamic> _reactivo(String id, int valor) {
  return {'id': id, 'respuesta_valor': valor};
}

void main() {
  group('nivelCssrsPorDominio', () {
    test('sin ninguna respuesta afirmativa devuelve sinRiesgo', () {
      final reactivos = [
        _reactivo('desear_muerto', 0),
        _reactivo('idea_suicidarse', 0),
        _reactivo('como_lo_haria', 0),
        _reactivo('intencion_llevarlo', 0),
        _reactivo('detalles_plan', 0),
      ];

      expect(nivelCssrsPorDominio(reactivos), NivelColumbia.sinRiesgo);
    });

    test(
      'caso reportado: solo "detalles_plan" afirmativo es urgente, no riesgo bajo',
      () {
        final reactivos = [
          _reactivo('desear_muerto', 0),
          _reactivo('idea_suicidarse', 0),
          _reactivo('como_lo_haria', 0),
          _reactivo('intencion_llevarlo', 0),
          _reactivo('detalles_plan', 1),
        ];

        expect(nivelCssrsPorDominio(reactivos), NivelColumbia.urgente);
      },
    );

    test('ideación sola (sin planeación) no escala a riesgo alto', () {
      final reactivos = [
        _reactivo('desear_muerto', 1),
        _reactivo('idea_suicidarse', 1),
        _reactivo('como_lo_haria', 0),
        _reactivo('intencion_llevarlo', 0),
        _reactivo('detalles_plan', 0),
      ];

      expect(nivelCssrsPorDominio(reactivos), NivelColumbia.seguimiento);
    });

    // Semana 4 (asesor, 16 oct): pensar en un método ya no es riesgo alto;
    // queda en seguimiento. La intención va a lo comunitario.
    test('método solo es seguimiento; intención es comunitario', () {
      final soloMetodo = [
        _reactivo('desear_muerto', 0),
        _reactivo('idea_suicidarse', 0),
        _reactivo('como_lo_haria', 1),
        _reactivo('intencion_llevarlo', 0),
        _reactivo('detalles_plan', 0),
      ];

      expect(nivelCssrsPorDominio(soloMetodo), NivelColumbia.seguimiento);

      final intencion = [
        _reactivo('desear_muerto', 1),
        _reactivo('idea_suicidarse', 0),
        _reactivo('como_lo_haria', 0),
        _reactivo('intencion_llevarlo', 1),
        _reactivo('detalles_plan', 0),
      ];
      expect(nivelCssrsPorDominio(intencion), NivelColumbia.comunitario);
    });

    test('el plan domina sobre las demás aunque estén también marcadas', () {
      final reactivos = [
        _reactivo('desear_muerto', 1),
        _reactivo('idea_suicidarse', 1),
        _reactivo('como_lo_haria', 1),
        _reactivo('intencion_llevarlo', 1),
        _reactivo('detalles_plan', 1),
      ];

      expect(nivelCssrsPorDominio(reactivos), NivelColumbia.urgente);
    });
  });
}
