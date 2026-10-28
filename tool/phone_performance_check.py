"""Install and smoke-check the three requested updates on the connected phone."""
import json
import re
import subprocess
import sys
import time
from pathlib import Path
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding='utf-8')

ADB = 'C:/Users/Zek/AppData/Local/Android/Sdk/platform-tools/adb.exe'
OUT = Path('C:/e-reader/build/phone-performance-2026-10-28')
OUT.mkdir(parents=True, exist_ok=True)
devices = subprocess.check_output([ADB, 'devices'], text=True)
serials = [line.split('\t')[0] for line in devices.splitlines()[1:]
           if '\t' in line and line.split('\t')[1].strip() == 'device']
if len(serials) != 1:
    raise RuntimeError('Expected exactly one connected device')
SERIAL = serials[0]
APPS = {
    'reader': ('com.example.e_reader', 'C:/e-reader', 22),
    'cevsen': ('com.zek.cevsen_app', 'C:/cevsenApp', 25),
    'quran': ('com.zekitazegul.kuranapp', 'C:/KuranApp/kuran_app', 95),
}


def adb(*args):
    return subprocess.check_output([ADB, '-s', SERIAL, *args], timeout=150).decode('utf-8', errors='replace')


def nodes(name):
    for attempt in range(3):
        adb('shell', 'uiautomator', 'dump', '/sdcard/performance-check.xml')
        data = adb('shell', 'cat', '/sdcard/performance-check.xml')
        (OUT / f'{name}.xml').write_text(data, encoding='utf-8')
        result = list(ET.fromstring(data).iter('node'))
        if any(n.get('text') or n.get('content-desc') for n in result):
            return result
        time.sleep(.7)
    return result


def labels(name):
    return [n.get('text') or n.get('content-desc') for n in nodes(name)
            if n.get('text') or n.get('content-desc')]


def shot(name):
    data = subprocess.check_output([ADB, '-s', SERIAL, 'exec-out', 'screencap', '-p'], timeout=30)
    (OUT / f'{name}.png').write_bytes(data)


def tap_label(name, choices):
    candidates = [n for n in nodes(name) if any(
        choice in (n.get('text', '') + ' ' + n.get('content-desc', ''))
        for choice in choices)]
    if not candidates:
        raise RuntimeError(f'No matching control: {choices}')
    node = min(candidates, key=lambda n: len(n.get('text', '') + n.get('content-desc', '')))
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.get('bounds')))
    adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
    time.sleep(2)


def install(name):
    package, root, build = APPS[name]
    result = adb('install', '-r', f'{root}/build/app/outputs/flutter-apk/app-release.apk')
    if 'Success' not in result:
        raise RuntimeError(result)
    info = adb('shell', 'dumpsys', 'package', package)
    if not re.search(rf'versionCode={build}\b', info):
        raise RuntimeError('Installed build mismatch')
    print(f'{name}: installed build {build}', flush=True)


def launch(name):
    package = APPS[name][0]
    result = adb('shell', 'am', 'start', '-W', '-S', '-n', package + '/.MainActivity')
    (OUT / f'{name}-launch.txt').write_text(result, encoding='utf-8')
    time.sleep(3)
    pid = adb('shell', 'pidof', package).strip()
    if not pid:
        raise RuntimeError(f'{name}: no running process')
    text = labels(name + '-home')
    shot(name + '-home')
    print(json.dumps({'app': name, 'launch': result, 'labels': text}, ensure_ascii=False), flush=True)


def layout_check(name):
    auto = adb('shell', 'settings', 'get', 'system', 'accelerometer_rotation').strip()
    rotation = adb('shell', 'settings', 'get', 'system', 'user_rotation').strip()
    fixed = adb('shell', 'wm', 'fixed-to-user-rotation').strip()
    evidence = {}
    try:
        adb('shell', 'wm', 'fixed-to-user-rotation', 'enabled')
        adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0')
        for value, orientation in [('0', 'portrait'), ('1', 'landscape')]:
            adb('shell', 'settings', 'put', 'system', 'user_rotation', value)
            time.sleep(2)
            evidence[orientation] = labels(name + '-' + orientation)
            actual_rotation = ET.parse(OUT / f'{name}-{orientation}.xml').getroot().get('rotation')
            if actual_rotation != value:
                raise RuntimeError(f'Expected rotation {value}, got {actual_rotation}')
            shot(name + '-' + orientation)
            # The Quran landscape reader intentionally hides its chrome and
            # displays the page image without accessibility text.
            if (OUT / f'{name}-{orientation}.png').stat().st_size < 10000:
                raise RuntimeError('Reading screenshot is unexpectedly small')
    finally:
        adb('shell', 'wm', 'fixed-to-user-rotation', fixed)
        adb('shell', 'settings', 'put', 'system', 'user_rotation', rotation)
        adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', auto)
    (OUT / f'{name}-layout.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'{name}: portrait and landscape captured; rotation preferences restored', flush=True)


def page_check(name):
    def counter():
        matches = [re.fullmatch(r'(\d+)\s*/\s*(\d+)', label) for label in labels(name + '-page')]
        return next((tuple(map(int, match.groups())) for match in matches if match), None)
    before = counter()
    if before is None:
        raise RuntimeError('Page counter unavailable')
    tap_label(name, ['Sonraki sayfa'])
    after = counter()
    if after != (before[0] + 1, before[1]):
        raise RuntimeError(f'Unexpected next page: {before} -> {after}')
    tap_label(name, ['Önceki sayfa'])
    restored = counter()
    if restored != before:
        raise RuntimeError(f'Page did not restore: {restored}')
    evidence = {'before': before, 'next': after, 'restored': restored}
    (OUT / f'{name}-page-check.json').write_text(json.dumps(evidence), encoding='utf-8')
    print(json.dumps({name: evidence}), flush=True)


def verify_pages():
    auto = adb('shell', 'settings', 'get', 'system', 'accelerometer_rotation').strip()
    rotation = adb('shell', 'settings', 'get', 'system', 'user_rotation').strip()
    fixed = adb('shell', 'wm', 'fixed-to-user-rotation').strip()
    try:
        adb('shell', 'wm', 'fixed-to-user-rotation', 'enabled')
        adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0')
        adb('shell', 'settings', 'put', 'system', 'user_rotation', '0')
        time.sleep(2)
        for name, title in [('reader', 'Yalnız Efe'), ('quran', 'Okumaya devam et')]:
            launch(name)
            tap_label(name, [title])
            page_check(name)
    finally:
        adb('shell', 'settings', 'put', 'system', 'user_rotation', rotation)
        adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', auto)
        adb('shell', 'wm', 'fixed-to-user-rotation', fixed)


if __name__ == '__main__':
    action, name = sys.argv[1:3]
    if action == 'install':
        install(name)
    elif action == 'launch':
        launch(name)
    elif action == 'tap':
        tap_label(name, sys.argv[3:])
        print(json.dumps(labels(name + '-reader'), ensure_ascii=False))
        shot(name + '-reader')
    elif action == 'layout':
        layout_check(name)
    elif action == 'page-check':
        page_check(name)
    elif action == 'verify-pages':
        verify_pages()
