// PROTOTIPO (Semana 2): resultado de una entrada del diario.
//
// Muestra lado a lado lo que el estudiante marcó y lo que estima el
// analizador, los consejos del día, la invitación a Serena y, cuando el
// motor de decisión lo pide, las líneas de ayuda. En crisis no se usa esta
// pantalla: se muestra DiarioCrisisPantalla.
import 'package:flutter/material.dart';

import 'diario_catalogo.dart';
import 'diario_estilo.dart';
import 'diario_modelos.dart';
import 'diario_widgets.dart';

class DiarioResultadoPantalla extends StatelessWidget {
  const DiarioResultadoPantalla({
    super.key,
    required this.resultado,
    required this.onAbrirSerena,
    this.onLlamar,
    this.onVerHistorial,
  });

  final ResultadoDiario resultado;
  final VoidCallback onAbrirSerena;
  final ValueChanged<LineaAyuda>? onLlamar;
  final VoidCallback? onVerHistorial;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final c = DiarioColores.de(context);
    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        title: const Text(
          'Tu día',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: c.texto,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (r.accion == 'sugerir_apoyo') ...[
            const _AvisoSuave(
              icono: Icons.favorite_rounded,
              texto:
                  'Llevas varios días difíciles seguidos. No tienes que pasarlo sin compañía.',
            ),
            const SizedBox(height: 14),
          ],
          _Comparacion(resultado: r),
          if (r.mensajeConcordancia.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MensajeConcordancia(
              concordancia: r.concordancia,
              mensaje: r.mensajeConcordancia,
            ),
          ],
          if (r.ofrecerSerena) ...[
            const SizedBox(height: 16),
            TarjetaSerena(mensaje: r.mensajeSerena, onAbrir: onAbrirSerena),
          ],
          if (r.mostrarLineasAyuda) ...[
            const SizedBox(height: 16),
            TarjetaLineasAyuda(
              titulo: 'Si lo necesitas, puedes hablar con alguien ahora',
              onLlamar: onLlamar,
            ),
          ],
          if (r.consejos.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Consejos(consejos: r.consejos, polaridad: r.polaridad),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onVerHistorial,
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('Ver mi semana'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.tinta(Polaridad.positivo),
              side: BorderSide(color: c.tinta(Polaridad.positivo)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const EtiquetaPrototipo(
            texto:
                'Prototipo: consejos y mensajes en borrador, pendientes de revisión clínica.',
          ),
        ],
      ),
    );
  }
}

class _Comparacion extends StatelessWidget {
  const _Comparacion({required this.resultado});
  final ResultadoDiario resultado;

  @override
  Widget build(BuildContext context) {
    final propia = kPolaridades[resultado.polaridad]!;
    final analisis = resultado.analisis;
    final c = DiarioColores.de(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Columna(
                titulo: 'Tú marcaste',
                info: propia,
                detalle: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in resultado.emociones)
                      _Pastilla(texto: e, polaridad: propia.polaridad),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 24, color: c.borde),
            Expanded(
              child: analisis == null
                  ? const _SinAnalisis()
                  // Con poca confianza no se muestra la polaridad del
                  // modelo: no se contradice al estudiante (UMBRAL_CONFIANZA
                  // en evaluador_diario.py).
                  : resultado.concordancia == 'incierto'
                  ? const _AnalisisNoConcluyente()
                  : _Columna(
                      titulo: 'En tu texto notamos',
                      info: kPolaridades[analisis.polaridad]!,
                      confianza: analisis.confianza,
                      detalle: Column(
                        children: [
                          for (final e in analisis.emociones.take(3))
                            _BarraEmocion(
                              emocion: e,
                              color: c.tinta(analisis.polaridad),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Columna extends StatelessWidget {
  const _Columna({
    required this.titulo,
    required this.info,
    required this.detalle,
    this.confianza,
  });
  final String titulo;
  final PolaridadInfo info;
  final Widget detalle;
  final double? confianza;

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: TextStyle(
            fontSize: DiarioTexto.etiqueta,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
            color: c.textoSuave,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: info.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: info.color.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                info.icono,
                color: DiarioColores.sobreLuz(info.polaridad),
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                info.nombre,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: DiarioTexto.titulo,
                  color: c.tinta(info.polaridad),
                ),
              ),
            ),
          ],
        ),
        if (confianza != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'confianza ${(confianza! * 100).round()} %',
              style: TextStyle(
                fontSize: DiarioTexto.etiqueta,
                color: c.textoSuave,
              ),
            ),
          ),
        const SizedBox(height: 10),
        detalle,
      ],
    );
  }
}

class _BarraEmocion extends StatelessWidget {
  const _BarraEmocion({required this.emocion, required this.color});
  final EmocionDetectada emocion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  emocion.nombre,
                  style: TextStyle(
                    fontSize: DiarioTexto.apoyo,
                    fontWeight: FontWeight.w600,
                    color: c.texto,
                  ),
                ),
              ),
              Text(
                '${(emocion.probabilidad * 100).round()} %',
                style: TextStyle(
                  fontSize: DiarioTexto.etiqueta,
                  color: c.textoSuave,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: emocion.probabilidad,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinAnalisis extends StatelessWidget {
  const _SinAnalisis();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Hoy no escribiste texto, así que solo se guardó tu semáforo.',
      style: TextStyle(
        color: DiarioColores.de(context).textoSuave,
        height: 1.35,
      ),
    );
  }
}

class _AnalisisNoConcluyente extends StatelessWidget {
  const _AnalisisNoConcluyente();

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EN TU TEXTO',
          style: TextStyle(
            fontSize: DiarioTexto.etiqueta,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
            color: c.textoSuave,
          ),
        ),
        const SizedBox(height: 8),
        Icon(Icons.help_outline_rounded, color: c.textoSuave, size: 30),
        const SizedBox(height: 6),
        Text(
          'El análisis automático no fue concluyente. Cuenta lo que tú marcaste.',
          style: TextStyle(color: c.textoSuave, height: 1.35),
        ),
      ],
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.texto, required this.polaridad});
  final String texto;
  final Polaridad polaridad;

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kPolaridades[polaridad]!.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: DiarioTexto.etiqueta,
          color: c.tinta(polaridad),
        ),
      ),
    );
  }
}

class _MensajeConcordancia extends StatelessWidget {
  const _MensajeConcordancia({
    required this.concordancia,
    required this.mensaje,
  });
  final String concordancia;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final coincide = concordancia == 'coincide';
    final c = DiarioColores.de(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          coincide
              ? Icons.check_circle_rounded
              : Icons.lightbulb_outline_rounded,
          color: c.tinta(coincide ? Polaridad.positivo : Polaridad.neutro),
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(mensaje, style: TextStyle(height: 1.35, color: c.texto)),
        ),
      ],
    );
  }
}

class _Consejos extends StatelessWidget {
  const _Consejos({required this.consejos, required this.polaridad});
  final List<String> consejos;
  final Polaridad polaridad;

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    final color = c.tinta(polaridad);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ideas para ti',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: DiarioTexto.titulo,
              color: c.texto,
            ),
          ),
          const SizedBox(height: 8),
          for (final consejo in consejos)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_rounded, size: 20, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      consejo,
                      style: TextStyle(height: 1.35, color: c.texto),
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

class _AvisoSuave extends StatelessWidget {
  const _AvisoSuave({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = DiarioColores.de(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.avisoFondo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icono, color: c.tinta(Polaridad.negativo)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: c.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
