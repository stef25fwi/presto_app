#!/usr/bin/env python3
"""Synchronise build/web -> docs/ avec gestion des gros fichiers"""
import os
import shutil
from pathlib import Path

src_dir = Path('/workspaces/presto_app/build/web')
dst_dir = Path('/workspaces/presto_app/docs')

print("📂 Synchronisation build/web -> docs/")

# Fichiers à copier
files_to_copy = [
    'index.html', '.last_build_id', 'flutter.js', 
    'flutter_bootstrap.js', 'flutter_service_worker.js',
    'manifest.json', 'version.json', 'favicon.png', 
    'main.dart.js', 'maintenance.html'
]

for filename in files_to_copy:
    src_file = src_dir / filename
    dst_file = dst_dir / filename
    if src_file.exists():
        shutil.copy2(src_file, dst_file)
        size_mb = src_file.stat().st_size / (1024 * 1024)
        print(f"✓ {filename} ({size_mb:.1f} MB)")
    else:
        print(f"✗ Manquant: {filename}")

# Répertoires
for dirname in ['assets', 'canvaskit', 'icons']:
    src = src_dir / dirname
    dst = dst_dir / dirname
    if src.exists():
        shutil.copytree(src, dst, dirs_exist_ok=True)
        print(f"✓ {dirname}/")

# .nojekyll et 404.html
(dst_dir / '.nojekyll').touch()
if (dst_dir / 'index.html').exists():
    shutil.copy2(dst_dir / 'index.html', dst_dir / '404.html')
    print(f"✓ .nojekyll et 404.html créés")

print("\n✅ Synchronisation terminée!")
