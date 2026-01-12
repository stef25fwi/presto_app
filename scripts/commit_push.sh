#!/bin/bash
set -e

# Se placer à la racine du repo (comme avant)
cd /workspaces/presto_app

git add -A

# Si un message est passé en argument, l'utiliser. Sinon, garder le message multi‑ligne existant.
if [[ -n "${1:-}" ]]; then
	git commit -m "$1"
else
	git commit -m "feat: page Mon compte - sections encadrées + édition profil + suppression annonces

- Ajout mode édition pour les champs du profil (modifier/enregistrer)
- Création de 4 sections encadrées principales: Mon profil, Mes messages, Mes annonces publiées, Mes catégories favorites
- Affichage dynamique des annonces de l'utilisateur avec StreamBuilder
- Implémentation suppression d'annonces avec popup de confirmation (fond blanc)
- Vérification des droits utilisateur avant suppression
- Support du champ ownerId dans les règles Firestore
- Ajout du paramètre enabled aux widgets PhoneInputFieldCompact et _buildStyledDropdown
- Formatage intelligent des dates (il y a X min/h/jours...)
- Design Material 3 avec cartes à bordure colorée et en-têtes stylisés"
fi

git push

echo "✅ Commit et push terminés!"
