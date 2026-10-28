"""Build bundled offline lookup data from CC BY-SA 3.0 WikDict TEI files."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'build' / 'dictionary-sources'
OUT = ROOT / 'assets' / 'dictionaries'
ISO = {'nl': 'nld', 'en': 'eng', 'tr': 'tur'}
NS = {'t': 'http://www.tei-c.org/ns/1.0'}

def normalize(word, language):
    if language == 'tr':
        word = word.replace('I', 'ı').replace('İ', 'i')
    return word.lower().strip().replace('’', "'")

def build(pair):
    source, target = pair.split('-')
    url = f'https://download.wikdict.com/dictionaries/tei/recommended/{ISO[source]}-{ISO[target]}.tei'
    path = RAW / (pair + '.tei')
    if not path.exists():
        urllib.request.urlretrieve(url, path)
    data = path.read_bytes()
    root = ET.fromstring(data)
    availability = root.find('.//t:availability', NS)
    if availability is None or not any('by-sa/3.0' in r.attrib.get('target', '') for r in availability.findall('.//t:ref', NS)):
        raise ValueError(f'Unexpected license: {pair}')
    entries = {}
    for entry in root.findall('.//t:entry', NS):
        words = [normalize(''.join(n.itertext()), source) for n in entry.findall('./t:form/t:orth', NS)]
        translations = []
        for cit in entry.findall('.//t:cit', NS):
            if cit.attrib.get('type') != 'trans':
                continue
            for quote in cit.findall('t:quote', NS):
                text = ''.join(quote.itertext()).strip()
                if text and text not in translations:
                    translations.append(text)
        for word in words:
            if word and translations:
                result = entries.setdefault(word, [])
                for text in translations:
                    if text not in result:
                        result.append(text)
    (OUT / (pair + '.json')).write_text(json.dumps(entries, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(f'{pair}: {len(entries)} lookup keys')
    return {'pair': pair, 'source': url, 'source_sha256': hashlib.sha256(data).hexdigest(), 'entries': len(entries)}

def main():
    RAW.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    pairs = [f'{a}-{b}' for a in ISO for b in ISO if a != b]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        metadata = list(pool.map(build, pairs))
    (OUT / 'sources.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')

if __name__ == '__main__':
    main()
