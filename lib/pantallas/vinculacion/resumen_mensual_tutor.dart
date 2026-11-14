// PROTOTIPO Semana 8 (pregunta 6 de la Dra. González): cada mes, el tutor
// ve en su cuenta cuántos días fueron buenos, regulares y difíciles para cada
// estudiante vinculado. Sin emociones, sin palabras altisonantes y nunca lo
// que escribió (mock_backend/app/resumen_tutor.py).
import 'package:flutter/material.dart';

import '../servicios/user.dart';

typedef CargarResumen = Future<Map<String, dynamic>> Function(String? mes);

const Color _verde = Color(0xFF43A047);
const Color _ambar = Color(0xFFF9A825);
const Color _coral = Color(0xFFE8664F);

/// Mes anterior a `aaaa-mm`, en el mismo formato.
String mesAnteriorDe(String mes) {
  final partes = mes.split('-');
  final anio = int.parse(partes[0]);
  final num = int.parse(partes[1]);
  return num == 1
      ? '${anio - 1}-12'
      : '$anio-${(num - 1).toString().padLeft(2, '0')}';
}

/// Mes siguiente a `aaaa-mm`, en el mismo formato.
String mesSiguienteDe(String mes) {
  final partes = mes.split('-');
  final anio = int.parse(partes[0]);
  final num = int.parse(partes[1]);
  return num == 12
      ? '${anio + 1}-01'
      : '$anio-${(num + 1).toString().padLeft(2, '0')}';
}

class ResumenMensualTutor extends StatefulWidget {
  const ResumenMensualTutor({super.key, this.cargar});

  /// Para las pruebas; por omisión, el servidor.
  final CargarResumen? cargar;

  @override
  State<ResumenMensualTutor> createState() => _ResumenMensualTutorState();
}

class _ResumenMensualTutorState extends State<ResumenMensualTutor> {
  Map<String, dynamic>? _datos;
  String? _error;
  bool _cargando = true;
  String? _mesMasReciente;

  CargarResumen get _cargar =>
      widget.cargar ?? (mes) => User().getResumenMensual(mes: mes);

  @override
  void initState() {
    super.initState();
    _ir(null);
  }

  Future<void> _ir(String? mes) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final r = await _cargar(mes);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (r['success'] == true && r['data'] is Map) {
        _datos = Map<String, dynamic>.from(r['data'] as Map);
        _mesMasReciente ??= _datos?['mes'] as String?;
      } else {
        _error = r['message'] as String? ?? 'No se pudo cargar el resumen.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mes = _datos?['mes'] as String?;
    final resumenes = (_datos?['resumenes'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen del mes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SelectorMes(
            periodo: _datos?['periodo'] as String? ?? '',
            alAnterior: _cargando || mes == null
                ? null
                : () => _ir(mesAnteriorDe(mes)),
            alSiguiente: _cargando || mes == null || mes == _mesMasReciente
                ? null
                : () => _ir(mesSiguienteDe(mes)),
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _Aviso(texto: _error!)
          else if (resumenes.isEmpty)
            const _Aviso(
              texto:
                  'Todavía no tienes estudiantes vinculados. Cuando tu hijo o '
                  'hija confirme el vínculo, aquí verás su resumen cada mes.',
            )
          else
            for (final r in resumenes)
              _TarjetaResumen(datos: Map<String, dynamic>.from(r)),
          const SizedBox(height: 12),
          Text(
            'El resumen solo dice cómo marcó sus días. Nunca incluye lo que '
            'escribió en su diario ni en el chat.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SelectorMes extends StatelessWidget {
  const _SelectorMes({
    required this.periodo,
    required this.alAnterior,
    required this.alSiguiente,
  });

  final String periodo;
  final VoidCallback? alAnterior;
  final VoidCallback? alSiguiente;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Mes anterior',
          onPressed: alAnterior,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            periodo.isEmpty
                ? ''
                : periodo[0].toUpperCase() + periodo.substring(1),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          onPressed: alSiguiente,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.datos});

  final Map<String, dynamic> datos;

  int _n(String clave) => (datos[clave] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              datos['estudiante'] as String? ?? '',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Conteo(n: _n('positivos'), etiqueta: 'buenos', color: _verde),
                _Conteo(n: _n('neutros'), etiqueta: 'regulares', color: _ambar),
                _Conteo(
                  n: _n('dificiles'),
                  etiqueta: 'difíciles',
                  color: _coral,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              datos['texto'] as String? ?? '',
              style: const TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Conteo extends StatelessWidget {
  const _Conteo({required this.n, required this.etiqueta, required this.color});

  final int n;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(etiqueta),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(texto, textAlign: TextAlign.center),
    );
  }
}
