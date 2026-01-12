#!/usr/bin/env python3
"""
Script pour retirer le slide "Boîte à outils de l'entrepreneur" du main.dart
Lit le fichier backup et crée une nouvelle version sans ce slide
"""

import re
import sys

# Lire le fichier backup
with open('/workspaces/presto_app/lib/main.dart.backup', 'r', encoding='utf-8') as f:
    content = f.read()

print("📖 Fichier backup lu")
print(f"   Nombre de caractères: {len(content)}")

# Étape 1: Supprimer le slide "Boîte à outils de l'entrepreneur"
# Ce bloc est entre ligne ~577-583
pattern1 = r'    _HomeSlide\(\s*title: "Boîte à outils de l\'entrepreneur",\s*subtitle: "Liens utiles CCI, Région, aides et infos clés\.",\s*badge: "Pro",\s*icon: Icons\.business_center_outlined,\s*\),\s*'

content_before_1 = len(content)
content = re.sub(pattern1, '', content)
content_after_1 = len(content)

if content_before_1 != content_after_1:
    print(f"✅ Slide supprimé (différence: {content_before_1 - content_after_1} caractères)")
else:
    print("⚠️  Slide non trouvé - tentative avec pattern alternatif")
    # Alternative pattern sans espaces excessifs
    pattern1_alt = r'    _HomeSlide\(\n      title: "Boîte à outils de l\'entrepreneur",\n      subtitle: "Liens utiles CCI, Région, aides et infos clés\.",\n      badge: "Pro",\n      icon: Icons\.business_center_outlined,\n    \),'
    content = re.sub(pattern1_alt, '', content)
    print("✅ Pattern alternatif appliqué")

# Étape 2: Supprimer le bloc if (index == 1)
# Cherchons le pattern exact qui affiche ce slide
pattern2 = r'                          // ✅ SLIDE 2 \(index 1\) : design custom "Boîte à outils"\s*if \(index == 1\) \{\s*return GestureDetector\(\s*onTap: _openEntrepreneurToolbox,\s*child: const EntrepreneurToolboxSlide\(\),\s*\);\s*\}\s*'

content_before_2 = len(content)
content = re.sub(pattern2, '', content)
content_after_2 = len(content)

if content_before_2 != content_after_2:
    print(f"✅ Bloc if (index == 1) supprimé (différence: {content_before_2 - content_after_2} caractères)")
else:
    print("⚠️  Bloc if (index == 1) non trouvé")

# Sauvegarder dans le fichier main.dart
with open('/workspaces/presto_app/lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print(f"💾 Fichier main.dart sauvegardé ({len(content)} caractères)")
print("✅ Modifications effectuées avec succès!")
