import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_provider.dart';
import '../principal.dart';
import 'paso_identificacion.dart';
import 'paso_preferencias.dart';
import 'paso_escala_suicida.dart';
import 'paso_escritura.dart';

class CuestionarioWrapper extends StatefulWidget {
  const CuestionarioWrapper({super.key});

  @override
  State<CuestionarioWrapper> createState() => _CuestionarioWrapperState();
}

class _CuestionarioWrapperState extends State<CuestionarioWrapper> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4; // Identificación + Preferencias + Escala Suicida + Escritura

  // Estado compartido (Se podría usar Provider, pero localmente funciona para este flujo)
  final Map<String, dynamic> _respuestas = {
    'identificacion': <String, bool>{},
    'preferencias': <String, dynamic>{},
    'escala_suicida': <String, int>{},
    'sentimientos': '',
    'gustos': '',
    'datos': '',
  };

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishQuestionnaire();
    }
  }

  Future<void> _finishQuestionnaire() async {
    // Guardar que ya se completó
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cuestionario_completado', true);

    // Aquí podrías guardar _respuestas en backend o BD local
    debugPrint("Respuestas Finales: $_respuestas");

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const Principal()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    // Paleta Verde
    final primaryGreen = const Color(0xFF43A047); 
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Conociéndote (${_currentPage + 1}/$_totalPages)",
          style: TextStyle(
             color: isDarkMode ? Colors.white : Colors.black87,
             fontWeight: FontWeight.bold,
             fontSize: 16
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0 
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black87),
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              )
            )
          : null,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Evitar swipe manual para obligar a contestar
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: [
          // Paso 1: Swipe (Tinder-style)
          PasoIdentificacion(
            onCompleted: (resultados) {
              _respuestas['identificacion'] = resultados;
              _nextPage();
            },
          ),
          
          // Paso 2: Preferencias y Gustos (NUEVO)
          PasoPreferencias(
            onCompleted: (resultados) {
              print("Guatemal: $resultados");
              _respuestas['preferencias'] = resultados;
              _nextPage();
            },
          ),
          
          // Paso 3: Escala de Gravedad Suicida
          PasoEscalaSuicida(
            onCompleted: (resultados) {
              _respuestas['escala_suicida'] = resultados;
              _nextPage();
            },
          ),
          
          // Paso 4: Escritura
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
    );
  }
}