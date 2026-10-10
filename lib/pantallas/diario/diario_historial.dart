// PROTOTIPO (Semana 2): la semana del estudiante en semáforos.
import 'package:flutter/material.dart';

import 'diario_catalogo.dart';
import 'diario_estilo.dart';
import 'diario_modelos.dart';
import 'diario_widgets.dart';

class DiarioHistorialPantalla extends StatelessWidget {
  const DiarioHistorialPantalla({
    super.key,
    required this.rango,
    required this.dias,
    required this.onAbrirSerena,
    this.onLlamar,
  });

  final String rango;
  final List<DiaHistorial> dias;
  final VoidCallback onAbrirSerena;
  final ValueChanged<LineaAyuda>? onLlamar;

  int _cuenta(Polaridad p) => dias.where((d) => d.polaridad == p).length;

  // Mismo criterio que el backend (R10): hoy y los dos días anteriores.
  bool get _racha {
    final escritos = dias.where((d) => d.polaridad != null).toList();
    if (escritos.length < 3) return false;
    return escritos
        .sublist(escritos.length - 3)
        .every((d) => d.polaridad == Polaridad.negativo);
  }

  Map<String, int> get _emociones {
    final conteo = <String, int>{};
    for (final d in dias) {
      if (d.emocion != null) conteo[d.emocion!] = (conteo[d.emocion!] ?? 0) + 1;
    }
    final orden = conteo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(orden);
  }

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        title: const Text(
          'Mi semana',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: c.texto,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Text(
            rango,
            style: TextStyle(
              color: c.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: DiarioTexto.apoyo,
            ),
          ),
          const SizedBox(height: 12),
          _TiraSemana(dias: dias),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final p in Polaridad.values) ...[
                Expanded(
                  child: _Conteo(info: kPolaridades[p]!, cuenta: _cuenta(p)),
                ),
                if (p != Polaridad.negativo) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Lo que más sentiste',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: DiarioTexto.titulo,
              color: c.texto,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _emociones.entries)
                Chip(
                  label: Text('${e.key} · ${e.value}'),
                  labelStyle: TextStyle(
                    color: c.texto,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: c.superficie,
                  side: BorderSide(color: c.borde),
                ),
            ],
          ),
          if (_racha) ...[
            const SizedBox(height: 18),
            TarjetaSerena(
              mensaje:
                  'Llevas varios días difíciles seguidos. Platicarlo puede ayudar: '
                  'Serena te escucha en privado.',
              onAbrir: onAbrirSerena,
            ),
            const SizedBox(height: 14),
            TarjetaLineasAyuda(
              titulo: 'También puedes llamar a alguien ahora',
              onLlamar: onLlamar,
            ),
          ],
          const SizedBox(height: 16),
          const EtiquetaPrototipo(
            texto:
                'Por defecto solo tú ves tu historial. Qué podría ver tu tutor es decisión pendiente.',
          ),
        ],
      ),
    );
  }
}

class _TiraSemana extends StatelessWidget {
  const _TiraSemana({required this.dias});
  final List<DiaHistorial> dias;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: DiarioColores.carcasa,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final d in dias)
            Column(
              children: [
                Text(
                  d.etiqueta,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: DiarioTexto.etiqueta,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: d.polaridad == null
                        ? Colors.white.withValues(alpha: 0.08)
                        : kPolaridades[d.polaridad]!.color,
                    border: d.polaridad == null
                        ? Border.all(
                            color: Colors.white24,
                            style: BorderStyle.solid,
                          )
                        : null,
                    boxShadow: d.polaridad == null
                        ? null
                        : [
                            BoxShadow(
                              color: kPolaridades[d.polaridad]!.color
                                  .withValues(alpha: 0.6),
                              blurRadius: 10,
                            ),
                          ],
                  ),
                  child: d.polaridad == null
                      ? const Icon(
                          Icons.remove_rounded,
                          color: Colors.white24,
                          size: 16,
                        )
                      : Icon(
                          kPolaridades[d.polaridad]!.icono,
                          color: DiarioColores.sobreLuz(d.polaridad!),
                          size: 18,
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Conteo extends StatelessWidget {
  const _Conteo({required this.info, required this.cuenta});
  final PolaridadInfo info;
  final int cuenta;

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$cuenta',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: c.tinta(info.polaridad),
            ),
          ),
          Text(
            info.nombre,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: DiarioTexto.etiqueta,
              color: c.texto,
            ),
          ),
        ],
      ),
    );
  }
}
