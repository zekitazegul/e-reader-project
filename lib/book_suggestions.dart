/// Search folding keeps Cyrillic and Arabic letters while removing optional marks.
String normalizeTitle(String text) {
  var value = text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  const equivalents = {
    'ı': 'i',
    'ç': 'c',
    'ğ': 'g',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'â': 'a',
    'î': 'i',
    'û': 'u',
    'ё': 'е',
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ى': 'ي',
    'ی': 'ي',
    'ک': 'ك',
  };
  for (final entry in equivalents.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value
      .replaceAll(
        RegExp(
          r'[\u0300-\u036f\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u0640\u200e\u200f\u202a-\u202e\u2066-\u2069]',
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'[^a-z0-9\u0400-\u052f\u0621-\u063a\u0641-\u064a\u0660-\u0669\u0671-\u06d3\u06f0-\u06f9]+',
        ),
        ' ',
      )
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class BookSuggestion {
  const BookSuggestion(this.title, this.author, this.aliases);
  final String title;
  final String author;
  final List<String> aliases;
  String get label => author.isEmpty ? title : '$title — $author';
}

const knownBooks = [
  BookSuggestion('Monte Kristo Kontu', 'Alexandre Dumas', [
    'Monte Cristo',
    'The Count of Monte Cristo',
    'Граф Монте-Кристо',
    'الكونت دي مونت كريستو',
    'كونت مونت كريستو',
  ]),
  BookSuggestion('Suç ve Ceza', 'Fyodor Dostoyevski', [
    'Crime and Punishment',
    'Преступление и наказание',
    'الجريمة والعقاب',
  ]),
  BookSuggestion('Savaş ve Barış', 'Lev Tolstoy', [
    'War and Peace',
    'Война и мир',
    'الحرب والسلام',
  ]),
  BookSuggestion('Sefiller', 'Victor Hugo', [
    'Les Misérables',
    'Les Miserables',
    'Отверженные',
    'البؤساء',
  ]),
  BookSuggestion('Gurur ve Önyargı', 'Jane Austen', [
    'Pride and Prejudice',
    'Гордость и предубеждение',
    'كبرياء وتحامل',
  ]),
  BookSuggestion('Anna Karenina', 'Lev Tolstoy', [
    'Анна Каренина',
    'آنا كارنينا',
  ]),
  BookSuggestion('Don Kişot', 'Miguel de Cervantes', [
    'Don Quixote',
    'Дон Кихот',
    'دون كيخوت',
  ]),
  BookSuggestion('Moby Dick', 'Herman Melville', [
    'Moby-Dick',
    'Моби Дик',
    'موبي ديك',
  ]),
];

int _distance(String a, String b) {
  var previous = List.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final row = List.filled(b.length + 1, i + 1);
    for (var j = 0; j < b.length; j++) {
      final replace = previous[j] + (a[i] == b[j] ? 0 : 1);
      var best = row[j] + 1;
      if (previous[j + 1] + 1 < best) best = previous[j + 1] + 1;
      row[j + 1] = replace < best ? replace : best;
    }
    previous = row;
  }
  return previous.last;
}

List<BookSuggestion> suggestBooks(
  String query, {
  Iterable<String> localTitles = const [],
}) {
  final normalized = normalizeTitle(query);
  if (normalized.length < 5 || normalized.length > 150) return [];
  final candidates = [
    ...knownBooks,
    for (final title in localTitles) BookSuggestion(title, '', const []),
  ];
  final ranked = <({BookSuggestion book, double score})>[];
  final seen = <String>{};
  for (final book in candidates) {
    if (!seen.add(normalizeTitle(book.title))) continue;
    var score = 0.0;
    for (final alias in [book.title, ...book.aliases]) {
      final name = normalizeTitle(alias);
      final length = normalized.length > name.length
          ? normalized.length
          : name.length;
      if ((normalized.length - name.length).abs() > length * 0.24) continue;
      final similarity = 1 - _distance(normalized, name) / length;
      if (similarity > score) score = similarity;
    }
    if (score >= 0.76) ranked.add((book: book, score: score));
  }
  ranked.sort((a, b) => b.score.compareTo(a.score));
  return ranked.take(3).map((entry) => entry.book).toList();
}

BookSuggestion? identifyBook(String query) {
  final candidates = suggestBooks(query);
  return candidates.isEmpty ? null : candidates.first;
}

bool matchesLibraryTitle(String title, String query) {
  final normalized = normalizeTitle(query);
  final name = normalizeTitle(title);
  if (name.contains(normalized)) return true;
  for (final book in knownBooks) {
    final aliases = [book.title, ...book.aliases].map(normalizeTitle).toList();
    if (aliases.contains(normalized) && aliases.any(name.contains)) return true;
  }
  return false;
}
