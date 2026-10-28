"""Offline catalog builder. No network access; translations are authored in packs."""
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
KEYS=list(json.loads((ROOT/'assets/i18n/tr.json').read_text(encoding='utf-8')))
def write(code, text):
    values=[line.strip() for line in text.strip().splitlines()]
    if len(values)!=len(KEYS):
        raise ValueError(f'{code}: expected {len(KEYS)} messages, got {len(values)}')
    for key,value in zip(KEYS,values):
        if sorted(re.findall(r'\{\d+\}',key))!=sorted(re.findall(r'\{\d+\}',value)):
            raise ValueError(f'{code}: placeholders differ: {key!r} -> {value!r}')
    (ROOT/'assets/i18n'/f'{code}.json').write_text(json.dumps(dict(zip(KEYS,values)),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{code}: {len(values)}')
