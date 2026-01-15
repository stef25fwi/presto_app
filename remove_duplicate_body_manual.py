#!/usr/bin/env python3
"""
Script pour supprimer le bloc body: Stack dupliqué (lignes 4495-4559)

Ce script:
1. Lit le fichier main.dart
2. Supprime les lignes 4495 à 4559 (indices 4494-4558)
3. Écrit le résultat dans un nouveau fichier temporaire
4. Remplace l'ancien fichier par le nouveau

Usage: python3 remove_duplicate_body_manual.py
"""

def main():
    file_path = '/workspaces/presto_app/lib/main.dart'
    
    print("Lecture du fichier main.dart...")
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    total = len(lines)
    print(f"  Total lignes: {total}")
    
    # Lignes à supprimer: 4495-4559 (indices 4494-4558 inclus)
    start_delete = 4494
    end_delete = 4558
    
    print(f"Suppression des lignes {start_delete+1} à {end_delete+1}...")
    
    # Créer le nouveau contenu
    new_lines = lines[:start_delete] + lines[end_delete+1:]
    
    new_total = len(new_lines)
    removed = total - new_total
    
    print(f"  Lignes supprimées: {removed}")
    print(f"  Nouveau total: {new_total}")
    
    # Écrire le résultat
    print("Écriture du fichier corrigé...")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print("✅ Fichier corrigé avec succès!")
    print(f"   {removed} lignes ont été supprimées.")
    print(f"   Le fichier contient maintenant {new_total} lignes.")

if __name__ == '__main__':
    main()
