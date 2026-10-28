"""Rebuild the bundled public-domain story with source attribution."""
from html import escape
from html.parser import HTMLParser
from pathlib import Path
from urllib.request import Request, urlopen
from zipfile import ZipFile, ZIP_DEFLATED, ZIP_STORED

SOURCE = 'https://tr.wikisource.org/w/index.php?title=Yaln%C4%B1z_Efe&oldid=169450'


class StoryParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.depth = 0
        self.capture = None
        self.text = []
        self.paragraphs = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'div':
            if self.depth:
                self.depth += 1
            elif 'mw-parser-output' in attrs.get('class', '').split():
                self.depth = 1
        if self.depth and tag in ('p', 'pre', 'dd'):
            self.capture = tag
            self.text = []
        if self.capture and tag == 'br':
            self.text.append('\n')

    def handle_endtag(self, tag):
        if tag == self.capture:
            lines = ''.join(self.text).splitlines() if tag == 'pre' else [''.join(self.text)]
            self.paragraphs.extend(' '.join(line.split()) for line in lines if line.strip())
            self.capture = None
        if tag == 'div' and self.depth:
            self.depth -= 1

    def handle_data(self, data):
        if self.capture:
            self.text.append(data)


def main():
    request = Request(SOURCE, headers={'User-Agent': 'EReaderSampleBook/1.0 (public-domain reading fixture)'})
    with urlopen(request, timeout=45) as response:
        source = response.read().decode('utf-8')
    parser = StoryParser()
    parser.feed(source)
    paragraphs = parser.paragraphs
    end = next(i for i, p in enumerate(paragraphs) if 'nur iner mi?' in p)
    paragraphs = paragraphs[:end + 1]
    assert len(paragraphs) > 20, 'Story extraction failed'
    assert paragraphs[0].startswith('Sabahtan beri yürüyorduk.'), paragraphs[0]
    assert 'nur iner mi?' in paragraphs[-1], paragraphs[-1]
    body = ''.join(f'<p>{escape(p)}</p>' for p in paragraphs)
    story = f'''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="tr"><head><title>Yalnız Efe</title></head>
<body><h1>Yalnız Efe</h1>{body}</body></html>'''
    credits = f'''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="tr"><head><title>Kaynak</title></head><body>
<h1>Kaynak ve kullanım bilgisi</h1><p>Yalnız Efe — Ömer Seyfettin (1884–1920).</p>
<p>Özgün eserin Türkiye’deki mali hak koruma süresi dolmuştur.</p>
<p>Metin: Türkçe Vikikaynak, Yalnız Efe, sürüm 169450. Vikikaynak katkıda bulunanları.</p>
<p><a href="{escape(SOURCE, quote=True)}">Kaynak ve katkı geçmişi</a></p>
<p>Bu dijital metin derlemesi CC BY-SA 4.0 koşullarıyla paylaşılır.
Metin değiştirilmemiş, EPUB için paragraf boşlukları düzenlenmiştir.</p>
<p><a href="https://creativecommons.org/licenses/by-sa/4.0/">CC BY-SA 4.0</a></p>
</body></html>'''
    package = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="id">urn:e-reader:sample:yalniz-efe:169450</dc:identifier>
<dc:title>Yalnız Efe</dc:title><dc:creator>Ömer Seyfettin</dc:creator><dc:language>tr</dc:language>
<dc:rights>Original work public domain in Turkey; digital text CC BY-SA 4.0</dc:rights>
<meta property="dcterms:modified">2026-10-27T00:00:00Z</meta></metadata>
<manifest><item id="story" href="story.xhtml" media-type="application/xhtml+xml"/>
<item id="credits" href="credits.xhtml" media-type="application/xhtml+xml"/>
<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/></manifest>
<spine><itemref idref="story"/><itemref idref="credits"/></spine></package>'''
    container = '''<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="EPUB/book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'''
    nav = '''<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="tr"><head><title>İçindekiler</title></head><body><nav epub:type="toc"><ol><li><a href="story.xhtml">Yalnız Efe</a></li><li><a href="credits.xhtml">Kaynak</a></li></ol></nav></body></html>'''
    output = Path(__file__).resolve().parents[1] / 'assets/books/yalniz-efe.epub'
    with ZipFile(output, 'w', compression=ZIP_DEFLATED) as archive:
        archive.writestr('mimetype', 'application/epub+zip', compress_type=ZIP_STORED)
        for name, text in [('META-INF/container.xml', container), ('EPUB/book.opf', package),
                           ('EPUB/story.xhtml', story), ('EPUB/credits.xhtml', credits), ('EPUB/nav.xhtml', nav)]:
            archive.writestr(name, text.encode('utf-8'))
    print(f'Created {output.name}: {len(paragraphs)} story paragraphs')


if __name__ == '__main__':
    main()
