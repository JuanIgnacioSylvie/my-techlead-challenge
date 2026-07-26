import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';
import 'package:mobile/presentation/login/login_screen.dart';

void main() {
  testWidgets('La app arranca mostrando la pantalla de login', (tester) async {
    await tester.pumpWidget(const App());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('El login valida campos vacíos antes de llamar a la API',
      (tester) async {
    await tester.pumpWidget(const App());

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresá tu usuario'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña'), findsOneWidget);
  });
}
