import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart';

import 'dart:convert';

import 'book_reference_page.dart';

class ReferenceTextBlock {
  const ReferenceTextBlock(this.element, this.raw, this.text, this.offset);
  final dom.Element element;
  final String raw, text;
  final int offset;
}

class _Location {
  _Location(this.start, this.order);
  final int start, order;
  int endOrder = 0;
}

/// Page labels are accepted only from explicit publisher page metadata.
/// Text extraction is unchanged, including for previously stored UTF-16 offsets.
class EpubReferencePages {
  EpubReferencePages(Archive archive, XmlDocument package, String packagePath) {
    String? read(String path) {
      final entry = archive.findFile(path);
      return entry == null ? null : utf8.decode(entry.content);
    }

    for (final item in package.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'item',
    )) {
      final href = item.getAttribute('href');
      if (href == null) continue;
      final path = Uri(path: packagePath).resolve(href).path;
      try {
        if (_tokens(item.getAttribute('properties')).contains('nav')) {
          final source = read(path);
          if (source == null) continue;
          final document = html.parse(source);
          for (final nav in document.querySelectorAll('nav')) {
            if (!_tokens(nav.attributes['epub:type']).contains('page-list') &&
                !_tokens(nav.attributes['role']).contains('doc-pagelist')) {
              continue;
            }
            for (final link in nav.querySelectorAll('a[href]')) {
              _addTarget(path, link.attributes['href']!, link.text.trim());
            }
          }
        } else if (item.getAttribute('media-type') ==
            'application/x-dtbncx+xml') {
          final source = read(path);
          if (source == null) continue;
          final ncx = XmlDocument.parse(source);
          for (final target in ncx.descendants.whereType<XmlElement>().where(
            (e) => e.name.local == 'pageTarget',
          )) {
            final content = target.descendants.whereType<XmlElement>().where(
              (e) => e.name.local == 'content',
            );
            final labels = target.descendants.whereType<XmlElement>().where(
              (e) => e.name.local == 'text',
            );
            final src = content.isEmpty
                ? null
                : content.first.getAttribute('src');
            if (src != null) {
              _addTarget(
                path,
                src,
                labels.isEmpty
                    ? target.getAttribute('value') ?? ''
                    : labels.first.innerText.trim(),
              );
            }
          }
        }
      } catch (_) {
        // Malformed optional page metadata must never block reading.
      }
    }
  }

  static Set<String> _tokens(String? value) =>
      (value ?? '').split(RegExp(r'\s+')).toSet();
  final _targets = <String, Map<String, String>>{};
  final pages = <BookReferencePage>[];

  void _addTarget(String base, String href, String label) {
    final uri = Uri(path: base).resolve(href);
    if (label.isEmpty || uri.hasScheme || uri.hasAuthority) return;
    (_targets[uri.path] ??= {})[uri.fragment] = label;
  }

  void addChapter(
    String path,
    dom.Document document,
    List<ReferenceTextBlock> blocks, {
    required bool cleanWhitespace,
  }) {
    if (blocks.isEmpty) return;
    final labels = <dom.Element, String>{};
    final targets = _targets[path] ?? const <String, String>{};
    final body = document.body;
    if (body == null) return;
    if (targets.containsKey('')) labels[body] = targets['']!;
    for (final element in document.querySelectorAll('*')) {
      final target = targets[element.id];
      if (element.id.isNotEmpty && target != null) labels[element] = target;
      if (_tokens(element.attributes['epub:type']).contains('pagebreak') ||
          _tokens(element.attributes['role']).contains('doc-pagebreak')) {
        final label =
            element.attributes['aria-label'] ??
            element.attributes['title'] ??
            element.text.trim();
        if (label.trim().isNotEmpty) {
          labels.putIfAbsent(element, () => label.trim());
        }
      }
    }
    if (labels.isEmpty) return;

    final wanted = {...labels.keys, ...blocks.map((b) => b.element)};
    final locations = <dom.Element, _Location>{};
    final stack = <(dom.Node, bool)>[(body, false)];
    var rawOffset = 0;
    var order = 0;
    while (stack.isNotEmpty) {
      final (node, exit) = stack.removeLast();
      if (node is dom.Text) {
        rawOffset += node.data.length;
      } else {
        if (node is dom.Element && wanted.contains(node)) {
          if (exit) {
            locations[node]!.endOrder = order++;
          } else {
            locations[node] = _Location(rawOffset, order++);
          }
        }
        if (!exit) {
          stack.add((node, true));
          for (final child in node.nodes.reversed) {
            stack.add((child, false));
          }
        }
      }
    }
    final markers = labels.keys.where(locations.containsKey).toList()
      ..sort((a, b) => locations[a]!.order.compareTo(locations[b]!.order));
    var blockIndex = 0;
    final cuts = <int, List<(int, String)>>{};
    for (final marker in markers) {
      final location = locations[marker]!;
      while (blockIndex < blocks.length &&
          location.order > locations[blocks[blockIndex].element]!.endOrder) {
        blockIndex++;
      }
      if (blockIndex == blocks.length) {
        final last = blocks.last;
        pages.add(
          BookReferencePage(last.offset + last.text.length, labels[marker]!),
        );
      } else {
        final block = blocks[blockIndex];
        final start = locations[block.element]!;
        final cut = (location.start - start.start).clamp(0, block.raw.length);
        (cuts[blockIndex] ??= []).add((cut, labels[marker]!));
      }
    }
    for (final entry in cuts.entries) {
      final block = blocks[entry.key];
      final boundaries = entry.value..sort((a, b) => a.$1.compareTo(b.$1));
      final offsets = _mapCuts(
        block.raw,
        block.text,
        boundaries.map((b) => b.$1).toList(),
        cleanWhitespace,
      );
      for (var i = 0; i < boundaries.length; i++) {
        pages.add(
          BookReferencePage(block.offset + offsets[i], boundaries[i].$2),
        );
      }
    }
  }

  List<BookReferencePage> finish() {
    pages.sort((a, b) => a.offset.compareTo(b.offset));
    final result = <BookReferencePage>[];
    for (final page in pages) {
      if (result.isNotEmpty && result.last.offset == page.offset) {
        result[result.length - 1] = page;
      } else {
        result.add(page);
      }
    }
    return result;
  }
}

List<int> _mapCuts(String raw, String text, List<int> cuts, bool clean) {
  if (!clean) {
    final leading = raw.length - raw.trimLeft().length;
    return cuts.map((cut) => (cut - leading).clamp(0, text.length)).toList();
  }
  final mapped = <int>[];
  var index = 0;
  var output = 0;
  final words = RegExp(r'[^\s\u00a0\u2007\u202f]+').allMatches(raw);
  for (final word in words) {
    final start = output + (output == 0 ? 0 : 1);
    while (index < cuts.length && cuts[index] <= word.end) {
      mapped.add(
        (start + (cuts[index] - word.start).clamp(0, word.end - word.start))
            .clamp(0, text.length),
      );
      index++;
    }
    output = start + word.end - word.start;
  }
  while (mapped.length < cuts.length) {
    mapped.add(text.length);
  }
  return mapped;
}
