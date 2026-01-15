#!/usr/bin/env python3
"""
Correction finale du fichier lib/main.dart en supprimant les lignes 4495-4558
et gardant uniquement la bonne section du détail de l'offre.

Approche : lire le fichier, identifier les lignes à supprimer, réécrire proprement.
"""

import sys

def fix_main_dart():
    filepath = '/workspaces/presto_app/lib/main.dart'
    
    # Lire le fichier
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    print(f"[INFO] Fichier lu: {len(lines)} lignes")
    
    # Les lignes 4495-4558 (0-indexed: 4494-4557)
    # Supprimer ces lignes
    # On garde les lignes de 0 à 4493 (lignes 1-4494)
    # Puis on ajoute les lignes de 4558+ (lignes 4559+)
    
    # Lignes à conserver
    keep_lines = lines[:4494] + lines[4558:]
    
    print(f"[INFO] Après suppression: {len(keep_lines)} lignes")
    print(f"[INFO] Lignes supprimées: {4558 - 4494} = 64 lignes")
    
    # Réécrire le fichier
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(keep_lines)
    
    print(f"[SUCCESS] Fichier corrigé: {filepath}")
    return 0

if __name__ == '__main__':
    sys.exit(fix_main_dart())
