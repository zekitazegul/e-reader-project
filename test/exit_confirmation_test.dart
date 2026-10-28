import 'package:e_reader/exit_confirmation.dart';
import 'package:e_reader/app_chrome.dart';
import 'package:e_reader/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Back asks before exiting and cancel keeps app open', (
    tester,
  ) async {
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigation.instance.navigatorKey,
        builder: (_, child) => AppChrome(child: child!),
        home: const ExitConfirmation(child: Scaffold(body: Text('Library'))),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('app-back')));
    await tester.pumpAndSettle();
    expect(find.text('Çıkış?'), findsOneWidget);
    expect(exits, 0);
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(exits, 1);
  });
}
