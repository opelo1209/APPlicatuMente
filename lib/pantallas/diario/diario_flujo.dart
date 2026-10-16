// PROTOTIPO (Semana 2): conecta las pantallas del diario con el backend.
//
// Las pantallas (diario_entrada, diario_resultado, diario_historial,
// diario_crisis) solo dibujan; aquí se llama a la API y se navega.
import 'package:flutter/material.dart';

import '../servicios/servicio_prototipo.dart';
import 'diario_catalogo.dart';
import 'diario_crisis.dart';
import 'diario_entrada.dart';
import 'diario_historial.dart';
import 'diario_modelos.dart';
import 'diario_resultado.dart';
import 'diario_widgets.dart';

const _dias = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String fechaLarga(DateTime d) =>
    '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

// BORRADOR: texto final de la psicóloga (revisión clínica, apartado B).
const guionCrisis =
    'Lo que sientes es importante y no tienes que pasarlo sin compañía. '
    'Ahora mismo te pueden escuchar personas preparadas para esto.';

/// Hasta tener url_launcher, «Llamar» muestra el número para marcarlo.
void mostrarNumero(BuildContext context, LineaAyuda linea) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(linea.nombre),
      content: Text(
        'Marca al ${linea.telefono} (${linea.horario}).',
        style: const TextStyle(fontSize: 18, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

class DiarioFlujo extends StatefulWidget {
  const DiarioFlujo({
    super.key,
    required this.onAbrirSerena,
    this.acento = const Color(0xFF43A047),
  });

  /// Cierra el diario y lleva a la pestaña de Serena.
  final VoidCallback onAbrirSerena;
  final Color acento;

  @override
  State<DiarioFlujo> createState() => _DiarioFlujoState();
}

class _DiarioFlujoState extends State<DiarioFlujo> {
  bool _guardando = false;

  void _abrirHistorial() => abrirHistorial(context, widget.onAbrirSerena);

  Future<void> _guardar(EntradaDiarioDatos datos) async {
    setState(() => _guardando = true);
    final respuesta = await ServicioPrototipo.guardarEntrada(
      polaridad: datos.polaridad.name,
      emociones: datos.emociones,
      texto: datos.texto,
    );
    if (!mounted) return;
    setState(() => _guardando = false);

    final json = respuesta.datos;
    if (json == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(respuesta.mensaje ?? 'No se pudo guardar.')),
      );
      return;
    }
    final resultado = ResultadoDiario.fromJson(json);
    final Widget siguiente = resultado.esCrisis
        ? Builder(
            builder: (ctx) => DiarioCrisisPantalla(
              mensajeFijo: guionCrisis,
              onLlamar: (l) => mostrarNumero(ctx, l),
              onVolver: () => Navigator.of(ctx).popUntil((r) => r.isFirst),
            ),
          )
        : Builder(
            builder: (ctx) => DiarioResultadoPantalla(
              resultado: resultado,
              onAbrirSerena: widget.onAbrirSerena,
              onLlamar: (l) => mostrarNumero(ctx, l),
              onVerHistorial: () => abrirHistorial(ctx, widget.onAbrirSerena),
            ),
          );
    await Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => siguiente));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DiarioEntradaPantalla(
          fecha: fechaLarga(DateTime.now()),
          acento: widget.acento,
          onGuardar: _guardando ? (_) {} : _guardar,
          onVerHistorial: _abrirHistorial,
        ),
        if (_guardando) const DiarioGuardando(),
      ],
    );
  }
}

/// Abre «Mi semana» desde cualquier pantalla del diario.
///
/// Semana 4: «Ver mi semana» en la pantalla de resultado no hacía nada. Usaba
/// el `context` del diario, que ya se había cerrado con `pushReplacement`;
/// ahora cada pantalla abre el historial con su propio `context`.
void abrirHistorial(BuildContext context, VoidCallback onAbrirSerena) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => HistorialFlujo(onAbrirSerena: onAbrirSerena),
    ),
  );
}

class HistorialFlujo extends StatefulWidget {
  const HistorialFlujo({super.key, required this.onAbrirSerena});
  final VoidCallback onAbrirSerena;

  @override
  State<HistorialFlujo> createState() => _HistorialFlujoState();
}

class _HistorialFlujoState extends State<HistorialFlujo> {
  static const _letras = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  // Semana 4: 7 o 30 días, para ver la evolución del analizador.
  int _periodo = 7;
  late Future<RespuestaApi> _carga = ServicioPrototipo.listarEntradas(
    dias: _periodo,
  );

  void _cambiarPeriodo(int dias) {
    if (dias == _periodo) return;
    setState(() {
      _periodo = dias;
      _carga = ServicioPrototipo.listarEntradas(dias: dias);
    });
  }

  static String _clave(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DiaHistorial _dia(DateTime d, Map? e, String etiqueta) {
    final emociones = e == null
        ? const []
        : (e['emociones'] as List? ?? const []);
    final analizador = e?['analizador'];
    final a = analizador is Map ? analizador : null;
    return DiaHistorial(
      etiqueta,
      e == null ? null : polaridadDesdeTexto(e['polaridad'] as String),
      emociones.isEmpty ? null : emociones.first as String,
      fecha: d,
      polaridadAnalizador: a?['polaridad'] is String
          ? polaridadDesdeTexto(a!['polaridad'] as String)
          : null,
      confianza: (a?['confianza'] as num?)?.toDouble(),
      emocionAnalizador: a?['emocion'] as String?,
      concordancia: e?['concordancia'] as String?,
    );
  }

  List<DiaHistorial> _dias(List<dynamic> entradas, DateTime hoy) {
    final porFecha = {
      for (final e in entradas.whereType<Map>()) e['fecha'] as String: e,
    };
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    return [
      for (var i = _periodo - 1; i >= 0; i--)
        () {
          final d = base.subtract(Duration(days: i));
          final etiqueta = _periodo <= 7 ? _letras[d.weekday - 1] : '${d.day}';
          return _dia(d, porFecha[_clave(d)], etiqueta);
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicio = hoy.subtract(Duration(days: _periodo - 1));
    return FutureBuilder<RespuestaApi>(
      future: _carga,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || !snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final r = snap.data!;
        if (!r.ok) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mi semana')),
            body: Center(
              child: Text(r.mensaje ?? 'No se pudo cargar tu semana.'),
            ),
          );
        }
        return DiarioHistorialPantalla(
          rango:
              '${inicio.day} de ${_meses[inicio.month - 1]} al ${hoy.day} de ${_meses[hoy.month - 1]}',
          dias: _dias(r.datos!['entradas'] as List, hoy),
          periodo: _periodo,
          onCambiarPeriodo: _cambiarPeriodo,
          onAbrirSerena: widget.onAbrirSerena,
          onLlamar: (l) => mostrarNumero(context, l),
        );
      },
    );
  }
}
