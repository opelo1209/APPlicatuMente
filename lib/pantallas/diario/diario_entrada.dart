// PROTOTIPO (Semana 2): registro del día en el diario emocional.
//
// Orden pensado para que el estudiante se autoevalúe ANTES de ver cualquier
// análisis automático: 1) semáforo, 2) emociones de esa polaridad, 3) texto
// opcional. El análisis llega después y nunca reemplaza lo que él marcó.
import 'package:flutter/material.dart';

import 'diario_catalogo.dart';
import 'diario_estilo.dart';
import 'diario_widgets.dart';

class EntradaDiarioDatos {
  const EntradaDiarioDatos(this.polaridad, this.emociones, this.texto);
  final Polaridad polaridad;
  final List<String> emociones; // claves
  final String texto;
}

class DiarioEntradaPantalla extends StatefulWidget {
  const DiarioEntradaPantalla({
    super.key,
    required this.fecha,
    required this.onGuardar,
    this.onVerHistorial,
    this.acento = const Color(0xFF43A047),
    this.polaridadInicial,
    this.emocionesIniciales = const [],
    this.textoInicial = '',
  });

  final String fecha;
  final ValueChanged<EntradaDiarioDatos> onGuardar;
  final VoidCallback? onVerHistorial;
  final Color acento;
  // Solo para la vista previa y para editar una entrada ya guardada.
  final Polaridad? polaridadInicial;
  final List<String> emocionesIniciales;
  final String textoInicial;

  @override
  State<DiarioEntradaPantalla> createState() => _DiarioEntradaPantallaState();
}

class _DiarioEntradaPantallaState extends State<DiarioEntradaPantalla> {
  static const int _maxCaracteres = 5000;
  Polaridad? _polaridad;
  Set<String> _emociones = {};
  late final TextEditingController _texto;

  @override
  void initState() {
    super.initState();
    _polaridad = widget.polaridadInicial;
    _emociones = widget.emocionesIniciales.toSet();
    _texto = TextEditingController(text: widget.textoInicial);
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _elegirPolaridad(Polaridad p) {
    setState(() {
      // Las emociones dependen de la polaridad: al cambiarla se reinician.
      if (p != _polaridad) _emociones = {};
      _polaridad = p;
    });
  }

  void _alternarEmocion(String clave) {
    setState(() {
      _emociones = _emociones.contains(clave)
          ? (_emociones.toSet()..remove(clave))
          : {..._emociones, clave};
    });
  }

  bool get _listo => _polaridad != null && _emociones.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final info = _polaridad == null ? null : kPolaridades[_polaridad]!;
    final c = DiarioColores.de(context);
    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        title: const Text(
          'Mi diario',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: c.texto,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Mi semana',
            onPressed: widget.onVerHistorial,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _Encabezado(fecha: widget.fecha, acento: widget.acento),
          const SizedBox(height: 18),
          Center(
            child: SemaforoAnimo(
              seleccion: _polaridad,
              onSeleccionar: _elegirPolaridad,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Toca la luz que mejor describa tu día',
              style: TextStyle(
                color: c.textoSuave,
                fontSize: DiarioTexto.apoyo,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: info == null
                ? const SizedBox(width: double.infinity)
                : _seccionEmociones(info, c),
          ),
          if (info != null) ...[
            const SizedBox(height: 20),
            _seccionTexto(info, c),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                // Más oscuro que el acento: texto blanco con contraste AA.
                backgroundColor: Color.lerp(widget.acento, Colors.black, 0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _listo
                  ? () => widget.onGuardar(
                      EntradaDiarioDatos(
                        _polaridad!,
                        _emociones.toList(),
                        _texto.text.trim(),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text(
                'Guardar y ver mi análisis',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            const SizedBox(height: 10),
            const EtiquetaPrototipo(
              texto:
                  'El análisis automático es una guía para ti, no un diagnóstico. '
                  'Lo que tú marcaste es lo que se guarda.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _seccionEmociones(PolaridadInfo info, DiarioColores c) {
    final p = info.polaridad;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué emociones sentiste?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: DiarioTexto.titulo,
              color: c.texto,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Elige una o varias',
            style: TextStyle(color: c.textoSuave, fontSize: DiarioTexto.apoyo),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in emocionesDe(info.polaridad))
                FilterChip(
                  label: Text(e.nombre),
                  selected: _emociones.contains(e.clave),
                  onSelected: (_) => _alternarEmocion(e.clave),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: DiarioTexto.apoyo,
                    color: _emociones.contains(e.clave)
                        ? c.textoSobreElegido(p)
                        : c.texto,
                  ),
                  selectedColor: c.rellenoElegido(p),
                  backgroundColor: info.color.withValues(alpha: 0.10),
                  side: BorderSide(color: info.color.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seccionTexto(PolaridadInfo info, DiarioColores c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.pregunta,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: DiarioTexto.titulo,
            color: c.texto,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Opcional. Escribe con tus palabras, nadie más lo lee.',
          style: TextStyle(color: c.textoSuave, fontSize: DiarioTexto.apoyo),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _texto,
          maxLines: 5,
          minLines: 4,
          maxLength: _maxCaracteres,
          style: TextStyle(color: c.texto, fontSize: DiarioTexto.cuerpo),
          decoration: InputDecoration(
            hintText: 'Hoy...',
            hintStyle: TextStyle(color: c.textoSuave),
            counterStyle: TextStyle(color: c.textoSuave),
            filled: true,
            fillColor: c.superficie,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: c.tinta(info.polaridad), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.fecha, required this.acento});
  final String fecha;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        // Más oscuro que el acento para que el texto blanco tenga contraste
        // suficiente (el verde puro daba ~3:1).
        gradient: LinearGradient(
          colors: [
            Color.lerp(acento, Colors.black, 0.3)!,
            Color.lerp(acento, const Color(0xFF004D40), 0.55)!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fecha.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    fontSize: DiarioTexto.etiqueta,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '¿Cómo estuvo tu día?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tú decides cómo lo calificas. Tu diario es privado.',
                  style: TextStyle(color: Colors.white, height: 1.3),
                ),
              ],
            ),
          ),
          const Icon(Icons.menu_book_rounded, color: Colors.white, size: 46),
        ],
      ),
    );
  }
}
