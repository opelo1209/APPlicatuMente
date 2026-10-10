// PROTOTIPO (Semana 2): piezas compartidas por las pantallas del diario.
import 'package:flutter/material.dart';

import 'diario_catalogo.dart';
import 'diario_estilo.dart';

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
        color: DiarioColores.carcasa,
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
                    : DiarioColores.sobreLuz(info.polaridad),
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
                fontSize: DiarioTexto.etiqueta,
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
    const azul = DiarioColores.azulAyuda;
    final c = DiarioColores.de(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.ayudaFondo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.ayudaBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_rounded, color: c.ayudaTitulo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: DiarioTexto.cuerpo,
                    color: c.ayudaTitulo,
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: c.texto,
                          ),
                        ),
                        Text(
                          '${linea.telefono} · ${linea.horario}',
                          style: TextStyle(
                            color: c.textoSuave,
                            fontSize: DiarioTexto.apoyo,
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
    const morado = DiarioColores.moradoSerena;
    final c = DiarioColores.de(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: c.serenaFondo,
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
                child: Text(
                  mensaje,
                  style: TextStyle(height: 1.35, color: c.texto),
                ),
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
    final c = DiarioColores.de(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.science_outlined, size: 15, color: c.textoSuave),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: DiarioTexto.etiqueta,
              color: c.textoSuave,
            ),
          ),
        ),
      ],
    );
  }
}

/// Aviso mientras el servidor guarda y analiza la entrada del día.
///
/// Va dentro del Stack del flujo, encima de la pantalla de entrada. Lleva su
/// propio Material: sin él, Flutter dibujaba el texto con el estilo de error
/// (rojo y subrayado en amarillo).
class DiarioGuardando extends StatelessWidget {
  const DiarioGuardando({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    return Positioned.fill(
      child: Material(
        color: c.fondo.withValues(alpha: 0.85),
        child: Center(
          child: Semantics(
            liveRegion: true,
            child: Container(
              width: 300,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              decoration: BoxDecoration(
                color: c.superficie,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.borde),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _MiniSemaforo(),
                  const SizedBox(height: 18),
                  Text(
                    'Guardando tu día',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: DiarioTexto.titulo,
                      fontWeight: FontWeight.w800,
                      color: c.texto,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Estamos guardando lo que marcaste. En un momento verás '
                    'tu análisis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: DiarioTexto.apoyo,
                      height: 1.35,
                      color: c.textoSuave,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      color: c.tinta(Polaridad.positivo),
                      backgroundColor: c.borde,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Las tres luces del semáforo en pequeño, como marca del diario.
class _MiniSemaforo extends StatelessWidget {
  const _MiniSemaforo();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: DiarioColores.carcasa,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in Polaridad.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: kPolaridades[p]!.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
