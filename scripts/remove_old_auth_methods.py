#!/usr/bin/env python3

# Lire le fichier
with open('lib/main.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f"Fichier original: {len(lines)} lignes")

# Supprimer les 3 méthodes non utilisées
# 1. _signInWithEmail: lignes 8754-8806 (indices 8753-8805)
# 2. _registerWithEmail: lignes 8810-8836 (indices 8809-8835)
# 3. _resetPassword: lignes 9551-9594 (indices 9550-9593)

# Attention: après suppression de la première, les indices changent!
# Donc on supprime de la fin vers le début

# _resetPassword (9551-9594, indices 9550-9593)
lines_before_reset = lines[:9550]
lines_after_reset = lines[9594:]
print(f"Suppression _resetPassword: lignes 9551-9594")

# Recalculer (maintenant on a moins de lignes)
temp_lines = lines_before_reset + lines_after_reset

# _registerWithEmail (8810-8836, indices 8809-8835)  
lines_before_register = temp_lines[:8809]
lines_after_register = temp_lines[8836:]
print(f"Suppression _registerWithEmail: lignes 8810-8836")

temp_lines = lines_before_register + lines_after_register

# _signInWithEmail (8754-8806, indices 8753-8805)
lines_before_signin = temp_lines[:8753]
lines_after_signin = temp_lines[8806:]
print(f"Suppression _signInWithEmail: lignes 8754-8806")

new_lines = lines_before_signin + lines_after_signin

# Écrire
with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"✅ Fichier nettoyé: {len(lines)} → {len(new_lines)} lignes")
print(f"Supprimé {len(lines) - len(new_lines)} lignes au total")
