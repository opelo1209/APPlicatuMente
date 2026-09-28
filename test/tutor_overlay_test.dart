import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptm/pantallas/juegos/tutorial/tutor_definitions.dart';
import 'package:aptm/pantallas/juegos/tutorial/tutor_overlay.dart';
import 'package:aptm/pantallas/juegos/tutorial/tutor_service.dart';

// La pantalla del TCG monta el tutorial como hijo directo de un Stack, encima
// del tablero. Se reproduce esa misma estructura: si el panel vuelve a usar
// un Positioned que no sea hijo directo del Stack, Flutter lanza "Incorrect
// use of ParentDataWidget" y, en release, tapa todo el tablero con el
// recuadro gris de error.
Widget _pantallaConTutorial(TutorService servicio) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          const SizedBox.expand(key: ValueKey('tablero')),
          // La pantalla real reconstruye el overlay con setState cada vez que
          // el servicio avisa un cambio; aquí se hace con ListenableBuilder.
          ListenableBuilder(
            listenable: servicio,
            builder: (context, _) => TutorOverlay(
              service: servicio,
              onSkip: servicio.skip,
              onNext: servicio.nextStep,
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('el panel del tutorial se dibuja dentro del Stack sin errores', (
    tester,
  ) async {
    final servicio = TutorService()..start(createTutorialSteps());

    await tester.pumpWidget(_pantallaConTutorial(servicio));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bienvenido al TCG Salud Mental'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);
  });

  testWidgets('el panel queda arriba y no cubre el tablero completo', (
    tester,
  ) async {
    final servicio = TutorService()..start(createTutorialSteps());

    await tester.pumpWidget(_pantallaConTutorial(servicio));
    await tester.pumpAndSettle();

    final pantalla = tester.getSize(find.byType(Scaffold));
    final panel = tester.getRect(find.byType(Material).last);
    expect(panel.top, lessThan(pantalla.height * 0.2));
    expect(panel.height, lessThan(pantalla.height / 2));
  });

  testWidgets('avanzar de paso sigue sin errores durante la transición', (
    tester,
  ) async {
    final servicio = TutorService()..start(createTutorialSteps());

    await tester.pumpWidget(_pantallaConTutorial(servicio));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Tus cartas están aquí abajo'), findsOneWidget);
  });
}
