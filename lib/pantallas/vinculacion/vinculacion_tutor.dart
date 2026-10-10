// PROTOTIPO (Semana 2): vinculación del lado del padre, madre o tutor.
//
// - Confirmar (sentido 1): el estudiante lo registró; confirma con su propia
//   CURP, la CURP y fecha de nacimiento del estudiante y el código.
// - Solicitar (sentido 2): escribe CURP y fecha de nacimiento del estudiante;
//   el estudiante acepta o rechaza en su app.
// Reglas: mock_backend/app/vinculacion_bidireccional.py
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../diario/diario_widgets.dart';
import '../servicios/servicio_prototipo.dart';

final _curpValida = RegExp(r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$');

class ConfirmacionFormulario {
  const ConfirmacionFormulario(
    this.curpPropia,
    this.curpEstudiante,
    this.fechaNacimiento,
    this.codigo,
  );
  final String curpPropia;
  final String curpEstudiante;
  final String fechaNacimiento; // aaaa-mm-dd
  final String codigo;
}

/// "dd/mm/aaaa" -> "aaaa-mm-dd", o null si no es una fecha válida.
String? fechaIso(String texto) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(texto.trim());
  if (m == null) return null;
  final d = int.parse(m[1]!), mes = int.parse(m[2]!), a = int.parse(m[3]!);
  final fecha = DateTime(a, mes, d);
  if (fecha.year != a || fecha.month != mes || fecha.day != d) return null;
  return '${a.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

InputDecoration _deco(String etiqueta, IconData icono, {String? ayuda}) =>
    InputDecoration(
      labelText: etiqueta,
      helperText: ayuda,
      prefixIcon: Icon(icono),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );

String? _validarCurp(String? v) =>
    _curpValida.hasMatch((v ?? '').trim().toUpperCase())
    ? null
    : 'CURP no válida';
String? _validarFecha(String? v) =>
    fechaIso(v ?? '') == null ? 'Usa el formato dd/mm/aaaa' : null;

class VinculacionTutorPantalla extends StatefulWidget {
  const VinculacionTutorPantalla({
    super.key,
    required this.nombreEstudiante,
    this.mensajeError,
    this.intentosRestantes,
    this.enviando = false,
    this.onConfirmar,
  });

  final String nombreEstudiante;
  final String? mensajeError;
  final int? intentosRestantes;
  final bool enviando;
  final ValueChanged<ConfirmacionFormulario>? onConfirmar;

  @override
  State<VinculacionTutorPantalla> createState() =>
      _VinculacionTutorPantallaState();
}

class _VinculacionTutorPantallaState extends State<VinculacionTutorPantalla> {
  final _form = GlobalKey<FormState>();
  final _curpPropia = TextEditingController();
  final _curpEstudiante = TextEditingController();
  final _fecha = TextEditingController();
  final _codigo = TextEditingController();

  @override
  void dispose() {
    for (final c in [_curpPropia, _curpEstudiante, _fecha, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _confirmar() {
    if (!(_form.currentState?.validate() ?? false)) return;
    widget.onConfirmar?.call(
      ConfirmacionFormulario(
        _curpPropia.text.trim().toUpperCase(),
        _curpEstudiante.text.trim().toUpperCase(),
        fechaIso(_fecha.text)!,
        _codigo.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloqueada = widget.intentosRestantes == 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          'Confirmar vinculación',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.mark_email_unread_rounded,
                    color: Color(0xFF1565C0),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: widget.nombreEstudiante,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(
                            text:
                                ' te registró como su tutor. Confirma con sus datos y el código que te dio.',
                          ),
                        ],
                      ),
                      style: const TextStyle(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _curpPropia,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(18)],
              decoration: _deco(
                'Tu CURP',
                Icons.person_rounded,
                ayuda: 'La que escribió el estudiante',
              ),
              validator: _validarCurp,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _curpEstudiante,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(18)],
              decoration: _deco('CURP del estudiante', Icons.badge_rounded),
              validator: _validarCurp,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fecha,
              keyboardType: TextInputType.datetime,
              decoration: _deco(
                'Fecha de nacimiento del estudiante',
                Icons.cake_rounded,
                ayuda: 'dd/mm/aaaa',
              ),
              validator: _validarFecha,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codigo,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
              ),
              decoration: _deco('Código de 6 dígitos', Icons.pin_rounded),
              validator: (v) =>
                  (v ?? '').length == 6 ? null : 'El código tiene 6 dígitos',
            ),
            if (widget.mensajeError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBE6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFC62828),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.intentosRestantes == null
                            ? widget.mensajeError!
                            : '${widget.mensajeError} Te quedan ${widget.intentosRestantes} intentos.',
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  widget.enviando || bloqueada || widget.onConfirmar == null
                  ? null
                  : _confirmar,
              icon: widget.enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_user_rounded),
              label: Text(
                bloqueada ? 'Solicitud bloqueada' : 'Confirmar vinculación',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const EtiquetaPrototipo(
              texto:
                  'El mensaje de error es el mismo para cualquier dato incorrecto, a propósito.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenedor de la confirmación de UNA solicitud.
class ConfirmarSolicitudFlujo extends StatefulWidget {
  const ConfirmarSolicitudFlujo({
    super.key,
    required this.idSolicitud,
    required this.nombreEstudiante,
  });
  final int idSolicitud;
  final String nombreEstudiante;

  @override
  State<ConfirmarSolicitudFlujo> createState() =>
      _ConfirmarSolicitudFlujoState();
}

class _ConfirmarSolicitudFlujoState extends State<ConfirmarSolicitudFlujo> {
  bool _enviando = false;
  String? _error;
  int? _restantes;

  Future<void> _confirmar(ConfirmacionFormulario f) async {
    setState(() => _enviando = true);
    final r = await ServicioPrototipo.tutorConfirma(
      widget.idSolicitud,
      curpPropia: f.curpPropia,
      curpEstudiante: f.curpEstudiante,
      fechaNacimiento: f.fechaNacimiento,
      codigo: f.codigo,
    );
    if (!mounted) return;
    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Listo: la vinculación con ${widget.nombreEstudiante} quedó confirmada.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }
    // El servidor manda un único mensaje genérico; los intentos van al final.
    final restantes = RegExp(
      r'Te quedan (\d+) intentos',
    ).firstMatch(r.mensaje ?? '');
    setState(() {
      _enviando = false;
      _restantes = restantes == null ? null : int.parse(restantes[1]!);
      _error = (r.mensaje ?? 'No se pudo confirmar.').replaceAll(
        RegExp(r' Te quedan \d+ intentos\.'),
        '',
      );
    });
  }

  @override
  Widget build(BuildContext context) => VinculacionTutorPantalla(
    nombreEstudiante: widget.nombreEstudiante,
    mensajeError: _error,
    intentosRestantes: _restantes,
    enviando: _enviando,
    onConfirmar: _confirmar,
  );
}

/// Inicio de la vinculación para el padre: solicitudes por confirmar y
/// formulario para pedirla él (sentido 2).
class VinculacionTutorFlujo extends StatefulWidget {
  const VinculacionTutorFlujo({super.key});

  @override
  State<VinculacionTutorFlujo> createState() => _VinculacionTutorFlujoState();
}

class _VinculacionTutorFlujoState extends State<VinculacionTutorFlujo> {
  final _form = GlobalKey<FormState>();
  final _curp = TextEditingController();
  final _fecha = TextEditingController();
  String _parentesco = 'madre';
  bool _enviando = false;
  late Future<RespuestaApi> _pendientes = ServicioPrototipo.tutorPendientes();

  @override
  void dispose() {
    _curp.dispose();
    _fecha.dispose();
    super.dispose();
  }

  Future<void> _solicitar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    final r = await ServicioPrototipo.tutorSolicita(
      curpEstudiante: _curp.text.trim().toUpperCase(),
      fechaNacimiento: fechaIso(_fecha.text)!,
      parentesco: _parentesco,
    );
    if (!mounted) return;
    setState(() => _enviando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.ok
              ? r.datos!['mensaje'] as String
              : (r.mensaje ?? 'No se pudo enviar.'),
        ),
      ),
    );
    if (r.ok) {
      _curp.clear();
      _fecha.clear();
    }
  }

  Future<void> _abrir(Map<dynamic, dynamic> p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmarSolicitudFlujo(
          idSolicitud: p['id_solicitud'] as int,
          nombreEstudiante: p['nombre_estudiante'] as String,
        ),
      ),
    );
    if (mounted) {
      setState(() => _pendientes = ServicioPrototipo.tutorPendientes());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          'Vincular a mi hijo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          const Text(
            'Por confirmar',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          FutureBuilder<RespuestaApi>(
            future: _pendientes,
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              final r = snap.data!;
              final lista = r.ok
                  ? (r.datos!['pendientes'] as List).whereType<Map>().toList()
                  : const <Map>[];
              if (lista.isEmpty) {
                return Text(
                  r.ok
                      ? 'No tienes solicitudes por confirmar.'
                      : (r.mensaje ?? 'No se pudieron cargar.'),
                  style: TextStyle(color: Colors.grey[700]),
                );
              }
              return Column(
                children: [
                  for (final p in lista)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.mark_email_unread_rounded,
                          color: Color(0xFF1565C0),
                        ),
                        title: Text(p['nombre_estudiante'] as String),
                        subtitle: Text(
                          'Te registró como ${p['parentesco']}. Intentos: ${p['intentos_restantes']}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _abrir(p),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            '¿Tu hijo aún no te registra?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Escribe sus datos. Le llegará tu solicitud y tendrá que aceptarla en su app.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _curp,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(18)],
                  decoration: _deco('CURP del estudiante', Icons.badge_rounded),
                  validator: _validarCurp,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fecha,
                  keyboardType: TextInputType.datetime,
                  decoration: _deco(
                    'Fecha de nacimiento',
                    Icons.cake_rounded,
                    ayuda: 'dd/mm/aaaa',
                  ),
                  validator: _validarFecha,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _parentesco,
                  decoration: _deco(
                    'Parentesco',
                    Icons.family_restroom_rounded,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'madre', child: Text('Madre')),
                    DropdownMenuItem(value: 'padre', child: Text('Padre')),
                    DropdownMenuItem(
                      value: 'tutor',
                      child: Text('Tutor legal'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _parentesco = v ?? 'madre'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _enviando ? null : _solicitar,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Enviar solicitud al estudiante'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const EtiquetaPrototipo(
            texto:
                'Por seguridad, la respuesta es la misma aunque los datos no coincidan.',
          ),
        ],
      ),
    );
  }
}
