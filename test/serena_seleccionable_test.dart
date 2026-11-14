// Semana 8: los mensajes de Serena se pueden seleccionar y copiar, para
// compartir lo que respondió al revisarla.
import 'package:aptm/pantallas/diario/aviso_confianza.dart';
import 'package:aptm/pantallas/modulos/chatbot_serena.dart';
import 'package:aptm/pantallas/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('los mensajes del chat quedan dentro de un área seleccionable', (
    tester,
  ) async {
    // Arrange: el aviso de confianza ya se vio, para que no tape el chat.
    SharedPreferences.setMockInitialValues({claveAvisoConfianza: true});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(home: Scaffold(body: ChatbotSerena())),
      ),
    );

    // Act: sin servidor, la verificación de conexión falla y el chat abre igual.
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // Assert
    final bienvenida = find.textContaining('Soy Serena');
    expect(bienvenida, findsOneWidget);
    expect(
      find.ancestor(of: bienvenida, matching: find.byType(SelectionArea)),
      findsOneWidget,
    );
  });
}
