#!/usr/bin/env python3
"""Extrai URLs de mídia (musics/images/covers) dos JSONs espelhados e escreve /tmp/urls-files.txt."""
import json, os, re, sys

DB = '/media/rafaelejosi/NovoVolume/louvorja-mirror/db'
OUT = '/tmp/urls-files.txt'
urls = set()
pat = re.compile(r'^/(musics|images|covers|videos)/')

for fn in os.listdir(DB):
    if not fn.endswith('.json') or fn == 'index.json':
        continue
    try:
        raw = open(os.path.join(DB, fn), encoding='utf-8', errors='replace').read()
    except OSError:
        continue
    # varre todos os campos string procurando paths de mídia
    for m in re.finditer(r'"(?:url_[a-z_]*|path)"\s*:\s*"([^"]+)"', raw):
        v = m.group(1)
        if pat.match(v):
            urls.add('https://api.louvorja.com.br/file' + v.replace(' ', '%20'))

with open(OUT, 'w') as f:
    f.write('\n'.join(sorted(urls)))
print(len(urls), 'midia urls')
