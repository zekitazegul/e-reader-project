import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/reading_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets('Font and paper choices update the reading preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(settingsOnly: true, store: DeviceReadingStore()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Literata'));
    await tester.pumpAndSettle();
    expect((await DeviceReadingStore().settings()).font, 'Literata');
    await tester.ensureVisible(find.text('Gece'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gece'));
    await tester.pump();
    expect((await DeviceReadingStore().settings()).paper, 'night');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reader fits a narrow phone screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: ReaderPage(store: DeviceReadingStore())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
