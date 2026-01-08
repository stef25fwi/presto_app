#!/usr/bin/env python3

# Lire le fichier
with open('lib/main.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f"Fichier original: {len(lines)} lignes")

# Supprimer les lignes de 9606 à 9890 (indices 9605 à 9889 en Python - 0-indexed)
# La ligne 9605 contient le commentaire qu'on garde
new_lines = lines[:9605] + lines[9890:]

# Écrire
with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"✅ Ancienne méthode _buildProfile supprimée (lignes 9606-9890)")
print(f"Fichier réduit à {len(new_lines)} lignes")
