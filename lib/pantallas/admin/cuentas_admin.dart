// PROTOTIPO Semana 5: cuentas para el administrador.
//
// La app no tenía cómo ver las cuentas: el backend ya podía reactivar una
// cuenta desactivada (H6), pero no había dónde encontrarla. Aquí se listan
// estudiantes y tutores, se desactivan o reactivan, y se BORRAN con todos sus
// datos (derecho de cancelación del aviso de privacidad). Borrar pide
// escribir el nombre de usuario: no tiene vuelta atrás.
import 'package:flutter/material.dart';

import '../servicios/servicio_prototipo.dart';

/// El botón de borrar solo se habilita con el nombre de usuario exacto.
bool confirmacionDeBorrado(String escrito, String usuario) =>
    escrito.trim() == usuario && usuario.isNotEmpty;

const String textoBorradoCuenta =
    'Se borran la cuenta, su diario, sus cuestionarios, sus sesiones y su '
    'vínculo con el tutor. Las alertas de riesgo se conservan sin nada que '
    'identifique a la persona (tipo, fecha y si se atendió). Los respaldos '
    'del servidor la conservan hasta 14 días. No se puede deshacer.';

class CuentasAdmin extends StatefulWidget {
  const CuentasAdmin({super.key});

  @override
  State<CuentasAdmin> createState() => _CuentasAdminState();
}

class _CuentasAdminState extends State<CuentasAdmin> {
  String _perfil = 'estudiante';
  String _buscar = '';
  late Future<RespuestaApi> _cuentas = _cargar();

  Future<RespuestaApi> _cargar() =>
      ServicioPrototipo.cuentas(perfil: _perfil, buscar: _buscar);

  void _recargar() => setState(() => _cuentas = _cargar());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cuentas',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'estudiante', label: Text('Estudiantes')),
                ButtonSegment(value: 'padre', label: Text('Tutores')),
              ],
              selected: {_perfil},
              onSelectionChanged: (s) {
                _perfil = s.first;
                _recargar();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre, usuario o correo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (texto) {
                _buscar = texto;
                _recargar();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<RespuestaApi>(
              future: _cuentas,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final r = snap.data!;
                if (!r.ok) {
                  return Center(
                    child: Text(r.mensaje ?? 'No se pudieron cargar.'),
                  );
                }
                final cuentas = (r.datos!['cuentas'] as List)
                    .whereType<Map>()
                    .toList();
                if (cuentas.isEmpty) {
                  return const Center(child: Text('No hay cuentas.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: cuentas.length,
                  itemBuilder: (_, i) =>
                      TarjetaCuenta(cuenta: cuentas[i], onCambio: _recargar),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TarjetaCuenta extends StatelessWidget {
  const TarjetaCuenta({super.key, required this.cuenta, required this.onCambio});
  final Map<dynamic, dynamic> cuenta;
  final VoidCallback onCambio;

  String get _perfil => cuenta['perfil_tipo'] as String;
  int get _id => cuenta['id_usuario'] as int;
  String get _usuario => cuenta['nombre_usuario'] as String;

  Future<void> _avisar(BuildContext context, RespuestaApi r, String ok) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.ok ? ok : (r.mensaje ?? 'No se pudo.'))),
    );
    if (r.ok) onCambio();
  }

  Future<void> _cambiarActivo(BuildContext context, bool activo) async {
    final r = await ServicioPrototipo.cambiarActivo(
      _perfil,
      _id,
      activo: activo,
    );
    if (!context.mounted) return;
    await _avisar(
      context,
      r,
      activo ? 'Cuenta reactivada.' : 'Cuenta desactivada.',
    );
  }

  Future<void> _borrar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => DialogoBorrarCuenta(usuario: _usuario),
    );
    if (confirmado != true || !context.mounted) return;
    final r = await ServicioPrototipo.borrarCuenta(_perfil, _id, _usuario);
    if (!context.mounted) return;
    await _avisar(context, r, 'Cuenta borrada.');
  }

  @override
  Widget build(BuildContext context) {
    final activo = cuenta['activo'] == true;
    final esquema = Theme.of(context).colorScheme;
    final ultima = DateTime.tryParse(
      cuenta['ultima_conexion'] as String? ?? '',
    )?.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (cuenta['nombre_completo'] as String?)?.isNotEmpty == true
                  ? cuenta['nombre_completo'] as String
                  : _usuario,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text('$_usuario · ${cuenta['correo'] ?? ''}'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(activo ? 'Activa' : 'Desactivada'),
                  backgroundColor: activo
                      ? Colors.green.withValues(alpha: 0.15)
                      : esquema.errorContainer,
                ),
                if (cuenta['google'] == true)
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Google'),
                  ),
                if (ultima != null)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'Última vez: ${ultima.day}/${ultima.month}/${ultima.year}',
                    ),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cambiarActivo(context, !activo),
                  icon: Icon(activo ? Icons.block : Icons.check_circle_outline),
                  label: Text(activo ? 'Desactivar' : 'Reactivar'),
                ),
                TextButton.icon(
                  onPressed: () => _borrar(context),
                  style: TextButton.styleFrom(foregroundColor: esquema.error),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Borrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dueño de su controlador (como en las alertas: no se libera mientras el
/// diálogo todavía se está cerrando).
class DialogoBorrarCuenta extends StatefulWidget {
  const DialogoBorrarCuenta({super.key, required this.usuario});
  final String usuario;

  @override
  State<DialogoBorrarCuenta> createState() => _DialogoBorrarCuentaState();
}

class _DialogoBorrarCuentaState extends State<DialogoBorrarCuenta> {
  final _escrito = TextEditingController();

  @override
  void dispose() {
    _escrito.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final puede = confirmacionDeBorrado(_escrito.text, widget.usuario);
    return AlertDialog(
      title: const Text('Borrar la cuenta y sus datos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(textoBorradoCuenta),
          const SizedBox(height: 12),
          Text('Para confirmar, escribe «${widget.usuario}»:'),
          TextField(
            controller: _escrito,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: puede ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Borrar'),
        ),
      ],
    );
  }
}
