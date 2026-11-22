import 'package:flutter_test/flutter_test.dart';
import 'package:neon_xo_admin/main.dart';

void main() {
  testWidgets('NEON XO Admin login screen test',
          (WidgetTester tester) async {
        await tester.pumpWidget(const NeonXOAdminApp());

        expect(find.text('NEON XO'), findsOneWidget);
        expect(find.text('ADMIN PANEL'), findsOneWidget);
        expect(find.text('ADMIN LOGIN'), findsOneWidget);
      });
}