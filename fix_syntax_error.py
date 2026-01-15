#!/usr/bin/env python3
"""
Corrige l'erreur de syntaxe à la ligne 5487-5490 dans main.dart
Remplace les paramètres orphelins par le texte manquant pour fermer le Row
"""

def fix_syntax():
    file_path = '/workspaces/presto_app/lib/main.dart'
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Chercher et remplacer le bloc corrompu
    old_block = """                      const SizedBox(width: 8),
            // ✅ CTA sticky comme le mockup
                 onPressed: () => _showActionSheet(context),
                  child: const Text("Accepter l'offre"),
                ),
              ),
            ],"""
    
    new_block = """                      const SizedBox(width: 8),
                      Text(
                        'Signaler',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],"""
    
    if old_block in content:
        content = content.replace(old_block, new_block)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("✅ Syntaxe corrigée avec succès!")
        return True
    else:
        print("❌ Bloc à corriger non trouvé")
        return False

if __name__ == '__main__':
    fix_syntax()
