import 'package:e_reader/directional_pager.dart';
import 'package:e_reader/reading_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'An established axis follows the finger without waiting for a frame',
    (tester) async {
      final controller = PageController(initialPage: 2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectionalPager(
              controller: controller,
              builder: (axis) => PageView.builder(
                controller: controller,
                scrollDirection: axis,
                physics: const NeverScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                itemCount: 10,
                itemBuilder: (_, i) => Text('$i'),
              ),
            ),
          ),
        ),
      );
      final before = controller.offset;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(-25, 1));
      await gesture.moveBy(const Offset(-5, 0));
      expect(controller.offset, greaterThan(before));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  test('Compact spacing replaces the old default but keeps custom spacing', () {
    expect(const ReadingSettings().lineHeight, 1.15);
    expect(
      ReadingSettings.fromJson({'lineHeight': 1.3, 'spacingVersion': 2})
          .lineHeight,
      1.15,
    );
    expect(
      ReadingSettings.fromJson(const ReadingSettings(lineHeight: 1.0).toJson())
          .lineHeight,
      1.0,
    );
    expect(ReadingSettings.fromJson({'lineHeight': 1.75}).lineHeight, 1.15);
    expect(ReadingSettings.fromJson({'lineHeight': 1.5}).lineHeight, 1.5);
    expect(
      ReadingSettings.fromJson(const ReadingSettings(lineHeight: 1.75).toJson())
          .lineHeight,
      1.75,
    );
  });

  for (final size in [const Size(360, 640), const Size(800, 360)]) {
    for (final sideways in [-1.0, 1.0]) {
      testWidgets('Vertical drag ignores sideways jitter $sideways at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = PageController(initialPage: 2);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DirectionalPager(
                controller: controller,
                builder: (axis) => PageView.builder(
                  controller: controller,
                  scrollDirection: axis,
                  physics: const NeverScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  itemCount: 20,
                  itemBuilder: (_, index) => Center(child: Text('$index')),
                ),
              ),
            ),
          ),
        );
        final view = find.byType(PageView);
        final gesture = await tester.startGesture(tester.getCenter(view));
        for (final delta in [
          Offset(sideways * 12, -2),
          Offset(sideways * 6, -20),
          const Offset(1, -35),
          Offset(sideways * 35, -8),
        ]) {
          await gesture.moveBy(delta);
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.widget<PageView>(view).scrollDirection, Axis.vertical);
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(1, -35));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.page, greaterThan(2));
        final previous = controller.page!;
        await tester.drag(view, Offset(-size.width * .7, 3));
        await tester.pumpAndSettle();
        expect(tester.widget<PageView>(view).scrollDirection, Axis.horizontal);
        expect(controller.page, greaterThan(previous));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      });
    }
  }
}
