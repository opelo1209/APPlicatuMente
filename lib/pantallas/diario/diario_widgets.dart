// PROTOTIPO (Semana 2): piezas compartidas por las pantallas del diario.
import 'package:flutter/material.dart';

import 'diario_catalogo.dart';

/// Semáforo horizontal: una carcasa oscura con tres luces. La elegida se
/// enciende con un halo de su color; las otras quedan apagadas.
class SemaforoAnimo extends StatelessWidget {
  const SemaforoAnimo({
    super.key,
    required this.seleccion,
    this.onSeleccionar,
    this.tamano = 64,
  });

  final Polaridad? seleccion;
  final ValueChanged<Polaridad>? onSeleccionar;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tamano * 0.28,
        vertical: tamano * 0.22,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF22303A),
        borderRadius: BorderRadius.circular(tamano),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in Polaridad.values)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tamano * 0.12),
              child: _Luz(
                info: kPolaridades[p]!,
                encendida: seleccion == p,
                apagadaDelTodo: seleccion != null && seleccion != p,
                tamano: tamano,
                onTap: onSeleccionar == null ? null : () => onSeleccionar!(p),
              ),
            ),
        ],
      ),
    );
  }
}

class _Luz extends StatelessWidget {
  const _Luz({
    required this.info,
    required this.encendida,
    required this.apagadaDelTodo,
    required this.tamano,
    this.onTap,
  });

  final PolaridadInfo info;
  final bool encendida;
  final bool apagadaDelTodo;
  final double tamano;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = info.color;
    return Semantics(
      button: onTap != null,
      selected: encendida,
      label: 'Día ${info.nombre.toLowerCase()}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: tamano,
              height: tamano,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: apagadaDelTodo ? color.withValues(alpha: 0.22) : color,
                border: Border.all(
                  color: encendida
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.08),
                  width: encendida ? 3 : 1,
                ),
                boxShadow: encendida
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.75),
                          blurRadius: 26,
                          spreadRadius: 4,
                        ),
                      ]
                    : const [],
              ),
              child: Icon(
                info.icono,
                size: tamano * 0.56,
                color: apagadaDelTodo
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.white,
              ),
            ),
            SizedBox(height: tamano * 0.14),
            Text(
              info.nombre,
              style: TextStyle(
                color: encendida || !apagadaDelTodo
                    ? Colors.white
                    : Colors.white54,
                fontWeight: encendida ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta con las líneas de ayuda y un botón para llamar a cada una.
class TarjetaLineasAyuda extends StatelessWidget {
  const TarjetaLineasAyuda({super.key, required this.titulo, this.onLlamar});

  final String titulo;
  final ValueChanged<LineaAyuda>? onLlamar;

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: azul.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: azul),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D3C78),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final linea in kLineasAyuda)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          linea.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${linea.telefono} · ${linea.horario}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: azul),
                    onPressed: onLlamar == null ? null : () => onLlamar!(linea),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Llamar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Invitación a platicar con Serena (aunque el chat siga en desarrollo, el
/// botón ya lleva a su pantalla).
class TarjetaSerena extends StatelessWidget {
  const TarjetaSerena({
    super.key,
    required this.mensaje,
    required this.onAbrir,
  });

  final String mensaje;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    const morado = Color(0xFF6A4FB3);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1ECFB), Color(0xFFE7F4EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: morado,
                child: Icon(Icons.spa_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(mensaje, style: const TextStyle(height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: morado),
              onPressed: onAbrir,
              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
              label: const Text('Platicar con Serena'),
            ),
          ),
        ],
      ),
    );
  }
}

class EtiquetaPrototipo extends StatelessWidget {
  const EtiquetaPrototipo({super.key, required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.science_outlined, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
