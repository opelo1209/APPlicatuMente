import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_provider.dart';
import '../principal.dart';
import 'paso_preferencias.dart';
import 'paso_escritura.dart';
import '../servicios/user.dart';

class CuestionarioWrapper extends StatefulWidget {
  const CuestionarioWrapper({super.key});

  @override
  State<CuestionarioWrapper> createState() => _CuestionarioWrapperState();
}

class _CuestionarioWrapperState extends State<CuestionarioWrapper> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 2; // Preferencias + Escritura

  // Estado compartido
  final Map<String, dynamic> _respuestas = {
    'preferencias': <String, dynamic>{},
    'sentimientos': '',
    'gustos': '',
    'datos': '',
  };

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutQuart,
      );
    } else {
      _finishQuestionnaire();
    }
  }

  Future<void> _finishQuestionnaire() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cuestionario_completado', true);
    final perfilTipo = prefs.getString('perfil_tipo') ?? 'estudiante';
    final idUsuario = prefs.getInt('id_usuario');
    if (idUsuario != null) {
      await prefs.setBool(
        'cuestionario_completado_${perfilTipo}_$idUsuario',
        true,
      );
    }

    debugPrint("Respuestas Finales: $_respuestas");

    // Enviar al backend
    final userService = User();
    final resultado = await userService.updateCuestionario(
      tipoCuestionario: 'informacion_general',
      respuestas: _respuestas,
    );
    debugPrint('Backend informacion general: $resultado');

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const Principal(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode
        ? const Color(0xFF121212)
        : const Color(0xFFF8F9FA);
    final primaryColor = const Color(0xFF43A047);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header with Progress
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E272E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_currentPage > 0)
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            size: 20,
                          ),
                          onPressed: () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOutQuart,
                          ),
                        )
                      else
                        const SizedBox(width: 48), // Placeholder for alignment

                      Expanded(
                        child: Text(
                          "Conociéndote",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(width: 48), // Placeholder for alignment
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Progress Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _totalPages,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        height: 12,
                        width: _currentPage == index ? 40 : 12,
                        decoration: BoxDecoration(
                          color: _currentPage >= index
                              ? primaryColor
                              : (isDarkMode
                                    ? Colors.white12
                                    : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _currentPage == index
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  PasoPreferencias(
                    onCompleted: (resultados) {
                      _respuestas['preferencias'] = resultados;
                      _nextPage();
                    },
                  ),
                  PasoEscritura(
                    onCompleted: (sentimientos, gustos, datos) {
                      _respuestas['sentimientos'] = sentimientos;
                      _respuestas['gustos'] = gustos;
                      _respuestas['datos'] = datos;
                      _finishQuestionnaire();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
