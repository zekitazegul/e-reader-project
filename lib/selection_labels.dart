import 'package:flutter/widgets.dart';

String selectionLabel(BuildContext context, String key) {
  const labels = {
    'tr': {
      'translate': 'Tercüme',
      'underline': 'Altını çiz',
      'removeUnderline': 'Alt çizgiyi kaldır',
      'note': 'Not al',
      'save': 'Kaydet',
      'delete': 'Sil',
      'dictionary': 'Çevrimdışı sözlük',
      'meanings': 'Kelime ve kalıp anlamları',
      'missing': 'Sözlükte bulunamadı.',
      'download': 'Sözlüğü indir',
      'downloadInfo': 'Bu sözlük cihazına indirilecek ve sonraki kullanımlarda çevrimdışı çalışacak.',
      'downloadError': 'Sözlük indirilemedi. Tekrar deneyin.',
      'saveError': 'İşaretlemeler kaydedilemedi.',
      'source': 'Kaynak dil',
      'target': 'Hedef dil',
      'loadingError': 'Sözlük yüklenemedi.',
    },
    'en': {
      'translate': 'Translate',
      'underline': 'Underline',
      'removeUnderline': 'Remove underline',
      'note': 'Add note',
      'save': 'Save',
      'delete': 'Delete',
      'dictionary': 'Offline dictionary',
      'meanings': 'Word and phrase meanings',
      'missing': 'Not found in the dictionary.',
      'download': 'Download dictionary',
      'downloadInfo': 'This dictionary will be saved on your device and work offline afterwards.',
      'downloadError': 'Could not download the dictionary. Try again.',
      'saveError': 'Could not save annotations.',
      'source': 'Source language',
      'target': 'Target language',
      'loadingError': 'Could not load the dictionary.',
    },
    'nl': {
      'translate': 'Vertalen',
      'underline': 'Onderstrepen',
      'removeUnderline': 'Onderstreping verwijderen',
      'note': 'Notitie toevoegen',
      'save': 'Opslaan',
      'delete': 'Verwijderen',
      'dictionary': 'Offline woordenboek',
      'meanings': 'Betekenissen van woorden en uitdrukkingen',
      'missing': 'Niet gevonden in het woordenboek.',
      'download': 'Woordenboek downloaden',
      'downloadInfo': 'Dit woordenboek wordt op je apparaat opgeslagen en werkt daarna offline.',
      'downloadError':
          'Het woordenboek kon niet worden gedownload. Probeer opnieuw.',
      'saveError': 'Aantekeningen konden niet worden opgeslagen.',
      'source': 'Brontaal',
      'target': 'Doeltaal',
      'loadingError': 'Het woordenboek kon niet worden geladen.',
    },
  };
  final language = Localizations.localeOf(context).languageCode;
  return (labels[language] ?? labels['en']!)[key] ?? key;
}
