#!/usr/bin/env python3
"""Selective APK re-zip: STORE every entry under assets/ (Godot game files:
scripts, remaps, textures, audio, metadata) so Android AssetManager never
needs decompression/random-access on them. Native libs (lib/), dex and res/
keep their original compression (system handles those, saves ~100MB).
Output must still be zipaligned + signed afterwards."""
import zipfile, sys, os

src, dst = sys.argv[1], sys.argv[2]
zin = zipfile.ZipFile(src, 'r')
if os.path.exists(dst):
    os.remove(dst)
zout = zipfile.ZipFile(dst, 'w', allowZip64=True)
stored = deflate = 0
for info in zin.infolist():
    name = info.filename
    if info.is_dir():
        continue
    if name.startswith('META-INF/'):
        continue  # old signatures dropped; apksigner re-signs later
    data = zin.read(name)
    zi = zipfile.ZipInfo(name, date_time=info.date_time)
    zi.external_attr = info.external_attr
    if name.startswith('assets/'):
        zi.compress_type = zipfile.ZIP_STORED
        stored += 1
    else:
        zi.compress_type = info.compress_type
        deflate += 1
    zout.writestr(zi, data)
zout.close(); zin.close()
print(f'rezip ok: stored(assets)={stored} kept-original={deflate} size={os.path.getsize(dst)}')
