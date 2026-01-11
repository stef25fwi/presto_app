#!/usr/bin/env python3
"""
Script pour synchroniser build/web -> docs/
Utilisé pour GitHub Pages avec base-href /presto_app/
"""
import os
import shutil
import sys

def sync_build_to_docs():
    source = 'build/web'
    destination = 'docs'
    
    if not os.path.exists(source):
        print(f"❌ {source} n'existe pas")
        sys.exit(1)
    
    # Supprimer destination si elle existe
    if os.path.exists(destination):
        shutil.rmtree(destination)
        print(f'✅ Répertoire {destination}/ supprimé')
    
    # Copier tous les fichiers
    shutil.copytree(source, destination)
    print(f'✅ Fichiers copiés de {source}/ vers {destination}/')
    
    # Créer .nojekyll
    nojekyll = os.path.join(destination, '.nojekyll')
    open(nojekyll, 'w').close()
    print(f'✅ Fichier {nojekyll} créé')
    
    # Copier 404.html si index.html existe
    index_html = os.path.join(destination, 'index.html')
    if os.path.exists(index_html):
        shutil.copy(index_html, os.path.join(destination, '404.html'))
        print(f'✅ 404.html créé pour SPA routing')
    
    # Lister les fichiers principaux
    print('\n📁 Fichiers dans docs/:')
    items = sorted(os.listdir(destination))
    for item in items[:20]:
        path = os.path.join(destination, item)
        if os.path.isfile(path):
            size = os.path.getsize(path)
            size_str = f"{size/1024:.1f}KB" if size > 1024 else f"{size}B"
            print(f'  ✓ {item} ({size_str})')
        elif os.path.isdir(path):
            print(f'  📂 {item}/')

if __name__ == '__main__':
    sync_build_to_docs()
    print('\n✅ Synchronisation terminée!')
