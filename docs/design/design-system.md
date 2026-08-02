# Design system iliprestō

## Statut

- Version : 1.0
- Point du programme : 2 — UX/UI et design system
- Statut : base normative créée, vérification d’implémentation en cours
- Référence publique : `https://ilipresto.fr`

## Principes

Le design iliprestō doit être clair, rassurant, rapide à comprendre et utilisable sur mobile, tablette et ordinateur. L’interface évite les éléments décoratifs non fonctionnels et privilégie les surfaces simples, une hiérarchie visuelle nette et des actions explicites.

## Identité visuelle

| Élément | Valeur normative |
|---|---|
| Bleu principal | `#1A73E8` |
| Orange d’accent | `#FF6600` |
| Fond principal | blanc ou surface neutre claire |
| Police principale | Inter |
| Logo | carré arrondi bleu/orange, double « i » blanc et sourire blanc |
| Style | propre, premium, sans bulles décoratives ni beige `#F9F2EA` |

Les couleurs ne doivent jamais être l’unique moyen de transmettre un état. Chaque état critique associe couleur, texte et, lorsque pertinent, icône ou symbole.

## Typographie

- un seul système typographique principal basé sur Inter ;
- titres courts, explicites et hiérarchisés ;
- corps de texte lisible sans zoom ;
- aucune information critique en taille inférieure à 14 px CSS équivalent ;
- prise en charge du redimensionnement de texte sans troncature ni chevauchement ;
- contraste conforme WCAG AA pour le texte et les composants interactifs.

## Espacement et grilles

- grille de base : 4 px ;
- espacements usuels : 4, 8, 12, 16, 24, 32 et 48 px ;
- largeur de contenu bornée sur grand écran ;
- marges latérales adaptées aux largeurs 320, 360, 390, 430, 600, 768, 1024, 1280 et 1440 px ;
- aucune action principale collée au bord ou masquée par une zone système.

## Composants

### Boutons

- libellé orienté action ;
- hauteur tactile minimale de 48 px ;
- état normal, survol, focus, pressé, chargement et désactivé ;
- focus visible au clavier ;
- une seule action principale dominante par zone.

### Champs

- label persistant ou explicitement associé ;
- aide et erreur placées près du champ ;
- erreur formulée avec cause et action corrective ;
- ordre de tabulation logique ;
- clavier et type de saisie adaptés au contenu.

### Cartes et tuiles

- tailles cohérentes dans une même grille ;
- information principale visible sans ouvrir la carte ;
- zone cliquable complète lorsque la carte représente une action unique ;
- aucune différence de hauteur arbitraire entre cartes équivalentes.

### Dialogues et confirmations

- titre décrivant précisément l’action ;
- conséquence explicite avant une suppression ;
- action destructive visuellement distincte ;
- annulation toujours disponible, sauf opération irréversible déjà engagée.

## États d’écran

Chaque écran alimenté par des données doit prévoir :

1. chargement avec libellé ou squelette stable ;
2. état vide expliquant quoi faire ;
3. erreur exploitable avec nouvelle tentative ;
4. succès ou confirmation lorsque l’action modifie des données ;
5. état hors connexion lorsque la distinction est utile.

## Accessibilité

- cibles tactiles de 48 × 48 px minimum ;
- focus clavier visible et ordre logique ;
- éléments interactifs décrits par une sémantique exploitable ;
- images informatives avec description et images décoratives exclues de la sémantique ;
- aucune interaction disponible uniquement par geste complexe ;
- respect des réglages de taille de texte et de réduction des animations ;
- contraste AA vérifié avec preuve mesurée.

## Responsive

- navigation compacte sur mobile ;
- adaptation tablette à partir de 600 px lorsque la densité d’information le justifie ;
- contenu principal borné sur desktop ;
- aucune largeur fixe empêchant l’usage à 320 px ;
- tests obligatoires avec texte agrandi à 200 % sur les parcours principaux.

## Critère de validation

Ce document ne suffit pas à déclarer le contrôle `design-system` vérifié. La clôture exige que les composants du dépôt utilisent réellement les règles centrales, que les exceptions soient recensées et que les audits responsive et accessibilité soient verts.