# Publication : reprise durable du brouillon (U01)

## Problème

Le formulaire restait monté pendant les changements d'onglet, mais un
rechargement du navigateur ou un redémarrage de l'application supprimait la
saisie. Une publication longue pouvait donc être perdue avant sa validation.

## Correction

- Les champs du formulaire sont sauvegardés localement après un court délai,
  puis restaurés au prochain chargement pour le même compte.
- Le brouillon est isolé par identifiant Firebase et les données d'un ancien
  compte sont supprimées lorsqu'un autre compte devient actif.
- La sauvegarde expire après sept jours.
- La réinitialisation, une publication réussie, la déconnexion et la
  suppression du compte effacent la sauvegarde.
- Une publication qui échoue conserve le brouillon afin de permettre une
  nouvelle tentative.

Les photos ne sont pas enregistrées dans les préférences locales : les URL et
fichiers temporaires produits par les sélecteurs Web, Android et iOS ne sont
pas fiables après un redémarrage. Les champs texte, la catégorie, la ville, le
téléphone, le délai, le budget et le choix de confidentialité sont restaurés.

## Sécurité et confidentialité

Le stockage est limité au compte actif et à sept jours. Chaque sortie de
session purge explicitement son brouillon. Les données mal formées, issues
d'une autre version, associées à un autre compte, expirées ou horodatées dans
le futur sont rejetées puis supprimées.

## Vérification

- Tests du stockage : sérialisation complète, expiration, corruption,
  isolation entre comptes et purge explicite.
- Test widget : restauration du formulaire, modification sauvegardée après le
  délai et suppression durable lors de la réinitialisation.
- Tests Auth : purge à la déconnexion et après suppression du compte.

Le hero Home et ses trois affiches restent hors de ce lot.
