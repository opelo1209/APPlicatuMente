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

  void _abrirHistorial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistorialFlujo(onAbrirSerena: widget.onAbrirSerena),
      ),
    );
  }

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
              onVerHistorial: _abrirHistorial,
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
        if (_guardando)
          const ColoredBox(
            color: Color(0x88FFFFFF),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Analizando tu día...',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class HistorialFlujo extends StatelessWidget {
  const HistorialFlujo({super.key, required this.onAbrirSerena});
  final VoidCallback onAbrirSerena;

  static const _letras = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  List<DiaHistorial> _semana(List<dynamic> entradas, DateTime hoy) {
    final porFecha = {
      for (final e in entradas.whereType<Map>()) e['fecha'] as String: e,
    };
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final d = DateTime(
            hoy.year,
            hoy.month,
            hoy.day,
          ).subtract(Duration(days: i));
          final clave =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          final e = porFecha[clave];
          final emociones = e == null
              ? const []
              : (e['emociones'] as List? ?? const []);
          return DiaHistorial(
            _letras[d.weekday - 1],
            e == null ? null : polaridadDesdeTexto(e['polaridad'] as String),
            emociones.isEmpty ? null : emociones.first as String,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicio = hoy.subtract(const Duration(days: 6));
    return FutureBuilder<RespuestaApi>(
      future: ServicioPrototipo.listarEntradas(dias: 7),
      builder: (context, snap) {
        if (!snap.hasData) {
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
          dias: _semana(r.datos!['entradas'] as List, hoy),
          onAbrirSerena: onAbrirSerena,
          onLlamar: (l) => mostrarNumero(context, l),
        );
      },
    );
  }
}
