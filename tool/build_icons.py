"""Pack the Ionicons and Modern icon folders into one JSON library (name -> SVG).

Usage: python tool/build_icons.py <ionicpack dir> <iconpackmodern dir> <out.json> [<copy for the dashboard>]
Icons are referenced as "io:<name>" and "md:<name>"; colours become currentColor so the app and the
dashboard can tint them.
"""
import json, os, re, sys

def clean(svg, pack):
    svg = re.sub(r'<\?xml[^>]*>|<!--.*?-->|<title>.*?</title>', '', svg, flags=re.S)
    svg = re.sub(r'\s(width|height)="[^"]*"', '', svg, count=2)
    svg = svg.replace('#000000', 'currentColor').replace('#000', 'currentColor').replace('black', 'currentColor')
    if pack == 'md' and 'stroke=' not in svg.split('>')[0]:
        svg = svg.replace('<svg', '<svg stroke="currentColor"', 1)
    if pack == 'io' and 'fill=' not in svg.split('>')[0]:
        svg = svg.replace('<svg', '<svg fill="currentColor"', 1)
    return re.sub(r'>\s+<', '><', re.sub(r'\s+', ' ', svg)).strip()

def load(folder, pack):
    out = {}
    for f in sorted(os.listdir(folder)):
        if not f.endswith('.svg'):
            continue
        m = re.match(r'(.+?)(?: \((\d+)\))?\.svg$', f)
        name = m.group(1).strip().lower().replace(' ', '-') + ('-' + str(int(m.group(2)) + 1) if m.group(2) else '')
        out[name] = clean(open(os.path.join(folder, f), encoding='utf-8').read(), pack)
    return out

lib = {'io': load(sys.argv[1], 'io'), 'md': load(sys.argv[2], 'md')}
data = json.dumps(lib, separators=(',', ':'))
for path in sys.argv[3:]:
    open(path, 'w', encoding='utf-8').write(data)
print(len(lib['io']), 'ionicons +', len(lib['md']), 'modern;', round(len(data) / 1024), 'KB')
