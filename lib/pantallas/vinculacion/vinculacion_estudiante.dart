// PROTOTIPO (Semana 2): vinculación con el tutor, del lado del estudiante.
//
// Sentido 1: el estudiante registra a su tutor y recibe un código de 6
// dígitos que le dicta; el tutor confirma desde su cuenta.
// Sentido 2: si el tutor fue quien empezó, aquí aparece su solicitud y el
// estudiante la acepta o la rechaza.
// Reglas: mock_backend/app/vinculacion_bidireccional.py
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../diario/diario_widgets.dart';
import '../servicios/servicio_prototipo.dart';

final _curpValida = RegExp(r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$');
final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class SolicitudEntrante {
  const SolicitudEntrante(this.nombreTutor, this.parentesco, {this.id = 0});
  final int id;
  final String nombreTutor;
  final String parentesco;
}

class SolicitudEnviada {
  const SolicitudEnviada(this.nombreTutor, this.estado);
  final String nombreTutor;
  final String estado;
}

class DatosTutorFormulario {
  const DatosTutorFormulario(
    this.nombre,
    this.curp,
    this.correo,
    this.parentesco,
  );
  final String nombre;
  final String curp;
  final String correo;
  final String parentesco;
}

class VinculacionEstudiantePantalla extends StatefulWidget {
  const VinculacionEstudiantePantalla({
    super.key,
    this.codigoGenerado,
    this.nombreTutorRegistrado,
    this.solicitudEntrante,
    this.enviadas = const [],
    this.enviando = false,
    this.onEnviar,
    this.onResponder,
  });

  /// Si ya se envió la solicitud: el código que se muestra una sola vez.
  final String? codigoGenerado;
  final String? nombreTutorRegistrado;
  final SolicitudEntrante? solicitudEntrante;
  final List<SolicitudEnviada> enviadas;
  final bool enviando;
  final ValueChanged<DatosTutorFormulario>? onEnviar;
  final ValueChanged<bool>? onResponder;

  @override
  State<VinculacionEstudiantePantalla> createState() =>
      _VinculacionEstudiantePantallaState();
}

class _VinculacionEstudiantePantallaState
    extends State<VinculacionEstudiantePantalla> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _curp = TextEditingController();
  final _correo = TextEditingController();
  String _parentesco = 'madre';

  @override
  void dispose() {
    _nombre.dispose();
    _curp.dispose();
    _correo.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!(_form.currentState?.validate() ?? false)) return;
    widget.onEnviar?.call(
      DatosTutorFormulario(
        _nombre.text.trim(),
        _curp.text.trim().toUpperCase(),
        _correo.text.trim(),
        _parentesco,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        title: const Text(
          'Mi tutor',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (widget.solicitudEntrante != null) ...[
            _TarjetaSolicitud(
              solicitud: widget.solicitudEntrante!,
              onResponder: widget.onResponder,
            ),
            const SizedBox(height: 20),
          ],
          if (widget.codigoGenerado == null)
            _formulario()
          else
            _CodigoEnviado(
              codigo: widget.codigoGenerado!,
              nombreTutor: widget.nombreTutorRegistrado ?? '',
            ),
          if (widget.enviadas.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Tus solicitudes',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final s in widget.enviadas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.estado == 'vinculada'
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_top_rounded,
                  color: s.estado == 'vinculada'
                      ? const Color(0xFF43A047)
                      : const Color(0xFFF9A825),
                ),
                title: Text(s.nombreTutor),
                subtitle: Text(_estadoLegible(s.estado)),
              ),
          ],
          const SizedBox(height: 16),
          const EtiquetaPrototipo(
            texto:
                'La vinculación solo se activa cuando tu tutor confirma con tus datos y tu código.',
          ),
        ],
      ),
    );
  }

  Widget _formulario() {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Registra a tu mamá, papá o tutor',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'Le llegará un aviso y tendrá que confirmar desde su cuenta, usando el correo que escribas aquí.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nombre,
            decoration: _deco('Nombre completo', Icons.person_rounded),
            validator: (v) => (v ?? '').trim().length < 3
                ? 'Escribe su nombre completo'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _curp,
            decoration: _deco(
              'CURP de tu tutor',
              Icons.badge_rounded,
              ayuda: '18 caracteres',
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(18)],
            validator: (v) =>
                _curpValida.hasMatch((v ?? '').trim().toUpperCase())
                ? null
                : 'CURP no válida',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            decoration: _deco(
              'Correo de su cuenta en la app',
              Icons.mail_rounded,
            ),
            validator: (v) => _correoValido.hasMatch((v ?? '').trim())
                ? null
                : 'Correo no válido',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _parentesco,
            decoration: _deco('Parentesco', Icons.family_restroom_rounded),
            items: const [
              DropdownMenuItem(value: 'madre', child: Text('Madre')),
              DropdownMenuItem(value: 'padre', child: Text('Padre')),
              DropdownMenuItem(value: 'tutor', child: Text('Tutor legal')),
            ],
            onChanged: (v) => setState(() => _parentesco = v ?? 'madre'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.enviando || widget.onEnviar == null
                ? null
                : _enviar,
            icon: widget.enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Enviar solicitud'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _estadoLegible(String estado) => switch (estado) {
  'pendiente_tutor' => 'Esperando a que confirme',
  'vinculada' => 'Vinculados',
  'bloqueada' => 'Bloqueada por demasiados intentos',
  'expirada' => 'Venció; envía una nueva',
  'rechazada' => 'Rechazada',
  _ => estado,
};

class _CodigoEnviado extends StatelessWidget {
  const _CodigoEnviado({required this.codigo, required this.nombreTutor});
  final String codigo;
  final String nombreTutor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF43A047), Color(0xFF26A69A)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              const Text(
                'Tu código de vinculación',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < codigo.length; i++) ...[
                    if (i == 3) const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        codigo[i],
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Díctaselo a $nombreTutor. Vence en 72 horas y solo se muestra esta vez.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _Pasos(actual: 1),
      ],
    );
  }
}

