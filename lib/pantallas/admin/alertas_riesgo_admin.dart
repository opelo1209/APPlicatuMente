// PROTOTIPO (Semana 2): alertas de riesgo para el administrador.
//
// Cada alerta trae qué reglas se cumplieron, la frase exacta que generó
// cada hecho y la prueba del motor de Wang. No trae el texto completo del
// diario ni de la conversación (ver reporte, privacidad).
import 'package:flutter/material.dart';

import '../servicios/servicio_prototipo.dart';

class AlertasRiesgoAdmin extends StatefulWidget {
  const AlertasRiesgoAdmin({super.key});

  @override
  State<AlertasRiesgoAdmin> createState() => _AlertasRiesgoAdminState();
}

class _AlertasRiesgoAdminState extends State<AlertasRiesgoAdmin> {
  // Semana 5 (H9): por omisión se ven primero las que nadie ha atendido.
  bool _soloPendientes = true;
  late Future<RespuestaApi> _alertas = _cargar();

  Future<RespuestaApi> _cargar() =>
      ServicioPrototipo.alertasRiesgo(soloPendientes: _soloPendientes);

  void _recargar() => setState(() => _alertas = _cargar());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          'Alertas de riesgo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Pendientes')),
                ButtonSegment(value: false, label: Text('Todas')),
              ],
              selected: {_soloPendientes},
              onSelectionChanged: (s) {
                _soloPendientes = s.first;
                _recargar();
              },
            ),
          ),
        ),
      ),
      body: FutureBuilder<RespuestaApi>(
        future: _alertas,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snap.data!;
          if (!r.ok) {
            return Center(child: Text(r.mensaje ?? 'No se pudieron cargar.'));
          }
          final alertas = (r.datos!['alertas'] as List)
              .whereType<Map>()
              .toList();
          if (alertas.isEmpty) {
            return Center(
              child: Text(
                _soloPendientes
                    ? 'No hay alertas pendientes.'
                    : 'No hay alertas.',
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: alertas.length,
            itemBuilder: (_, i) =>
                _TarjetaAlerta(alerta: alertas[i], onCambio: _recargar),
          );
        },
      ),
    );
  }
}

// Semana 3: el chat genera tres tipos de alerta (crisis, respuesta bloqueada
// por la guardia de salida y riesgo acumulado en la conversacion).
String _origen(String? origen) => switch (origen) {
  'chat' => 'Chat con Serena: crisis',
  'chat_salida' => 'Chat con Serena: respuesta bloqueada',
  'chat_acumulado' => 'Chat con Serena: señales repetidas',
  'chat_autolesion' => 'Chat con Serena: autolesión',
  'chat_metodo' => 'Chat con Serena: preguntó por métodos',
  'diario' => 'Diario',
  _ => 'Diario',
};

class _TarjetaAlerta extends StatelessWidget {
  const _TarjetaAlerta({required this.alerta, required this.onCambio});
  final Map<dynamic, dynamic> alerta;
  final VoidCallback onCambio;

