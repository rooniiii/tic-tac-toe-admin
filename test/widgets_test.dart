import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neon_xo_admin/theme/app_theme.dart';
import 'package:neon_xo_admin/widgets/change_password_dialog.dart';
import 'package:neon_xo_admin/widgets/load_more_button.dart';
import 'package:neon_xo_admin/widgets/simple_charts.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('ChangePasswordDialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ChangePasswordDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, String current, String next,
        String confirm) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), current);
      await tester.enterText(fields.at(1), next);
      await tester.enterText(fields.at(2), confirm);
      await tester.tap(find.text('CHANGE'));
      await tester.pumpAndSettle();
    }

    testWidgets('requires the current password', (tester) async {
      await openDialog(tester);
      await fill(tester, '', 'NewPass1!', 'NewPass1!');
      expect(find.text('Enter your current password'), findsOneWidget);
    });

    testWidgets('enforces the password rules', (tester) async {
      await openDialog(tester);

      await fill(tester, 'old', 'short', 'short');
      expect(find.text('At least 8 characters'), findsOneWidget);

      await fill(tester, 'old', 'lowercase1!', 'lowercase1!');
      expect(find.text('Add an uppercase letter'), findsOneWidget);

      await fill(tester, 'old', 'NoNumber!!', 'NoNumber!!');
      expect(find.text('Add a number'), findsOneWidget);

      await fill(tester, 'old', 'NoSpecial12', 'NoSpecial12');
      expect(find.text('Add a special character'), findsOneWidget);
    });

    testWidgets('confirmation must match', (tester) async {
      await openDialog(tester);
      await fill(tester, 'old', 'NewPass1!', 'NewPass2!');
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('cancel closes the dialog', (tester) async {
      await openDialog(tester);
      expect(find.text('Change my password'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('Change my password'), findsNothing);
    });
  });

  group('LoadMoreButton', () {
    testWidgets('shows the count, the hint and calls back', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(_app(LoadMoreButton(
        shown: 25,
        hint: 'Search only covers loaded players.',
        onPressed: () => pressed++,
      )));

      expect(find.text('Showing the first 25'), findsOneWidget);
      expect(find.text('Search only covers loaded players.'), findsOneWidget);
      await tester.tap(find.text('Load more'));
      expect(pressed, 1);
    });
  });

  group('Charts', () {
    testWidgets('bar chart with no games shows a message', (tester) async {
      await tester.pumpWidget(_app(const VerticalBarChart(
        labels: ['Mon', 'Tue'],
        values: [0, 0],
      )));
      expect(find.text('No games in this period.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bar chart and ratio bar render data', (tester) async {
      await tester.pumpWidget(_app(const Column(
        children: [
          VerticalBarChart(labels: ['Mon', 'Tue', 'Wed'], values: [3, 0, 7]),
          StackedRatioBar(segments: [
            ChartSegment('Wins', 6, Colors.green),
            ChartSegment('Losses', 2, Colors.red),
          ]),
          HorizontalBarList(
            labels: ['Ali', 'Sara'],
            values: [12, 4],
            unit: 'games',
          ),
        ],
      )));
      expect(find.text('Mon'), findsOneWidget);
      expect(find.textContaining('Wins'), findsWidgets);
      expect(find.text('1. Ali'), findsOneWidget);
      expect(find.text('12games'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
