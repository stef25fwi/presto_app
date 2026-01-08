#!/usr/bin/env python3

# Lire le fichier
with open('lib/main.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f"Fichier original: {len(lines)} lignes")

# Trouver les deux définitions de _buildProfile
buildprofile_lines = []
for i, line in enumerate(lines):
    if 'Widget _buildProfile(User user) {' in line:
        buildprofile_lines.append(i)
        print(f"Trouvé _buildProfile à la ligne {i+1}")

if len(buildprofile_lines) >= 2:
    first = buildprofile_lines[0]
    second = buildprofile_lines[1]
    
    print(f"\nSuppression de la première définition (lignes {first+1} à {second})")
    
    # Garder tout avant la première définition + tout après la deuxième définition
    new_lines = lines[:first] + lines[second:]
    
    # Écrire
    with open('lib/main.dart', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"✅ Fichier nettoyé: {len(lines)} → {len(new_lines)} lignes")
    print(f"Supprimé {len(lines) - len(new_lines)} lignes")
else:
    print(f"❌ Trouvé seulement {len(buildprofile_lines)} définition(s)")
