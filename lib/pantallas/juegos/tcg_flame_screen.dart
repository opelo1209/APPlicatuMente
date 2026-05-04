import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'tcg_flame_game.dart';

import 'package:just_audio/just_audio.dart';

enum _GameMenuAction { toggleSound, continueGame, exitGame }

class TcgFlameScreen extends StatefulWidget {
  const TcgFlameScreen({super.key});
  @override
  State<TcgFlameScreen> createState() => _TcgFlameScreenState();
}

class _TcgFlameScreenState extends State<TcgFlameScreen> {
  late final MentalTcgGame _game;
  bool _soundEnabled = true;
  late final AudioPlayer player;

  @override
  void initState() {
    super.initState();
    _game = MentalTcgGame();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    player = AudioPlayer();
    await player.setAsset('assets/musica/tcg/The_Keeper_s_Ledger.mp3');
    player.setLoopMode(LoopMode.all);
    player.play();
  }

  Future<void> _openGameMenu() async {
    _game.pauseEngine();

    final action = await showModalBottomSheet<_GameMenuAction>(
      context: context,
      backgroundColor: const Color(0xFF17221E).withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    _soundEnabled
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    _soundEnabled ? 'Quitar sonido' : 'Activar sonido',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_GameMenuAction.toggleSound),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Continuar partida',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_GameMenuAction.continueGame),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.exit_to_app,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Salir de la partida',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => {
                    player.stop(),
                    Navigator.of(context).pop(_GameMenuAction.exitGame),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (action == null || action == _GameMenuAction.continueGame) {
      _game.resumeEngine();
      return;
    }

    if (action == _GameMenuAction.toggleSound) {
      setState(() {
        _soundEnabled = !_soundEnabled;
        if (_soundEnabled) {
          player.play();
        } else {
          player.pause();
        }
      });
      _game.resumeEngine();
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 121, 185, 121), // Fondo color verde salvia para ocultar las esquinas grises
      body: SafeArea(
        child: Column(
          children: [
            // 1. COMPONENTE 1: La Barra de Estado de Juego
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 78, 120, 82), // Verde Musgo Profundo
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border.all(color: const Color(0xFF3B5E40), width: 1.5), // Bisel sutil madera/metal (Ajustado)
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF28402C).withValues(alpha: 0.45), // Sombra ajustada al nuevo tono
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // MENU
                      GestureDetector(
                        onTap: _openGameMenu,
                        behavior: HitTestBehavior.opaque,
                        child: Semantics(
                          label: 'Menú',
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.menu_rounded,
                                  size: 26,
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                                const Icon(
                                  Icons.menu_rounded,
                                  size: 24,
                                  color: Color(0xFFF3E5AB), // Ocre suave/Crema
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // BARRA CENTRAL DE ESTADO (PUNTOS Y ELIXIR)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ValueListenableBuilder<int>(
                            valueListenable: _game.playerHpNotifier,
                            builder: (context, playerHp, _) {
                              return ValueListenableBuilder<int>(
                                valueListenable: _game.bossHpNotifier,
                                builder: (context, bossHp, _) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: _game.manaNotifier,
                                    builder: (context, mana, _) {
                                      return ValueListenableBuilder<int>(
                                        valueListenable: _game.manaCapNotifier,
                                        builder: (context, manaCap, _) {
                                          return ValueListenableBuilder<int>(
                                            valueListenable:
                                                _game.bossManaNotifier,
                                            builder: (context, bossMana, _) {
                                              return ValueListenableBuilder<
                                                int
                                              >(
                                                valueListenable:
                                                    _game.bossManaCapNotifier,
                                                builder: (context, bossManaCap, _) {
                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.favorite_rounded, color: Color(0xFFA8D5BA), size: 16), // Verde menta
                                                              const SizedBox(width: 6),
                                                              Row(
                                                                children: List.generate(10, (index) {
                                                                  final blocksActive = (playerHp / 25 * 10).ceil();
                                                                  final isActive = index < blocksActive;
                                                                  return Container(
                                                                    width: 4, // Reducido para evitar overflow
                                                                    height: 10,
                                                                    margin: const EdgeInsets.only(right: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: isActive ? const Color(0xFFA8D5BA) : const Color(0xFF28402C).withValues(alpha: 0.6),
                                                                      borderRadius: BorderRadius.circular(5), // Completamente ovalado
                                                                      boxShadow: isActive ? [
                                                                        BoxShadow(
                                                                          color: const Color(0xFFA8D5BA).withValues(alpha: 0.4),
                                                                          blurRadius: 2,
                                                                          offset: const Offset(0, 0),
                                                                        )
                                                                      ] : null,
                                                                    ),
                                                                  );
                                                                }),
                                                              ),
                                                            ],
                                                          ),
                                                          Text(
                                                            'Bienestar',
                                                            style: TextStyle(
                                                              color: const Color(0xFFCFD8DC).withValues(alpha: 0.9), // Gris verdoso claro/Beige
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 15,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                          Row(
                                                            children: [
                                                              Row(
                                                                children: List.generate(10, (index) {
                                                                  final blocksActive = (bossHp / 25 * 10).ceil();
                                                                  final isActive = index < blocksActive;
                                                                  return Container(
                                                                    width: 4, // Reducido para evitar overflow
                                                                    height: 10,
                                                                    margin: const EdgeInsets.only(right: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: isActive ? const Color(0xFFD87D2F) : const Color(0xFF28402C).withValues(alpha: 0.6),
                                                                      borderRadius: BorderRadius.circular(5), // Completamente ovalado
                                                                      boxShadow: isActive ? [
                                                                        BoxShadow(
                                                                          color: const Color(0xFFD87D2F).withValues(alpha: 0.4),
                                                                          blurRadius: 2,
                                                                          offset: const Offset(0, 0),
                                                                        )
                                                                      ] : null,
                                                                    ),
                                                                  );
                                                                }),
                                                              ),
                                                              const SizedBox(width: 6),
                                                              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFD87D2F), size: 16), // Coral terracota
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      // BARRA DE ELIXIR ESTILO VECTOR MINIMALISTA
                                                      Container(
                                                        height: 14,
                                                        padding: const EdgeInsets.all(2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Row(
                                                          children: List.generate(_game.maxManaPerTurn, (index) {
                                                            final isUnlocked = index < manaCap;
                                                            final isAvailable = index < mana;
                                                            const activeColor = Color(0xFF66BB6A); // Verde natural/curativo
                                                            
                                                            return Expanded(
                                                              child: Container(
                                                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                                decoration: BoxDecoration(
                                                                  color: isAvailable
                                                                      ? activeColor
                                                                      : (isUnlocked ? Colors.black26 : Colors.black12),
                                                                  border: Border.all(
                                                                    color: isAvailable
                                                                        ? activeColor.withValues(alpha: 0.5)
                                                                        : Colors.black12,
                                                                    width: 1.0,
                                                                  ),
                                                                  borderRadius: BorderRadius.circular(4),
                                                                ),
                                                              ),
                                                            );
                                                          }),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      // REINICIAR
                      GestureDetector(
                        onTap: () {
                          _game.resetMatch();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Semantics(
                          label: 'Reiniciar',
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 26,
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                                const Icon(
                                  Icons.refresh_rounded,
                                  size: 24,
                                  color: Color(0xFFF3E5AB), // Ocre suave/Crema
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. COMPONENTE 2: El Tablero del Juego (Flame)
            Expanded(
              child: Stack(
                children: [
                  GameWidget<MentalTcgGame>(
                    game: _game,
                    overlayBuilderMap: {
                      'preview': (context, game) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: game.previewArtPath,
                          builder: (context, imagePath, child) {
                            if (imagePath == null)
                              return const SizedBox.shrink();
                            return GestureDetector(
                              onTap: game.hideCardPreview,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.72),
                                child: Center(
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width *
                                        0.82,
                                    constraints: const BoxConstraints(
                                      maxWidth: 360,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black54,
                                          blurRadius: 20,
                                          offset: Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.asset(
                                        imagePath,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    },
                    initialActiveOverlays: const ['preview'],
                  ),

                  // MENSAJES / INDICACIONES FLOTANTES (MODAL CENTRADO)
                  Positioned.fill(
                    child: Center(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<String>(
                          valueListenable: _game.hintTextNotifier,
                          builder: (context, hint, _) {
                            if (hint.isEmpty) return const SizedBox.shrink();

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: hint.split('\n').map((line) {
                                  List<TextSpan> spans = [];
                                  List<String> words = line.split(' ');
                                  for (String word in words) {
                                    Color color = Colors.white;
                                    if (word == 'Tú:')
                                      color = const Color.fromARGB(
                                        255,
                                        121,
                                        185,
                                        231,
                                      );
                                    else if (word == 'Boss:')
                                      color = Colors.redAccent;
                                    else if (word.contains('Daño') ||
                                        int.tryParse(word) != null)
                                      color = Colors.orangeAccent;
                                    else if (word.contains('(x'))
                                      color = Colors.greenAccent;
                                    else if (word.contains('¡Ganaste!') ||
                                        word.contains('Perdiste'))
                                      color = Colors.amberAccent;

                                    spans.add(
                                      TextSpan(
                                        text: '$word ',
                                        style: TextStyle(color: color),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2.0,
                                    ),
                                    child: RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'sans-serif',
                                        ),
                                        children: spans,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // BOTON RENDONDO PARA FINALIZAR TURNO (INFERIOR DERECHO)
                  Positioned(
                    bottom: 24,
                    right: 20,
                    child: Semantics(
                      label: 'Jugar cartas',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF28402C).withValues(alpha: 0.5), // Sombra ajustada
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FloatingActionButton(
                          mini: true,
                          heroTag: 'btn_pass_turn',
                          backgroundColor: const Color(0xFFD87D2F), // Naranja Terracota / Ocre
                          foregroundColor: const Color(0xFFFFE0B2), // Ocre más claro
                          elevation: 0,
                          highlightElevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onPressed: () {
                            if (!_game.isFinished) {
                              _game.passTurn();
                            }
                          },
                          child: const Icon(
                            Icons.double_arrow_rounded,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
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
