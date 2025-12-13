#!/usr/bin/env python3
"""Script pour supprimer les doublons dans les fichiers cities_*.json"""

import json
import os
from collections import OrderedDict

CITIES_DIR = "assets/data/cities"

def remove_duplicates_in_file(filepath):
    """Supprime les doublons dans un fichier JSON de villes"""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Utiliser un dict pour garder seulement la première occurrence
    seen = OrderedDict()
    duplicates_count = 0
    
    for entry in data:
        name = entry.get('name', '').strip().upper()
        cp = entry.get('cp', '').strip()
        key = (name, cp)
        
        if key not in seen:
            seen[key] = entry
        else:
            duplicates_count += 1
    
    # Reconstruire la liste sans doublons
    cleaned_data = list(seen.values())
    
    if duplicates_count > 0:
        # Sauvegarder le fichier nettoyé
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(cleaned_data, f, ensure_ascii=False, indent=2)
        print(f"✅ {os.path.basename(filepath)}: {duplicates_count} doublon(s) supprimé(s)")
        return duplicates_count
    else:
        print(f"✓ {os.path.basename(filepath)}: aucun doublon")
        return 0

def main():
    if not os.path.exists(CITIES_DIR):
        print(f"❌ Dossier {CITIES_DIR} introuvable")
        return
    
    total_duplicates = 0
    files_processed = 0
    
    for filename in sorted(os.listdir(CITIES_DIR)):
        if not filename.startswith('cities_') or not filename.endswith('.json'):
            continue
        
        filepath = os.path.join(CITIES_DIR, filename)
        try:
            count = remove_duplicates_in_file(filepath)
            total_duplicates += count
            files_processed += 1
        except Exception as e:
            print(f"❌ Erreur sur {filename}: {e}")
    
    print(f"\n📊 Résumé: {files_processed} fichiers traités, {total_duplicates} doublons supprimés au total")

if __name__ == "__main__":
    main()
