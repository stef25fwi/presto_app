#!/usr/bin/env python3

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f"Fichier original: {len(lines)} lignes")

# Commenter les lignes utilisant _isLoading aux lignes spécifiées
# Lignes 9236, 9250, 9315, 9465 (indices 9235, 9249, 9314, 9464)
lines_to_comment = [9235, 9249, 9314, 9464]

for idx in lines_to_comment:
    if idx < len(lines) and '_isLoading' in lines[idx]:
        # Indentation + commentaire
        stripped = lines[idx].lstrip()
        indent = lines[idx][:len(lines[idx]) - len(stripped)]
        lines[idx] = f"{indent}// {stripped}"
        print(f"Commenté ligne {idx+1}: {stripped.strip()}")

# Écrire
with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"✅ Fichier modifié avec {len([i for i in lines_to_comment if i < len(lines)])} commentaires")
