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
  late Future<RespuestaApi> _alertas = ServicioPrototipo.alertasRiesgo();

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
            onPressed: () =>
                setState(() => _alertas = ServicioPrototipo.alertasRiesgo()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
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
            return const Center(child: Text('No hay alertas.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: alertas.length,
            itemBuilder: (_, i) => _TarjetaAlerta(alerta: alertas[i]),
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
  'diario' => 'Diario',
  _ => 'Diario',
};

class _TarjetaAlerta extends StatelessWidget {
  const _TarjetaAlerta({required this.alerta});
  final Map<dynamic, dynamic> alerta;

  @override
  Widget build(BuildContext context) {
    final fecha = DateTime.tryParse(
      alerta['fecha'] as String? ?? '',
    )?.toLocal();
    final reglas = (alerta['reglas'] as List? ?? const []).cast<Object>();
    final evidencia = (alerta['evidencia'] as List? ?? const []).cast<Object>();
    final prueba = (alerta['prueba'] as List? ?? const []).cast<Object>();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF0B4A8)),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFEBE6),
          child: Icon(Icons.priority_high_rounded, color: Color(0xFFC62828)),
        ),
        title: Text(
          alerta['estudiante'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${_origen(alerta['origen'] as String?)} · '
          '${fecha == null ? '' : '${fecha.day}/${fecha.month} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [for (final r in reglas) Chip(label: Text('Regla $r'))],
          ),
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
