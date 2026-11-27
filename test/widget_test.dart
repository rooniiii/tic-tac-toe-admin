import 'package:flutter_test/flutter_test.dart';

import 'package:neon_xo_admin/main.dart';
import 'package:neon_xo_admin/screen/admin_login_screen.dart';

/// Smoke test of the real app (theme, title) with the login screen, which
/// does not need Firebase until the admin actually logs in.
void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      NeonXOAdminApp(home: AdminLoginScreen(onLoginSuccess: () {})),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('NEON XO Admin shows the login screen', (tester) async {
    await pumpLogin(tester);

    expect(find.text('NEON XO'), findsOneWidget);
    expect(find.text('ADMIN PANEL'), findsOneWidget);
    expect(find.text('ADMIN LOGIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty login is rejected before contacting Firebase',
      (tester) async {
    await pumpLogin(tester);

    final button = find.text('ADMIN LOGIN');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
