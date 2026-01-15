#!/usr/bin/env python3
import re

file_path = '/workspaces/presto_app/lib/main.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Trouver et corriger les lignes 5487-5490
# Chercher la ligne avec "// ✅ CTA sticky"
for i, line in enumerate(lines):
    if 'CTA sticky' in line:
        print(f"Trouvé à la ligne {i+1}: {line.strip()}")
        
        # Vérifier les 3 lignes suivantes
        if i+1 < len(lines) and 'onPressed' in lines[i+1]:
            # Remplacer les 3 lignes suivantes
            indent = ' ' * 22  # Indentation correcte
            
            lines[i] = indent + 'Text(\n'
            lines[i+1] = indent + "  'Signaler',\n"
            
            # Insérer les nouvelles lignes
            new_lines = [
                indent + "  style: TextStyle(\n",
                indent + "    color: Colors.red.shade700,\n",
                indent + "    fontWeight: FontWeight.w600,\n",
                indent + "  ),\n",
                indent + "),\n"
            ]
            
            # Remplacer les anciennes lignes
            lines[i+2:i+5] = new_lines
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            
            print("✅ Corrigé avec succès!")
            break
else:
    print("❌ Ligne non trouvée")
