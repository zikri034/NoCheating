import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/core/widgets/neo_bottom_nav.dart';

void main() {
  testWidgets('NeoBottomNav displays all 5 tabs and handles taps', (WidgetTester tester) async {
    int selectedIndex = 0;
    bool logoutTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: NeoBottomNav(
            currentIndex: selectedIndex,
            onTap: (index) => selectedIndex = index,
            onLogoutTap: () => logoutTriggered = true,
          ),
        ),
      ),
    );

    // Verify all 5 items are present in exact PRD order
    expect(find.text('BERANDA'), findsOneWidget);
    expect(find.text('UJIAN'), findsOneWidget);
    expect(find.text('PROFIL'), findsOneWidget);
    expect(find.text('SARAN'), findsOneWidget);
    expect(find.text('LOGOUT'), findsOneWidget);

    // Tap on UJIAN (index 1)
    await tester.tap(find.text('UJIAN'));
    expect(selectedIndex, 1);

    // Tap on PROFIL (index 2)
    await tester.tap(find.text('PROFIL'));
    expect(selectedIndex, 2);

    // Tap on LOGOUT
    await tester.tap(find.text('LOGOUT'));
    expect(logoutTriggered, true);
  });
}
