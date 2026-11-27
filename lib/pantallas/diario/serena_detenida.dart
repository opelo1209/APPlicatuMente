// PROTOTIPO (Semana 2): cómo se vería en el chat de Serena la compuerta de
// riesgo. Cada mensaje del estudiante muestra (solo en el prototipo) la
// polaridad que se le pasa al modelo; cuando el motor de decisión marca
// crisis, la conversación se pausa y el cuadro de texto se deshabilita.
import 'package:flutter/material.dart';

import 'diario_catalogo.dart';
import 'diario_widgets.dart';

class MensajeChat {
  const MensajeChat({
    required this.deEstudiante,
    required this.texto,
    this.polaridad,
    this.emocion,
  });
  final bool deEstudiante;
  final String texto;
  final Polaridad? polaridad;
  final String? emocion;
}

class SerenaDetenidaPantalla extends StatelessWidget {
  const SerenaDetenidaPantalla({
    super.key,
    required this.mensajes,
    required this.detenida,
    required this.mensajeFijo,
    this.onLlamar,
  });

  final List<MensajeChat> mensajes;
  final bool detenida;
  final String mensajeFijo;
  final ValueChanged<LineaAyuda>? onLlamar;

  @override
  Widget build(BuildContext context) {
    const morado = Color(0xFF6A4FB3);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        backgroundColor: morado,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Icon(Icons.spa_rounded, color: Colors.white, size: 18),
            ),
            SizedBox(width: 10),
            Text('Serena', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              children: [
                for (final m in mensajes) _Burbuja(mensaje: m),
                if (detenida) ...[
                  const SizedBox(height: 6),
                  _Pausa(mensajeFijo: mensajeFijo, onLlamar: onLlamar),
                ],
              ],
            ),
          ),
          _CajaTexto(habilitada: !detenida),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje});
  final MensajeChat mensaje;

  @override
  Widget build(BuildContext context) {
    final propio = mensaje.deEstudiante;
    final info = mensaje.polaridad == null
        ? null
        : kPolaridades[mensaje.polaridad]!;
    return Align(
      alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: Column(
          crossAxisAlignment: propio
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: propio ? const Color(0xFF43A047) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(propio ? 18 : 4),
                  bottomRight: Radius.circular(propio ? 4 : 18),
                ),
              ),
              child: Text(
                mensaje.texto,
                style: TextStyle(
                  color: propio ? Colors.white : const Color(0xFF2B2B2B),
                  height: 1.35,
                ),
              ),
            ),
            if (info != null)
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 9, color: info.color),
                    const SizedBox(width: 4),
                    Text(
                      '${info.nombre.toLowerCase()} · ${mensaje.emocion ?? ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pausa extends StatelessWidget {
  const _Pausa({required this.mensajeFijo, this.onLlamar});
  final String mensajeFijo;
  final ValueChanged<LineaAyuda>? onLlamar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFD5EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pause_circle_rounded, color: Color(0xFF0D3C78)),
              SizedBox(width: 8),
              Text(
                'Conversación en pausa',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D3C78),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(mensajeFijo, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          TarjetaLineasAyuda(
            titulo: 'Habla ahora con alguien preparado',
            onLlamar: onLlamar,
          ),
        ],
      ),
    );
  }
}

class _CajaTexto extends StatelessWidget {
  const _CajaTexto({required this.habilitada});
  final bool habilitada;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                enabled: habilitada,
                decoration: InputDecoration(
                  hintText: habilitada
                      ? 'Escribe un mensaje'
                      : 'La conversación está en pausa',
                  filled: true,
                  fillColor: const Color(0xFFF1F1F4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: habilitada ? () {} : null,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
