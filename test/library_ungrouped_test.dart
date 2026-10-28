import 'dart:convert';
import 'dart:typed_data';

import 'package:e_reader/books.dart';
import 'package:e_reader/library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'library_view_test.dart' show LiveBookStore;

void main() {
  testWidgets(
    'Previously grouped books appear on the main shelf without grouping controls',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final store = LiveBookStore();
      addTearDown(store.notifications.close);
      final book = BookFile('Alpha.pdf', Uint8List.fromList([1]));
      store.entries
        ..clear()
        ..add(book);
      await SharedPreferencesAsync().setString(
        'library.groups.v1',
        jsonEncode({
          'names': {'old-group': 'RNK'},
          'members': {bookFingerprint(book.bytes): 'old-group'},
        }),
      );
      await tester.pumpWidget(MaterialApp(home: LibraryPage(store: store)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('library-cover-Alpha.pdf')),
        findsOneWidget,
      );
      expect(find.text('RNK'), findsNothing);
      expect(find.byType(LongPressDraggable<BookFile>), findsNothing);
      expect(find.byType(DragTarget<BookFile>), findsNothing);
      expect(find.byKey(const ValueKey('library-create-group')), findsNothing);
      await tester.longPress(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('Kitap bilgileri'), findsOneWidget);
      expect(find.text('Gruba taşı'), findsNothing);
      expect(find.text('Üst rafa koy'), findsOneWidget);
      expect(find.text('Kitaplıktan kaldır'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
