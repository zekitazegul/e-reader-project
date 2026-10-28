import 'dart:typed_data';

import 'package:e_reader/book_store.dart';
import 'package:e_reader/book_suggestions.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/library.dart';
import 'package:e_reader/text_direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MultilingualStore extends BookStore {
  @override
  Future<String> location() async => 'test';
  @override
  Future<List<BookFile>> scan() async => [
    BookFile('The_Count_of_Monte_Cristo.epub', Uint8List(0)),
    BookFile('Преступление_и_наказание.epub', Uint8List(0)),
    BookFile('الْكُونْت_دِي_مُونْت_كْرِيسْتُو.epub', Uint8List(0)),
  ];
}

void main() {
  test('Suggests corrected titles and rejects unrelated or short queries', () {
    expect(
      suggestBooks('Montr Ktisto kontu').first.title,
      'Monte Kristo Kontu',
    );
    expect(suggestBooks('Savas ve Baris').first.title, 'Savaş ve Barış');
    expect(suggestBooks('Граф Монте Кристо').first.title, 'Monte Kristo Kontu');
    expect(
      suggestBooks('الْكُونْت دِي مُونْت كْرِيسْتُو').first.title,
      'Monte Kristo Kontu',
    );
    expect(suggestBooks('bilinmeyen bir uzay kitabı'), isEmpty);
    expect(suggestBooks('mon'), isEmpty);
    expect(suggestBooks(''), isEmpty);
    expect(suggestBooks('Denoz', localTitles: ['Deniz']).first.title, 'Deniz');
  });

  test('Normalizes Turkish, Russian and Arabic marks without transliterating titles', () {
    expect(normalizeTitle('İSTANBUL Çığ ŞÜKRÜ'), 'istanbul cig sukru');
    expect(normalizeTitle('ВСЁ'), 'все');
    expect(normalizeTitle('الْكِتَــاب'), 'الكتاب');
    expect(normalizeTitle('إلى'), normalizeTitle('الي'));
    expect(directionForText('123 — الكونت'), TextDirection.rtl);
    expect(directionForText('Граф Монте-Кристо'), TextDirection.ltr);
    expect(directionForText('阅读 مرحبًا'), TextDirection.ltr);
    expect(directionForText('Ελλάδα مرحبًا'), TextDirection.ltr);
    expect(directionForText('שלום hello'), TextDirection.rtl);
    expect(
      matchesLibraryTitle('The Count of Monte Cristo', 'Monte Kristo Kontu'),
      isTrue,
    );
    expect(
      matchesLibraryTitle('Преступление и наказание', 'Suç ve Ceza'),
      isTrue,
    );
  });

  testWidgets('Library displays multilingual titles without search controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: LibraryPage(store: MultilingualStore())),
    );
    await tester.pumpAndSettle();
    expect(find.text('The Count of Monte Cristo'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Bunu mu aradın?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
