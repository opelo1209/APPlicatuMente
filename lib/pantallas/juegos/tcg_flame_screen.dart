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
    await player.setAsset( 'assets/musica/tcg/The_Keeper_s_Ledger.mp3');
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
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_GameMenuAction.toggleSound),
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
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_GameMenuAction.continueGame),
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  title: const Text(
                    'Salir de la partida',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => {
                    player.stop(),
                    Navigator.of(context).pop(_GameMenuAction.exitGame)},
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
      body: GameWidget<MentalTcgGame>(
        game: _game,
        overlayBuilderMap: {
          'hud': (context, game) {
            return SafeArea(
              child: Padding(
              padding: const EdgeInsets.only(top: 35, left: 28, right: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _openGameMenu,
                        tooltip: 'Menu',
                        icon: const Icon(Icons.menu_rounded),
                        color: Colors.white,
                        iconSize: 26,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: game.resetMatch,
                        tooltip: 'Reiniciar',
                        icon: const Icon(Icons.refresh_rounded),
                        color: Colors.white,
                        iconSize: 26,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          'preview': (context, game) {
            return ValueListenableBuilder<String?>(
              valueListenable: game.previewArtPath,
              builder: (context, imagePath, child) {
                if (imagePath == null) {
                  return const SizedBox.shrink();
                }

                return GestureDetector(
                  onTap: game.hideCardPreview,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.72),
                    child: Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.82,
                        constraints: const BoxConstraints(maxWidth: 360),
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
        initialActiveOverlays: const ['hud', 'preview'],
      ),
    );
  }
}