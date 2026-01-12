#!/usr/bin/env python3
import re

# Lire le fichier
with open('/workspaces/presto_app/lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Supprimer le slide "Boîte à outils de l'entrepreneur"
pattern1 = r'    _HomeSlide\(\s*title: "Boîte à outils de l\'entrepreneur",\s*subtitle: "Liens utiles CCI, Région, aides et infos clés\.",\s*badge: "Pro",\s*icon: Icons\.business_center_outlined,\s*\),\n'
content = re.sub(pattern1, '', content)

# 2. Supprimer le bloc if (index == 1) et le commentaire associé
pattern2 = r'                          // ✅ SLIDE 2 \(index 1\) : design custom "Boîte à outils"\s*if \(index == 1\) \{\s*return GestureDetector\(\s*onTap: _openEntrepreneurToolbox,\s*child: const EntrepreneurToolboxSlide\(\),\s*\);\s*\}\n\n'
content = re.sub(pattern2, '', content)

# 3. Aussi adapter le commentaire si nécessaire
pattern3 = r'// 🔁 SLIDES 4, 5 : layout texte \+ icône / image'
content = re.sub(pattern3, '// 🔁 SLIDES 2, 3, 4 : layout texte + icône / image', content)

# Sauvegarder
with open('/workspaces/presto_app/lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Modifications effectuées avec succès!")
