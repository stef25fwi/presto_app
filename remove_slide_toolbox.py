#!/usr/bin/env python3
"""
Script pour retirer le slide "Boîte à outils de l'entrepreneur" du main.dart
"""

import re

# Lire le fichier backup
with open('/workspaces/presto_app/lib/main.dart.backup', 'r', encoding='utf-8') as f:
    content = f.read()

print("📖 Fichier backup lu")
print(f"   Lignes initiales: {len(content.splitlines())}")

# Supprimer le slide dans la liste _slides
pattern1 = r'    _HomeSlide\(\n      title: "Boîte à outils de l\'entrepreneur",\n      subtitle: "Liens utiles CCI, Région, aides et infos clés\.",\n      badge: "Pro",\n      icon: Icons\.business_center_outlined,\n    \),\n'

content_before = len(content)
content = re.sub(pattern1, '', content, count=1)
content_after = len(content)

if content_before != content_after:
    print(f"✅ Slide supprimé de la liste _slides (réduction: {content_before - content_after} caractères)")
else:
    print("⚠️  Slide non trouvé dans la liste")

# Sauvegarder le fichier main.dart
with open('/workspaces/presto_app/lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print(f"💾 Fichier main.dart sauvegardé ({len(content)} caractères)")
print(f"   Lignes finales: {len(content.splitlines())}")
print("✅ Modifications effectuées avec succès!")
