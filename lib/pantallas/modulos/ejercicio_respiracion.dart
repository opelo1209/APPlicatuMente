import 'package:flutter/material.dart';

class EjercicioRespiracion extends StatefulWidget {
  const EjercicioRespiracion({super.key});

  @override
  State<EjercicioRespiracion> createState() => _EjercicioRespiracionState();
}

class _EjercicioRespiracionState extends State<EjercicioRespiracion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _cicloActual = 1;
  static const int _totalCiclos = 4;
  bool _completado = false;

  static const double _inhaleEnd = 0.25;
  static const double _holdEnd = 0.50;
  static const double _exhaleEnd = 0.75;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    _controller.addListener(_onTick);
    _controller.addStatusListener(_onStatusChange);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.removeStatusListener(_onStatusChange);
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    setState(() {});
  }

  void _onStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (_cicloActual < _totalCiclos) {
        _cicloActual++;
        _controller.reset();
        _controller.forward();
      } else {
        setState(() => _completado = true);
      }
    }
  }

  FaseRespiracion get _faseActual {
    final v = _controller.value;
    if (v < _inhaleEnd) return FaseRespiracion.inhalar;
    if (v < _holdEnd) return FaseRespiracion.retener;
    if (v < _exhaleEnd) return FaseRespiracion.exhalar;
    return FaseRespiracion.pausar;
  }

  double get _escala {
    final v = _controller.value;
    switch (_faseActual) {
      case FaseRespiracion.inhalar:
        return 0.3 + (v / _inhaleEnd) * 0.7;
      case FaseRespiracion.retener:
        return 1.0;
      case FaseRespiracion.exhalar:
        return 1.0 - ((v - _holdEnd) / (_exhaleEnd - _holdEnd)) * 0.7;
      case FaseRespiracion.pausar:
        return 0.3;
    }
  }

  String get _textoFase {
    switch (_faseActual) {
      case FaseRespiracion.inhalar:
        return 'Inhalá lentamente\npor la nariz';
      case FaseRespiracion.retener:
        return 'Mantené el aire';
      case FaseRespiracion.exhalar:
        return 'Exhalá con calma';
      case FaseRespiracion.pausar:
        return 'Esperá sin aire';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: _completado ? _buildCompletado() : _buildEjercicio(),
    );
  }

  Widget _buildEjercicio() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Respirá un minuto',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Transform.scale(
                      scale: _escala,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF42A5F5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF42A5F5).withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _textoFase,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  Text(
                    'Ciclo $_cicloActual de $_totalCiclos',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalCiclos, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _cicloActual
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletado() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Muy bien!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Completaste el ejercicio\nde respiración.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 18,
                height: 1.5,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum FaseRespiracion { inhalar, retener, exhalar, pausar }
