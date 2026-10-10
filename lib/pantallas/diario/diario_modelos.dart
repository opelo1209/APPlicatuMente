// PROTOTIPO (Semana 2): lo que devuelve el backend al evaluar una entrada
// del diario (mock_backend/app/evaluador_diario.py), ya listo para mostrar.
import 'diario_catalogo.dart';

class EmocionDetectada {
  const EmocionDetectada(this.clase, this.probabilidad);
  final String clase;
  final double probabilidad;

  String get nombre => kClasesAnalizador[clase] ?? clase;
}

class AnalisisIa {
  const AnalisisIa({
    required this.polaridad,
    required this.confianza,
    required this.emociones,
  });

  final Polaridad polaridad;
  final double confianza;
  final List<EmocionDetectada> emociones;

  factory AnalisisIa.fromJson(Map<String, dynamic> json) => AnalisisIa(
    polaridad: polaridadDesdeTexto(json['polaridad'] as String),
    confianza: (json['confianza'] as num).toDouble(),
    emociones: (json['emociones'] as List)
        .map((e) => EmocionDetectada(e[0] as String, (e[1] as num).toDouble()))
        .toList(growable: false),
  );
}

class ResultadoDiario {
  const ResultadoDiario({
    required this.texto,
    required this.polaridad,
    required this.emociones,
    required this.analisis,
    required this.concordancia,
    required this.mensajeConcordancia,
    required this.accion,
    required this.consejos,
    required this.ofrecerSerena,
    required this.mensajeSerena,
    required this.mostrarLineasAyuda,
  });

  final String texto;
  final Polaridad polaridad;
  final List<String> emociones; // nombres para mostrar
  final AnalisisIa? analisis;
  final String concordancia; // coincide | difiere | incierto | sin_analisis
  final String mensajeConcordancia;
  final String
  accion; // normal | sugerir_apoyo | explorar_con_cuidado | protocolo_crisis
  final List<String> consejos;
  final bool ofrecerSerena;
  final String mensajeSerena;
  final bool mostrarLineasAyuda;

  bool get esCrisis => accion == 'protocolo_crisis';

  factory ResultadoDiario.fromJson(Map<String, dynamic> json) {
    final analisis = json['analisis'];
    return ResultadoDiario(
      texto: json['texto'] as String? ?? '',
      polaridad: polaridadDesdeTexto(json['polaridad_registrada'] as String),
      emociones: (json['emociones_registradas'] as List)
          .map((e) => (e as Map)['nombre'] as String)
          .toList(growable: false),
      analisis: analisis == null
          ? null
          : AnalisisIa.fromJson(Map<String, dynamic>.from(analisis as Map)),
      concordancia: json['concordancia'] as String,
      mensajeConcordancia: json['mensaje_concordancia'] as String? ?? '',
      accion: json['accion'] as String,
      consejos: List<String>.from(json['consejos'] as List),
      ofrecerSerena: json['ofrecer_serena'] as bool,
      mensajeSerena: json['mensaje_serena'] as String? ?? '',
      mostrarLineasAyuda: json['mostrar_lineas_ayuda'] as bool,
    );
  }
}

class DiaHistorial {
  const DiaHistorial(this.etiqueta, this.polaridad, this.emocion);
  final String etiqueta; // "L", "M", ...
  final Polaridad? polaridad; // null: no escribió ese día
  final String? emocion;
}
