import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html;

// MOBI6/PalmDOC record layout: calibre/format_docs/pdb/mobi.txt.
// Only unencrypted text is accepted; KF8 and HUFF/CDIC are not decoded here.
Uint8List mobiToEpub(Uint8List source, String fallbackTitle) {
  const limit = 100 * 1024 * 1024;
  final bytes = ByteData.sublistView(source);
  int u16(int offset) => bytes.getUint16(offset);
  int u32(int offset) => bytes.getUint32(offset);
  Never invalid() => throw const FormatException('Invalid or unsupported MOBI');
  if (source.length < 86 || source.length > limit) invalid();
  final records = u16(76);
  if (records < 2 || 78 + records * 8 > source.length) invalid();
  final offsets = [
    for (var i = 0; i < records; i++) u32(78 + i * 8),
    source.length,
  ];
  if (offsets.first < 78 + records * 8) invalid();
  for (var i = 0; i < records; i++) {
    if (offsets[i] >= offsets[i + 1] || offsets[i + 1] > source.length) {
      invalid();
    }
  }
  final first = offsets.first;
  final headerSize = offsets[1] - first;
  if (headerSize < 16) invalid();
  final compression = u16(first);
  final textLength = u32(first + 4);
  final textRecords = u16(first + 8);
  if (u16(first + 12) != 0 ||
      textLength == 0 ||
      textLength > limit ||
      textRecords == 0 ||
      textRecords >= records ||
      ![1, 2].contains(compression)) {
    invalid();
  }
  var encoding = 1252;
  var trailing = 0;
  var title = fallbackTitle;
  if (headerSize >= 20 &&
      ascii.decode(
            source.sublist(first + 16, first + 20),
            allowInvalid: true,
          ) ==
          'MOBI') {
    if (headerSize < 108) invalid();
    final mobiLength = u32(first + 20);
    if (mobiLength < 92 || mobiLength + 16 > headerSize || u32(first + 36) >= 8) {
      invalid();
    }
    encoding = u32(first + 28);
    if (![1252, 65001].contains(encoding)) invalid();
    if (mobiLength >= 228) {
      trailing = u16(first + 242);
      if (u32(first + 172) != 0) invalid();
    }
    final titleOffset = u32(first + 84);
    final titleLength = u32(first + 88);
    if (titleLength > 0 && titleOffset + titleLength <= headerSize) {
      title = _decode(
        source.sublist(first + titleOffset, first + titleOffset + titleLength),
        encoding,
      ).trim();
    }
  }
  final output = BytesBuilder(copy: false);
  for (var index = 1; index <= textRecords; index++) {
    final record = Uint8List.sublistView(
      source,
      offsets[index],
      offsets[index + 1],
    );
    var end = record.length;
    for (var flags = trailing >> 1; flags != 0; flags >>= 1) {
      if (flags & 1 == 0) continue;
      var size = 0;
      var terminated = false;
      for (var n = 0; n < 4; n++) {
        if (end <= n) invalid();
        final value = record[end - 1 - n];
        size |= (value & 0x7f) << (7 * n);
        if (value & 0x80 != 0) {
          terminated = true;
          break;
        }
      }
      if (!terminated || size == 0 || size > end) invalid();
      end -= size;
    }
    if (trailing & 1 != 0) {
      if (end == 0) invalid();
      end -= (record[end - 1] & 3) + 1;
      if (end < 0) invalid();
    }
    final text = compression == 1
        ? record.sublist(0, end)
        : _palmDoc(record.sublist(0, end));
    if (output.length + text.length > limit) invalid();
    output.add(text);
  }
  final decoded = output.takeBytes();
  if (decoded.length < textLength) invalid();
  final document = html.parse(
    _decode(decoded.sublist(0, textLength), encoding).replaceAll('\u0000', ''),
  );
  document.querySelectorAll('script, style').forEach((node) => node.remove());
  final blocks = document.querySelectorAll(
    'h1, h2, h3, h4, h5, h6, p, li, blockquote, pre',
  );
  final paragraphs = <String>[];
  for (final block in blocks) {
    var parent = block.parent;
    while (parent != null && !blocks.contains(parent)) {
      parent = parent.parent;
    }
    if (parent == null && block.text.trim().isNotEmpty) {
      paragraphs.add(block.text.trim());
    }
  }
  if (paragraphs.isEmpty && document.body?.text.trim().isNotEmpty == true) {
    paragraphs.add(document.body!.text.trim());
  }
  if (paragraphs.isEmpty) invalid();
  if (title.isEmpty) title = fallbackTitle;
  final escape = const HtmlEscape().convert;
  final archive = Archive();
  void add(String name, String content, {bool stored = false}) {
    final data = utf8.encode(content);
    final file = ArchiveFile(name, data.length, data)..lastModTime = 315532800;
    if (stored) file.compression = CompressionType.none;
    archive.addFile(file);
  }

  add('mimetype', 'application/epub+zip', stored: true);
  add(
    'META-INF/container.xml',
    '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="EPUB/book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
  );
  add(
    'EPUB/book.opf',
    '<?xml version="1.0" encoding="UTF-8"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="book-id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="book-id">urn:sha256:${sha256.convert(source)}</dc:identifier><dc:title>${escape(title)}</dc:title><dc:language>und</dc:language></metadata><manifest><item id="text" href="text.xhtml" media-type="application/xhtml+xml"/><item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/></manifest><spine toc="toc"><itemref idref="text"/></spine></package>',
  );
  add(
    'EPUB/toc.ncx',
    '<?xml version="1.0" encoding="UTF-8"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="urn:sha256:${sha256.convert(source)}"/></head><docTitle><text>${escape(title)}</text></docTitle><navMap><navPoint id="start" playOrder="1"><navLabel><text>${escape(title)}</text></navLabel><content src="text.xhtml"/></navPoint></navMap></ncx>',
  );
  add(
    'EPUB/text.xhtml',
    '<?xml version="1.0" encoding="UTF-8"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>${escape(title)}</title></head><body>${paragraphs.map((p) => '<p>${escape(p)}</p>').join()}</body></html>',
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Uint8List _palmDoc(Uint8List input) {
  final output = <int>[];
  var index = 0;
  while (index < input.length) {
    final value = input[index++];
    if (value >= 1 && value <= 8) {
      if (index + value > input.length) {
        throw const FormatException('Truncated PalmDOC literal');
      }
      output.addAll(input.sublist(index, index + value));
      index += value;
    } else if (value <= 0x7f) {
      output.add(value);
    } else if (value >= 0xc0) {
      output.addAll([0x20, value ^ 0x80]);
    } else {
      if (index >= input.length) {
        throw const FormatException('Truncated PalmDOC reference');
      }
      final pair = (value << 8) | input[index++];
      final distance = (pair >> 3) & 0x7ff;
      final count = (pair & 7) + 3;
      if (distance == 0 || distance > output.length) {
        throw const FormatException('Invalid PalmDOC reference');
      }
      for (var n = 0; n < count; n++) {
        output.add(output[output.length - distance]);
      }
    }
    if (output.length > 65536) {
      throw const FormatException('Oversized PalmDOC record');
    }
  }
  return Uint8List.fromList(output);
}

String _decode(List<int> bytes, int encoding) {
  if (encoding == 65001) return utf8.decode(bytes, allowMalformed: true);
  const extended = [
    0x20ac,
    0x81,
    0x201a,
    0x192,
    0x201e,
    0x2026,
    0x2020,
    0x2021,
    0x2c6,
    0x2030,
    0x160,
    0x2039,
    0x152,
    0x8d,
    0x17d,
    0x8f,
    0x90,
    0x2018,
    0x2019,
    0x201c,
    0x201d,
    0x2022,
    0x2013,
    0x2014,
    0x2dc,
    0x2122,
    0x161,
    0x203a,
    0x153,
    0x9d,
    0x17e,
    0x178,
  ];
  return String.fromCharCodes(
    bytes.map((b) => b >= 0x80 && b <= 0x9f ? extended[b - 0x80] : b),
  );
}
