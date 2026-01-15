#!/usr/bin/env python3
"""Remove duplicate body: Stack declaration from main.dart"""

def fix_duplicate_body():
    file_path = '/workspaces/presto_app/lib/main.dart'
    
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # On cherche le premier body: Stack( qui se termine avant le second
    # Premier body: Stack commence vers ligne 4495 (index 4494)
    # Il se termine vers ligne 4551 (index 4550) avec "      ),\n"
    # Le deuxième body: Stack( commence à ligne 4552 (index 4551)
    
    # Supprimons les lignes 4495-4551 (indices 4494-4550 inclus)
    start_delete = 4494  # ligne 4495 (index 0-based)
    end_delete = 4550    # ligne 4551 (index 0-based)
    
    # Créer le nouveau contenu sans ces lignes
    new_lines = lines[:start_delete] + lines[end_delete+1:]
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"✅ Supprimé les lignes {start_delete+1}-{end_delete+1}")
    print(f"   Ancien total: {len(lines)} lignes")
    print(f"   Nouveau total: {len(new_lines)} lignes")
    print(f"   Lignes supprimées: {len(lines) - len(new_lines)}")

if __name__ == '__main__':
    fix_duplicate_body()
