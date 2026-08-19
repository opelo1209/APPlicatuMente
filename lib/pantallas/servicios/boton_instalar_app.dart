import 'package:flutter/material.dart';

import 'instalar_pwa.dart';

/// Botón "Instalar app" para la versión web.
///
/// Se dibuja solo si tiene sentido: desaparece en las compilaciones nativas y
/// cuando la app ya se está ejecutando instalada. En los navegadores que
/// exponen `beforeinstallprompt` (Chrome, Edge, Opera, Samsung, Chrome Android)
/// dispara el diálogo nativo; en el resto (Safari, iOS, Firefox) abre las
/// instrucciones manuales, que es la única vía de instalación que ofrecen.
class BotonInstalarApp extends StatefulWidget {
  const BotonInstalarApp({super.key, this.compacto = false});

  /// Variante reducida (solo icono) para barras de navegación.
  final bool compacto;

  @override
  State<BotonInstalarApp> createState() => _BotonInstalarAppState();
}

class _BotonInstalarAppState extends State<BotonInstalarApp> {
  static const Color _verde = Color(0xFF66BB6A);

  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    InstalarPwa.inicializar();
  }

  Future<void> _alPulsar() async {
    if (_procesando) return;

    if (!InstalarPwa.promptDisponible.value) {
      _mostrarInstrucciones();
      return;
    }

    setState(() => _procesando = true);
    final resultado = await InstalarPwa.instalar();
    if (!mounted) return;
    setState(() => _procesando = false);

    switch (resultado) {
      case ResultadoInstalacion.aceptada:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Listo! Busca APPlicatuMente entre tus apps.'),
            backgroundColor: _verde,
            behavior: SnackBarBehavior.floating,
          ),
        );
      case ResultadoInstalacion.rechazada:
        break;
      case ResultadoInstalacion.noDisponible:
        _mostrarInstrucciones();
    }
  }

  void _mostrarInstrucciones() {
    showDialog<void>(
      context: context,
      builder: (contexto) => _DialogoInstruccionesInstalacion(
        navegador: InstalarPwa.navegador,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!InstalarPwa.esWeb || InstalarPwa.yaInstalada) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // El botón se muestra siempre (con instrucciones como respaldo), pero se
    // repinta cuando llega `beforeinstallprompt` para reflejar que ya hay
    // instalación en un clic.
    return ValueListenableBuilder<bool>(
      valueListenable: InstalarPwa.promptDisponible,
      builder: (context, hayPromptNativo, _) {
        if (widget.compacto) {
          return IconButton(
            onPressed: _procesando ? null : _alPulsar,
            tooltip: 'Instalar APPlicatuMente',
            icon: _procesando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.install_mobile_outlined),
          );
        }

        return Semantics(
          button: true,
          label: 'Instalar APPlicatuMente en este dispositivo',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _procesando ? null : _alPulsar,
              borderRadius: BorderRadius.circular(30),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: isDarkMode
                      ? const Color(0xFF1C222B)
                      : const Color(0xFFF1F8E9),
                  border: Border.all(
                    color: _verde.withValues(alpha: hayPromptNativo ? 0.55 : 0.28),
                    width: hayPromptNativo ? 1.6 : 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_procesando)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _verde,
                        ),
                      )
                    else
                      const Icon(
                        Icons.install_mobile_outlined,
                        size: 19,
                        color: _verde,
                      ),
                    const SizedBox(width: 9),
                    Text(
                      'Instalar app',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: isDarkMode ? Colors.white : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pasos manuales para los navegadores sin diálogo nativo de instalación.
class _DialogoInstruccionesInstalacion extends StatelessWidget {
  const _DialogoInstruccionesInstalacion({required this.navegador});

  final NavegadorPwa navegador;

  static const Color _verde = Color(0xFF66BB6A);

  ({String titulo, List<String> pasos, String? nota}) get _contenido {
    switch (navegador) {
      case NavegadorPwa.ios:
        return (
          titulo: 'Instalar en iPhone o iPad',
          pasos: [
            'Abre esta página en Safari.',
            'Toca el botón Compartir en la barra inferior.',
            'Desliza y elige "Añadir a pantalla de inicio".',
            'Confirma con "Añadir".',
          ],
          nota:
              'iOS solo permite instalar desde el menú Compartir; no existe un '
              'botón automático.',
        );
      case NavegadorPwa.safari:
        return (
          titulo: 'Instalar en Safari',
          pasos: [
            'Abre el menú Archivo o el botón Compartir.',
            'Elige "Añadir al Dock".',
            'Confirma con "Añadir".',
          ],
          nota: 'Disponible en Safari 17 o superior (macOS Sonoma).',
        );
      case NavegadorPwa.firefox:
        return (
          titulo: 'Instalar en Firefox',
          pasos: [
            'En Android: abre el menú (⋮) y elige "Instalar" o '
                '"Añadir a la pantalla de inicio".',
            'En computadora: Firefox no permite instalar aplicaciones web.',
          ],
          nota:
              'En computadora, abre esta página en Chrome, Edge u Opera para '
              'instalarla con un clic.',
        );
      default:
        return (
          titulo: 'Instalar la aplicación',
          pasos: [
            'Abre el menú del navegador (⋮ o ⋯), arriba a la derecha.',
            'Elige "Instalar aplicación" o "Añadir a la pantalla de inicio".',
            'Confirma con "Instalar".',
          ],
          nota:
              'En computadora también aparece un icono de instalación en la '
              'barra de direcciones.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contenido = _contenido;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.install_mobile_outlined, color: _verde, size: 30),
      title: Text(
        contenido.titulo,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < contenido.pasos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _verde,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      contenido.pasos[i],
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          if (contenido.nota != null) ...[
            const SizedBox(height: 4),
            Text(
              contenido.nota!,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: _verde),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
