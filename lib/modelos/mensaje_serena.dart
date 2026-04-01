class MensajeSerena {
  final String texto;
  final bool esUsuario;
  final String tipo;
  final List<Map<String, String>> fuentes;
  final DateTime hora;

  MensajeSerena({
    required this.texto,
    required this.esUsuario,
    this.tipo = 'normal',
    this.fuentes = const [],
    DateTime? hora,
  }) : hora = hora ?? DateTime.now();

  bool get esCrisis => tipo == 'crisis';
  bool get esError => tipo == 'error';
}