  Future<void> _atender(
    BuildContext context,
    bool atendida,
    String nota,
  ) async {
    final r = await ServicioPrototipo.atenderAlerta(
      alerta['id_alerta'] as int,
      atendida: atendida,
      nota: nota,
    );
    if (!context.mounted) return;
    if (!r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.mensaje ?? 'No se pudo guardar.')),
      );
      return;
    }
    onCambio();
  }

  @override
  Widget build(BuildContext context) {
    final fecha = DateTime.tryParse(
      alerta['fecha'] as String? ?? '',
    )?.toLocal();
    final reglas = (alerta['reglas'] as List? ?? const []).cast<Object>();
    final evidencia = (alerta['evidencia'] as List? ?? const []).cast<Object>();
    final prueba = (alerta['prueba'] as List? ?? const []).cast<Object>();
    final atendida = alerta['atendida'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: atendida ? const Color(0xFFB7DFB9) : const Color(0xFFF0B4A8),
        ),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: atendida
            ? const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.check_rounded, color: Color(0xFF2E7D32)),
              )
            : const CircleAvatar(
                backgroundColor: Color(0xFFFFEBE6),
                child: Icon(
                  Icons.priority_high_rounded,
                  color: Color(0xFFC62828),
                ),
              ),
        title: Text(
          alerta['estudiante'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${_origen(alerta['origen'] as String?)} · '
          '${fecha == null ? '' : _fechaCorta(fecha)}'
          '${atendida ? ' · atendida' : ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EstadoAtencionAlerta(
            alerta: alerta,
            onAtender: (atendida, nota) => _atender(context, atendida, nota),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [for (final r in reglas) Chip(label: Text('Regla $r'))],
          ),
          // Semana 4: R16 (método en general) no trae frases; sin ellas no
          // se muestra el título vacío.
          if (evidencia.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Frases que coincidieron',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final e in evidencia)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${e.toString().replaceFirst(':', ': «')}»'),
              ),
          ],
          if (alerta['perfil_tipo'] == 'estudiante' &&
              alerta['id_usuario'] is int) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  mostrarResumenRiesgo(context, alerta['id_usuario'] as int),
              icon: const Icon(Icons.summarize_rounded),
              label: const Text('Ver resumen de los últimos 30 días'),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Prueba del motor de Wang',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                prueba.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fechaCorta(DateTime f) =>
    '${f.day}/${f.month} ${f.hour.toString().padLeft(2, '0')}:'
    '${f.minute.toString().padLeft(2, '0')}';

/// Semana 5 (H9): si la alerta ya se atendió, quién y cuándo; si no, el botón
/// para marcarla. Separado de la tarjeta para poder probarlo solo.
class EstadoAtencionAlerta extends StatelessWidget {
  const EstadoAtencionAlerta({
    super.key,
    required this.alerta,
    required this.onAtender,
  });

  final Map<dynamic, dynamic> alerta;
  final void Function(bool atendida, String nota) onAtender;

  Future<void> _pedirNota(BuildContext context) async {
    final nota = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoNotaAtencion(),
    );
    if (nota != null) onAtender(true, nota.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (alerta['atendida'] != true) {
      return FilledButton.icon(
        onPressed: () => _pedirNota(context),
        icon: const Icon(Icons.task_alt_rounded),
        label: const Text('Marcar como atendida'),
      );
    }
    final cuando = DateTime.tryParse(
      alerta['fecha_atendida'] as String? ?? '',
    )?.toLocal();
    final nota = alerta['nota_atencion'] as String?;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Atendida por ${alerta['atendida_por'] ?? 'el administrador'}'
            '${cuando == null ? '' : ' · ${_fechaCorta(cuando)}'}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B5E20),
            ),
          ),
          if (nota != null && nota.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(nota),
          ],
          TextButton(
            onPressed: () => onAtender(false, ''),
            child: const Text('Regresar a pendiente'),
          ),
        ],
      ),
    );
  }
}

/// El diálogo es dueño de su controlador: si lo liberara quien lo abre, el
/// campo seguiría usándolo durante la animación de cierre.
class _DialogoNotaAtencion extends StatefulWidget {
  const _DialogoNotaAtencion();

  @override
  State<_DialogoNotaAtencion> createState() => _DialogoNotaAtencionState();
}

class _DialogoNotaAtencionState extends State<_DialogoNotaAtencion> {
  final _control = TextEditingController();

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Marcar como atendida'),
      content: TextField(
        controller: _control,
        maxLength: 500,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Nota (opcional)',
          hintText: 'Por ejemplo: se habló con el tutor',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _control.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Semana 4 (asesor): resumen de las alertas del estudiante. La versión para
/// el tutor es un borrador: no se envía hasta que lo decidan el asesor y
/// psicología.
Future<void> mostrarResumenRiesgo(BuildContext context, int idUsuario) async {
  final r = await ServicioPrototipo.resumenRiesgo(idUsuario);
  if (!context.mounted) return;
  final datos = r.datos;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Resumen de alertas'),
      content: SingleChildScrollView(
        child: datos == null
            ? Text(r.mensaje ?? 'No se pudo cargar el resumen.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(datos['administrador'] as String? ?? ''),
                  if ((datos['tutor_borrador'] as String? ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Lo que leería el tutor (borrador, no se envía)',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(datos['tutor_borrador'] as String),
                  ],
                ],
              ),
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