class _Pasos extends StatelessWidget {
  const _Pasos({required this.actual});
  final int actual;

  @override
  Widget build(BuildContext context) {
    const pasos = [
      'Enviaste la solicitud',
      'Tu tutor confirma con tus datos y el código',
      'Quedan vinculados',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < pasos.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    i < actual
                        ? Icons.check_circle_rounded
                        : (i == actual
                              ? Icons.hourglass_top_rounded
                              : Icons.radio_button_unchecked_rounded),
                    color: i < actual
                        ? const Color(0xFF43A047)
                        : (i == actual ? const Color(0xFFF9A825) : Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pasos[i],
                      style: TextStyle(
                        fontWeight: i == actual
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
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

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud({required this.solicitud, this.onResponder});
  final SolicitudEntrante solicitud;
  final ValueChanged<bool>? onResponder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF8D6E00),
              ),
              SizedBox(width: 8),
              Text(
                'Solicitud de vinculación',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: solicitud.nombreTutor,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text:
                      ' quiere vincularse como tu ${solicitud.parentesco}. ¿Es correcto?',
                ),
              ],
            ),
            style: const TextStyle(height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            'Si no lo reconoces, recházala.',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onResponder == null
                      ? null
                      : () => onResponder!(false),
                  child: const Text('No lo reconozco'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onResponder == null
                      ? null
                      : () => onResponder!(true),
                  child: const Text('Sí, aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Contenedor: carga las solicitudes del estudiante y habla con la API.
class VinculacionEstudianteFlujo extends StatefulWidget {
  const VinculacionEstudianteFlujo({super.key});

  @override
  State<VinculacionEstudianteFlujo> createState() =>
      _VinculacionEstudianteFlujoState();
}

class _VinculacionEstudianteFlujoState
    extends State<VinculacionEstudianteFlujo> {
  bool _cargando = true;
  bool _enviando = false;
  String? _codigo;
  String? _nombreTutor;
  SolicitudEntrante? _entrante;
  List<SolicitudEnviada> _enviadas = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _avisar(String texto) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _cargar() async {
    final r = await ServicioPrototipo.estudianteSolicitudes();
    if (!mounted) return;
    final datos = r.datos;
    setState(() {
      _cargando = false;
      if (datos == null) return;
      final recibidas = (datos['recibidas'] as List).whereType<Map>().toList();
      _entrante = recibidas.isEmpty
          ? null
          : SolicitudEntrante(
              recibidas.first['nombre_tutor'] as String,
              recibidas.first['parentesco'] as String,
              id: recibidas.first['id_solicitud'] as int,
            );
      _enviadas = (datos['enviadas'] as List)
          .whereType<Map>()
          .map(
            (e) => SolicitudEnviada(
              e['nombre_tutor'] as String,
              e['estado'] as String,
            ),
          )
          .toList(growable: false);
    });
    if (datos == null) {
      _avisar(r.mensaje ?? 'No se pudieron cargar tus solicitudes.');
    }
  }

  Future<void> _enviar(DatosTutorFormulario d) async {
    setState(() => _enviando = true);
    final r = await ServicioPrototipo.estudianteRegistraTutor(
      nombre: d.nombre,
      curp: d.curp,
      correo: d.correo,
      parentesco: d.parentesco,
    );
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (r.ok) {
        _codigo = r.datos!['codigo'] as String;
        _nombreTutor = r.datos!['nombre_tutor'] as String;
      }
    });
    if (!r.ok) _avisar(r.mensaje ?? 'No se pudo enviar.');
    await _cargar();
  }

  Future<void> _responder(bool acepta) async {
    final entrante = _entrante;
    if (entrante == null) return;
    final r = await ServicioPrototipo.estudianteResponde(entrante.id, acepta);
    if (!mounted) return;
    _avisar(
      !r.ok
          ? (r.mensaje ?? 'No se pudo responder.')
          : acepta
          ? 'Listo: la vinculación con ${entrante.nombreTutor} quedó confirmada.'
          : 'Solicitud rechazada.',
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return VinculacionEstudiantePantalla(
      codigoGenerado: _codigo,
      nombreTutorRegistrado: _nombreTutor,
      solicitudEntrante: _entrante,
      enviadas: _enviadas,
      enviando: _enviando,
      onEnviar: _enviar,
      onResponder: _responder,
    );
  }
}
