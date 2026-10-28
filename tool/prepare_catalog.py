import json,re
from pathlib import Path
p=Path('assets/i18n/tr.json');d=json.loads(p.read_text(encoding='utf-8'))
d={k:v for k,v in d.items() if re.search(r'[a-zA-ZçğıöşüÇĞİÖŞÜ]',k) and k not in ('İ','ı','{0}{1} eşleşme')}
for key in ['Kapat','Git','İlk {0} eşleşme','{0} eşleşme']:
 d[key]=key
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for i,key in enumerate(d):print(str(i)+' '+json.dumps(key,ensure_ascii=True))
