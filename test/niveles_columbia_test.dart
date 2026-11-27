// Semana 4: niveles de Columbia confirmados por el asesor (16 de octubre).
import 'package:flutter_test/flutter_test.dart';
import 'package:aptm/pantallas/cuestionarios/niveles_columbia.dart';

NivelColumbia nivel(Set<String> si) => nivelColumbia(si.contains);

void main() {
  test('sin respuestas afirmativas no hay riesgo', () {
    expect(nivel({}), NivelColumbia.sinRiesgo);
  });

  test('deseo de morir, ideación o método son seguimiento', () {
    expect(nivel({'desear_muerto'}), NivelColumbia.seguimiento);
    expect(nivel({'idea_suicidarse'}), NivelColumbia.seguimiento);
    expect(nivel({'como_lo_haria'}), NivelColumbia.seguimiento);
  });

  test('intención va a lo comunitario', () {
    expect(
      nivel({'desear_muerto', 'intencion_llevarlo'}),
      NivelColumbia.comunitario,
    );
  });

  test('el plan siempre es urgente', () {
    expect(nivel({'detalles_plan'}), NivelColumbia.urgente);
    expect(
      nivel({
        'desear_muerto',
        'idea_suicidarse',
        'como_lo_haria',
        'intencion_llevarlo',
        'detalles_plan',
      }),
      NivelColumbia.urgente,
    );
  });

  test('el mensaje urgente usa el texto de la doctora', () {
    expect(
      NivelColumbia.urgente.mensajeEstudiante,
      contains('Se ha detectado alto riesgo'),
    );
  });

  // Semana 8 (pregunta 14 de la Dra. González).
  group('respuestas de la Dra. (Semana 8)', () {
    test('PHQ-9 de 10 o más sin Columbia va al centro comunitario', () {
      expect(
        nivelAtencion(NivelColumbia.sinRiesgo, phq9: 10),
        NivelColumbia.comunitario,
      );
      expect(
        nivelAtencion(NivelColumbia.sinRiesgo, phq9: 9),
        NivelColumbia.sinRiesgo,
      );
    });

    test('con ideación y PHQ-9 alto tampoco baja de comunitario', () {
      expect(
        nivelAtencion(NivelColumbia.seguimiento, phq9: 15),
        NivelColumbia.comunitario,
      );
      expect(
        nivelAtencion(NivelColumbia.seguimiento, phq9: 4),
        NivelColumbia.seguimiento,
      );
      expect(
        nivelAtencion(NivelColumbia.urgente, phq9: 20),
        NivelColumbia.urgente,
      );
    });

    test('el nivel comunitario nombra los CECOSAMA', () {
      final texto = NivelColumbia.comunitario.mensajeEstudiante;
      expect(
        texto,
        contains('Centro Comunitario de Salud Mental y Adicciones'),
      );
      expect(texto, contains('CECOSAMA'));
      expect(texto, contains('800 911 2000'));
    });

    test('en seguimiento la escuela está informada', () {
      expect(
        NivelColumbia.seguimiento.mensajeEstudiante,
        contains('tu escuela estará informada'),
      );
    });
  });
}
