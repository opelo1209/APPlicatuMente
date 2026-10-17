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
}
