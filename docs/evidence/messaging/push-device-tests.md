# Point 7 — Notifications sur appareils

## Matrice minimale

| Plateforme | Premier plan | Arrière-plan | Application fermée | Ouverture vers le bon fil |
|---|---|---|---|---|
| Android | à prouver | à prouver | à prouver | à prouver |
| Web mobile | à prouver | à prouver | à prouver | à prouver |
| Web desktop | à prouver | à prouver | à prouver | à prouver |
| iOS | à prouver | à prouver | à prouver | à prouver |

## Scénario de preuve

1. connecter deux comptes distincts A et B ;
2. ouvrir le même fil sur A ;
3. placer B successivement au premier plan, en arrière-plan puis application fermée ;
4. envoyer un message texte puis un média depuis A ;
5. vérifier une notification unique, sans contenu sensible excessif ;
6. toucher la notification et vérifier l’ouverture du bon fil ;
7. vérifier le compteur non lu puis sa remise à zéro après lecture ;
8. répéter après rotation du jeton FCM et après reconnexion ;
9. associer captures, journaux expurgés, versions et SHA testé.

## Critères bloquants

- aucune notification en double ;
- aucune notification adressée à l’expéditeur ;
- aucun jeton d’un autre compte conservé après déconnexion ;
- navigation fiable depuis une application fermée ;
- absence de texte privé dans les journaux ;
- gestion explicite du refus de permission et des jetons invalides.

Aucun contrôle de notification ne passe à `verified` sans preuve réelle sur la plateforme concernée.
