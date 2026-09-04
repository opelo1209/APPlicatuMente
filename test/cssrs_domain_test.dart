import 'package:flutter_test/flutter_test.dart';
import 'package:aptm/pantallas/cuestionarios/cuestionarios_modulo1.dart';

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

      expect(nivelCssrsPorDominio(reactivos), NivelCssrs.sinRiesgo);
    });

    test(
      'caso reportado: solo "detalles_plan" afirmativo escala a planConcreto, no a riesgo bajo',
      () {
        final reactivos = [
          _reactivo('desear_muerto', 0),
          _reactivo('idea_suicidarse', 0),
          _reactivo('como_lo_haria', 0),
          _reactivo('intencion_llevarlo', 0),
          _reactivo('detalles_plan', 1),
        ];

        expect(nivelCssrsPorDominio(reactivos), NivelCssrs.planConcreto);
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

      expect(nivelCssrsPorDominio(reactivos), NivelCssrs.ideacion);
    });

    test('planeación (método o intención) escala a planeacion', () {
      final soloMetodo = [
        _reactivo('desear_muerto', 0),
        _reactivo('idea_suicidarse', 0),
        _reactivo('como_lo_haria', 1),
        _reactivo('intencion_llevarlo', 0),
        _reactivo('detalles_plan', 0),
      ];

      expect(nivelCssrsPorDominio(soloMetodo), NivelCssrs.planeacion);
    });

    test(
      'plan concreto domina sobre ideación y planeación aunque estén también marcadas',
      () {
        final reactivos = [
          _reactivo('desear_muerto', 1),
          _reactivo('idea_suicidarse', 1),
          _reactivo('como_lo_haria', 1),
          _reactivo('intencion_llevarlo', 1),
          _reactivo('detalles_plan', 1),
        ];

        expect(nivelCssrsPorDominio(reactivos), NivelCssrs.planConcreto);
      },
    );
  });
}
