import 'dart:convert';
import 'dart:io';

import 'package:e_reader/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class CatalogDelegate extends LocalizationsDelegate<AppTranslations> {
  const CatalogDelegate();
  @override
  bool isSupported(Locale locale) =>
      appLanguages.containsKey(locale.languageCode);
  @override
  Future<AppTranslations> load(Locale locale) => SynchronousFuture(
    AppTranslations(
      locale.languageCode,
      (jsonDecode(
        File('assets/i18n/${locale.languageCode}.json').readAsStringSync(),
      ) as Map).cast<String, String>(),
    ),
  );
  @override
  bool shouldReload(CatalogDelegate old) => false;
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  Map<String, String> catalog(String code) =>
      (jsonDecode(File('assets/i18n/$code.json').readAsStringSync()) as Map)
          .cast<String, String>();
  test('Book editing and details use the actual Unicode source labels', () {
    final english = AppTranslations('en', catalog('en'));
    final dutch = AppTranslations('nl', catalog('nl'));
    expect(english.translate('Kitabı düzenle'), 'Edit book');
    expect(
      english.translate('Kitap adı boş bırakılamaz.'),
      'The book title cannot be empty.',
    );
    expect(english.translate('Sayfa sayısı'), 'Page count');
    expect(dutch.translate('Kitabı düzenle'), 'Boek bewerken');
    expect(dutch.translate('Henüz hesaplanmadı'), 'Nog niet berekend');
  });
  test(
    'Every offered language has all UI messages and matching placeholders',
    () {
      final source = catalog('tr');
      final tokens = RegExp(r'\{\d+\}');
      for (final code in appLanguages.keys) {
        final translated = catalog(code);
        expect(translated.keys.toSet(), source.keys.toSet(), reason: code);
        for (final entry in source.entries) {
          expect(
            translated[entry.key]!.trim(),
            isNotEmpty,
            reason: '$code / ${entry.key}',
          );
          expect(
            tokens.allMatches(translated[entry.key]!).map((m) => m[0]).toList()
              ..sort(),
            tokens.allMatches(entry.key).map((m) => m[0]).toList()..sort(),
            reason: '$code / ${entry.key}',
          );
        }
      }
    },
  );
  test('Translated templates keep variable book titles and numbers intact', () {
    final english = AppTranslations('en', catalog('en'));
    expect(english.translate('Sayfa 17'), 'Page 17');
    expect(english.translate('Lemalar — Sayfa 17'), 'Lemalar — Page 17');
    expect(english.translate('2 / 12 kitap'), '2 / 12 books');
    expect(english.translate('Original book content'), 'Original book content');
  });
  Widget frame(LanguageController controller, {String? language}) =>
      LanguageScope(
        controller: controller,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MaterialApp(
            locale: Locale(language ?? controller.code),
            supportedLocales: [
              for (final code in appLanguages.keys) Locale(code),
            ],
            localizationsDelegates: const [
              CatalogDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FirstLaunchLanguage(
              child: Scaffold(
                body: Column(
                  children: [AppText('Kitaplığım'), AppText('Yükleniyor')],
                ),
              ),
            ),
          ),
        ),
      );
  testWidgets('First launch asks once and restores the saved language', (
    tester,
  ) async {
    final first = LanguageController();
    await first.restore();
    await tester.pumpWidget(frame(first));
    await tester.pumpAndSettle();
    expect(find.text('Dil seçin / Choose your language'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('My library'), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
    final restored = LanguageController();
    await restored.restore();
    expect(restored.code, 'en');
    expect(restored.hasSelection, isTrue);
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    await tester.pumpWidget(frame(restored));
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.text('My library'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    restored.dispose();
  });
  for (final code in ['tr', 'en', 'uk', 'ru', 'es', 'zh', 'hi', 'ar']) {
    testWidgets('$code renders native controls and correct layout direction', (
      tester,
    ) async {
      final controller = LanguageController();
      await controller.restore();
      await controller.select(code);
      await tester.pumpWidget(frame(controller));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(catalog(code)['Kitaplığım']!),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '),
      );
      final element = tester.element(find.byType(Column));
      expect(
        Directionality.of(element),
        code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
