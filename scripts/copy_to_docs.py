#!/usr/bin/env python3
import shutil
import os
from pathlib import Path

# Chemins source et destination
source_dir = Path("/workspaces/presto_app/build/web")
dest_dir = Path("/workspaces/presto_app/docs")

# Créer le répertoire docs s'il n'existe pas
dest_dir.mkdir(parents=True, exist_ok=True)

# Fichiers individuels à copier
files_to_copy = [
    "main.dart.js",
    "manifest.json",
    "version.json"
]

# Copier les fichiers individuels
for file_name in files_to_copy:
    source_file = source_dir / file_name
    dest_file = dest_dir / file_name
    
    if source_file.exists():
        print(f"Copie: {file_name}")
        shutil.copy2(source_file, dest_file)
    else:
        print(f"⚠️  Fichier non trouvé: {source_file}")

# Répertoires à copier
dirs_to_copy = ["icons", "assets"]

for dir_name in dirs_to_copy:
    source_dir_path = source_dir / dir_name
    dest_dir_path = dest_dir / dir_name
    
    if source_dir_path.exists():
        print(f"Copie du répertoire: {dir_name}")
        if dest_dir_path.exists():
            shutil.rmtree(dest_dir_path)
        shutil.copytree(source_dir_path, dest_dir_path)
    else:
        print(f"⚠️  Répertoire non trouvé: {source_dir_path}")

# Créer .nojekyll
nojekyll_file = dest_dir / ".nojekyll"
print(f"Création: .nojekyll")
nojekyll_file.touch()

# Créer 404.html pour GitHub Pages
html_404 = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Presto App</title>
    <script>
        var pathparts = location.pathname.split('/');
        var i = pathparts.length - 1;
        while (i >= 0) {
            if (pathparts[i] !== '') {
                pathparts.splice(i + 1, pathparts.length - i - 1);
                location.replace(pathparts.join('/') + '/?p=' + location.pathname.slice(1).replace(/\//g, '~') + location.search);
                return;
            }
            i--;
        }
    </script>
</head>
<body></body>
</html>
"""

print(f"Création: 404.html")
with open(dest_dir / "404.html", "w") as f:
    f.write(html_404)

print("\n✅ Copie terminée!")
