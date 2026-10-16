import '../diario/diario_catalogo.dart' show LineaAyuda;

class MensajeSerena {
  final String texto;
  final bool esUsuario;
  final String tipo;
  final List<Map<String, String>> fuentes;
  // Semana 4: líneas de ayuda que se muestran en una tarjeta aparte.
  final List<LineaAyuda> lineas;
  final DateTime hora;

  MensajeSerena({
    required this.texto,
    required this.esUsuario,
    this.tipo = 'normal',
    this.fuentes = const [],
    this.lineas = const [],
    DateTime? hora,
  }) : hora = hora ?? DateTime.now();

  bool get esCrisis => tipo == 'crisis';
  bool get esError => tipo == 'error';
}
