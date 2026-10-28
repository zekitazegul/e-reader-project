import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appLanguages = <String, String>{
  'tr': 'Türkçe',
  'en': 'English',
  'uk': 'Українська',
  'ru': 'Русский',
  'es': 'Español',
  'de': 'Deutsch',
  'fr': 'Français',
  'it': 'Italiano',
  'pt': 'Português',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'cs': 'Čeština',
  'sk': 'Slovenčina',
  'sl': 'Slovenščina',
  'hr': 'Hrvatski',
  'bs': 'Bosanski',
  'sr': 'Српски',
  'bg': 'Български',
  'ro': 'Română',
  'hu': 'Magyar',
  'el': 'Ελληνικά',
  'sq': 'Shqip',
  'mk': 'Македонски',
  'be': 'Беларуская',
  'lt': 'Lietuvių',
  'lv': 'Latviešu',
  'et': 'Eesti',
  'fi': 'Suomi',
  'sv': 'Svenska',
  'no': 'Norsk',
  'da': 'Dansk',
  'is': 'Íslenska',
  'ga': 'Gaeilge',
  'cy': 'Cymraeg',
  'ca': 'Català',
  'eu': 'Euskara',
  'gl': 'Galego',
  'az': 'Azərbaycan',
  'hy': 'Հայերեն',
  'ka': 'ქართული',
  'zh': '中文',
  'hi': 'हिन्दी',
  'ar': 'العربية',
  'he': 'עברית',
  'ja': '日本語',
  'ko': '한국어',
  'id': 'Bahasa Indonesia',
  'fa': 'فارسی',
};

class LanguageController extends ChangeNotifier {
  static const preferenceKey = 'e_reader.language.v1';
  String code = 'tr';
  bool restored = false;
  bool hasSelection = false;

  Future<void> restore() async {
    try {
      final saved = await SharedPreferencesAsync().getString(preferenceKey);
      if (!_disposed && appLanguages.containsKey(saved)) {
        code = saved!;
        hasSelection = true;
      }
    } finally {
      if (!_disposed) {
        restored = true;
        notifyListeners();
      }
    }
  }

  Future<void> select(String value) async {
    if (!appLanguages.containsKey(value)) return;
    await SharedPreferencesAsync().setString(preferenceKey, value);
    if (!_disposed) {
      code = value;
      hasSelection = true;
      notifyListeners();
    }
  }

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier;
}

class AppTranslations {
  AppTranslations(this.code, Map<String, String> messages)
    : messages = Map.unmodifiable(messages);
  final String code;
  final Map<String, String> messages;
  late final templates = [
    for (final entry in messages.entries)
      if (entry.key.contains(RegExp(r'\{\d+\}')))
        (
          pattern: RegExp(
            '^${entry.key.splitMapJoin(RegExp(r'\{\d+\}'), onMatch: (_) => '(.*?)', onNonMatch: RegExp.escape)}\$',
          ),
          translation: entry.value,
        ),
  ];

  String translate(String source) {
    if (messages.containsKey(source)) return messages[source]!;
    for (final template in templates) {
      final match = template.pattern.firstMatch(source);
      if (match == null) continue;
      return template.translation.replaceAllMapped(RegExp(r'\{(\d+)\}'), (
        token,
      ) {
        final group = int.parse(token[1]!) + 1;
        return group <= match.groupCount ? match[group]! : token[0]!;
      });
    }
    return source;
  }

  static const delegate = _TranslationDelegate();
}

class _TranslationDelegate extends LocalizationsDelegate<AppTranslations> {
  const _TranslationDelegate();
  @override
  bool isSupported(Locale locale) =>
      appLanguages.containsKey(locale.languageCode);
  @override
  Future<AppTranslations> load(Locale locale) async {
    final source = await rootBundle.loadString(
      'assets/i18n/${locale.languageCode}.json',
    );
    final messages = (jsonDecode(source) as Map<String, dynamic>)
        .cast<String, String>();
    return AppTranslations(locale.languageCode, messages);
  }

  @override
  bool shouldReload(_TranslationDelegate old) => false;
}

String tr(BuildContext context, String source) =>
    Localizations.of<AppTranslations>(
      context,
      AppTranslations,
    )?.translate(source) ??
    source;

/// UI copy only. Book titles and book contents always use the original Text.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  @override
  Widget build(BuildContext context) => Text(
    tr(context, data),
    style: style,
    textAlign: textAlign,
    textDirection: textDirection,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
  );
}

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.of(context);
    if (controller == null) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.language),
      title: const AppText('Uygulama dili'),
      subtitle: Text(appLanguages[controller.code]!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showLanguagePicker(context),
    );
  }
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});
  @override
  Widget build(BuildContext context) => LanguageScope.of(context) == null
      ? const SizedBox.shrink()
      : Tooltip(
          message: tr(context, 'Uygulama dili'),
          child: TextButton.icon(
            icon: const Icon(Icons.language),
            label: Text(
              '${LanguageScope.of(context)!.code[0].toUpperCase()}${LanguageScope.of(context)!.code.substring(1)}',
            ),
            onPressed: () => showLanguagePicker(context),
          ),
        );
}

Future<void> showLanguagePicker(
  BuildContext context, {
  bool firstLaunch = false,
}) async {
  final controller = LanguageScope.of(context);
  if (controller == null) return;
  final selected = await showDialog<String>(
    context: context,
    barrierDismissible: !firstLaunch,
    builder: (context) => PopScope(
      canPop: !firstLaunch,
      child: SimpleDialog(
        title: firstLaunch
            ? const Text('Dil seçin / Choose your language')
            : const AppText('Uygulama dili'),
        children: [
          for (final entry in appLanguages.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Row(
                children: [
                  Expanded(child: Text(entry.value)),
                  if (entry.key == controller.code) const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    ),
  );
  if (selected == null) return;
  try {
    await controller.select(selected);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Dil tercihi kaydedilemedi. Tekrar dene.'),
        ),
      );
    }
  }
}

class FirstLaunchLanguage extends StatefulWidget {
  const FirstLaunchLanguage({super.key, required this.child});
  final Widget child;
  @override
  State<FirstLaunchLanguage> createState() => _FirstLaunchLanguageState();
}

class _FirstLaunchLanguageState extends State<FirstLaunchLanguage> {
  bool asking = false;
  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.of(context)!;
    if (controller.hasSelection) return widget.child;
    if (controller.restored && !asking) {
      asking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showLanguagePicker(context, firstLaunch: true);
        if (mounted && !controller.hasSelection) setState(() => asking = false);
      });
    }
    return Scaffold(
      body: Center(
        child: controller.restored
            ? const Icon(Icons.menu_book, size: 64)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
