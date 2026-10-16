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
    this.periodo = 7,
    this.onCambiarPeriodo,
  });

  final String rango;
  final List<DiaHistorial> dias;
  // Semana 4: 7 o 30 días.
  final int periodo;
  final ValueChanged<int>? onCambiarPeriodo;
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
        title: Text(
          periodo <= 7 ? 'Mi semana' : 'Mi mes',
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
          if (onCambiarPeriodo != null) ...[
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 días')),
                ButtonSegment(value: 30, label: Text('30 días')),
              ],
              selected: {periodo},
              onSelectionChanged: (s) => onCambiarPeriodo!(s.first),
              showSelectedIcon: false,
            ),
          ],
          const SizedBox(height: 12),
          if (periodo <= 7)
            _TiraSemana(dias: dias)
          else
            _Cuadricula(dias: dias),
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
          const SizedBox(height: 18),
          EvolucionAnalizador(dias: dias),
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

/// 30 días en una cuadrícula de luces pequeñas.
class _Cuadricula extends StatelessWidget {
  const _Cuadricula({required this.dias});
  final List<DiaHistorial> dias;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DiarioColores.carcasa,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          for (final d in dias)
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.polaridad == null
                          ? Colors.white.withValues(alpha: 0.08)
                          : kPolaridades[d.polaridad]!.color,
                      border: d.polaridad == null
                          ? Border.all(color: Colors.white24)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    d.etiqueta,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Semana 4 (asesor): la evolución de lo que encontró el analizador de
/// sentimientos en lo que escribió el estudiante, al lado de lo que marcó.
/// El registro del día siempre es lo que marcó el estudiante.
class EvolucionAnalizador extends StatelessWidget {
  const EvolucionAnalizador({super.key, required this.dias});
  final List<DiaHistorial> dias;

  static const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  List<DiaHistorial> get _conTexto =>
      dias.where((d) => d.polaridadAnalizador != null).toList();

  String _resumen(List<DiaHistorial> conTexto) {
    if (conTexto.isEmpty) {
      return 'Cuando escribas algo en tu diario, aquí verás lo que encontró el '
          'analizador en tus palabras.';
    }
    final coinciden = conTexto
        .where((d) => d.concordancia == 'coincide')
        .length;
    final n = conTexto.length;
    final dia = n == 1 ? 'día' : 'días';
    return 'Escribiste $n $dia. En $coinciden, lo que escribiste coincidió con '
        'cómo marcaste tu día.';
  }

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    final conTexto = _conTexto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lo que encontró el analizador',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: DiarioTexto.titulo,
            color: c.texto,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _resumen(conTexto),
          style: TextStyle(color: c.textoSuave, fontSize: DiarioTexto.apoyo),
        ),
        const SizedBox(height: 10),
        for (final d in conTexto.reversed) _fila(d, c),
      ],
    );
  }

  Widget _fila(DiaHistorial d, DiarioColores c) {
    final fecha = d.fecha;
    final cuando = fecha == null
        ? d.etiqueta
        : '${_diasSemana[fecha.weekday - 1]} ${fecha.day}';
    final pct = d.confianza == null
        ? ''
        : ' (${(d.confianza! * 100).round()} %)';
    final emocion = d.emocionAnalizador == null
        ? ''
        : ' · ${kClasesAnalizador[d.emocionAnalizador] ?? d.emocionAnalizador}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borde),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              cuando,
              style: TextStyle(fontWeight: FontWeight.w800, color: c.texto),
            ),
          ),
          _luz(d.polaridad),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_rounded, size: 14, color: c.textoSuave),
          const SizedBox(width: 6),
          _luz(d.polaridadAnalizador),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${kPolaridades[d.polaridadAnalizador]!.nombre}$pct$emocion',
              style: TextStyle(color: c.texto, fontSize: DiarioTexto.apoyo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _luz(Polaridad? p) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: p == null ? Colors.grey : kPolaridades[p]!.color,
    ),
  );
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
