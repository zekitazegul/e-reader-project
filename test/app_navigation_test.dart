import 'package:e_reader/app_chrome.dart';
import 'package:e_reader/app_navigation.dart';
import 'package:e_reader/book_opening_splash.dart';
import 'package:e_reader/library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'library_view_test.dart' show LiveBookStore;

class _StartupProbe extends StatefulWidget {
  const _StartupProbe({required this.onStart});
  final VoidCallback onStart;
  @override
  State<_StartupProbe> createState() => _StartupProbeState();
}

class _StartupProbeState extends State<_StartupProbe> {
  @override
  void initState() {
    super.initState();
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Library'));
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  testWidgets('Phone menu and bottom navigation reach library shortcuts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(338, 730);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LiveBookStore();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigation.instance.navigatorKey,
        builder: (_, child) => AppChrome(child: child!),
        home: LibraryPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    AppNavigation.instance.fullscreen.value = true;
    await tester.pump();
    expect(find.byKey(const ValueKey('app-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-left-menu')), findsOneWidget);
    AppNavigation.instance.fullscreen.value = false;
    await tester.pump();
    expect(find.text('Bir kitap seç. Yeni bir dünyaya açıl.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('library-menu')));
    await tester.pumpAndSettle();
    for (final label in [
      'Kütüphanem',
      'Kitap ekle',
      'Okuma ayarları',
      'Diğer uygulamalarım',
      'Destek',
      'Uygulamayı güncelle',
      'Uygulamayı paylaş',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Kütüphanem'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-row-First.epub')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('app-left-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Destek'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-left-menu')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Destek'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Destek'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-left-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Destek'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-home')));
    await tester.pumpAndSettle();
    expect(find.text('Destek'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-left-menu')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Diğer uygulamalarım'));
    await tester.tap(find.text('Diğer uygulamalarım'));
    await tester.pumpAndSettle();
    expect(find.text('Cevşen'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-menu')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await store.notifications.close();
  });
  testWidgets('Opening book finishes once and respects reduced motion', (
    tester,
  ) async {
    var starts = 0;
    Widget app({bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: BookOpeningSplash(child: _StartupProbe(onStart: () => starts++)),
      ),
    );
    await tester.pumpWidget(app());
    expect(find.byKey(const ValueKey('opening-red-book')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      starts,
      1,
      reason: 'Completing the splash must retain the live home state',
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AbsorbPointer && widget.absorbing,
      ),
      findsNothing,
    );
    await tester.pumpWidget(app());
    expect(find.byKey(const ValueKey('opening-red-book')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(reduced: true));
    expect(find.byKey(const ValueKey('opening-red-book')), findsNothing);
  });
}
