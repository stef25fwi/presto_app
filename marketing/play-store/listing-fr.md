# Fiche Play Store — français (fr-FR)

Brouillon à relire avant saisie dans Play Console. Les limites de caractères
sont celles imposées par la console ; elles sont vérifiées par
`tools/quality/check_play_listing.mjs`.

Positionnement repris de `web/index.html` et des valeurs par défaut de
`PublicLandingConfigService` afin que la fiche, le site et la page de
préouverture racontent la même chose.

---

## Titre (30 caractères max)

```
iliprestō — services locaux
```

> 27 caractères. Autres variantes tenant dans la limite :
> `iliprestō : services locaux` (27) · `iliprestō — services du jour` (28).
> `iliprestō : services près de vous` (33) dépasse et serait tronqué.

## Description courte (80 caractères max)

```
Trouvez près de chez vous un particulier ou un pro pour vos services du jour.
```

Variante : `Annonces de services locaux, mise en relation directe, 0 % de commission.` (72)

## Description longue (4 000 caractères max)

```
iliprestō met en relation particuliers, indépendants et professionnels pour
les services et microservices du quotidien. Publier une annonce, trouver
quelqu'un près de chez soi et échanger directement : tout se fait dans
l'application, sans intermédiaire et sans commission.

TROUVER UN SERVICE
Parcourez les annonces publiées autour de vous, filtrez par ville, par code
postal et par type de service, puis contactez directement la personne qui
vous intéresse. Chaque annonce indique clairement la zone couverte et le
budget attendu.

PUBLIER EN QUELQUES MINUTES
Décrivez ce que vous proposez ou ce que vous cherchez, ajoutez des photos,
indiquez votre ville et votre budget. Une assistance par intelligence
artificielle vous aide à rédiger une annonce claire et complète si vous le
souhaitez — vous gardez la main sur le texte final.

ÉCHANGER DIRECTEMENT
La messagerie intégrée vous permet de discuter, d'envoyer des photos et des
messages vocaux, et de convenir des détails avant de vous engager. Vous êtes
prévenu par notification dès qu'un message arrive.

DES OUTILS POUR SE LANCER
Un parcours guidé accompagne celles et ceux qui démarrent une activité :
fiches pratiques selon votre statut — salarié, indépendant, fonctionnaire,
étudiant, retraité, demandeur d'emploi — et documents à conserver ou à
partager.

UNE COMMUNAUTÉ SURVEILLÉE
Chaque annonce et chaque conversation peuvent être signalées en un geste, et
vous pouvez bloquer un utilisateur à tout moment. Les signalements sont
traités par notre équipe de modération.

VOS DONNÉES
Vous consultez, modifiez et supprimez vos informations depuis votre compte.
La suppression du compte est possible à tout moment depuis l'application, et
la procédure est également décrite sur ilipresto.fr/suppression-compte.

Confidentialité : https://ilipresto.fr/confidentialite
Conditions d'utilisation : https://ilipresto.fr/cgu
```

## Ressources graphiques

| Élément | Format exigé | État |
|---|---|---|
| Icône | 512 × 512 PNG 32 bits | **généré** — `marketing/play-store/graphics/icon-512.png` (`tools/android/generate_adaptive_icon.py`) |
| Image de mise en avant | 1024 × 500 PNG ou JPEG | à produire |
| Captures téléphone | 2 à 8, min. 320 px de côté | à produire |
| Captures tablette 7" et 10" | requises si la tablette est déclarée | à décider |
| Vidéo promotionnelle | URL YouTube | facultatif |

Captures suggérées, dans cet ordre : liste d'annonces filtrée par ville ·
détail d'une annonce · rédaction assistée par IA · messagerie · parcours
« je me lance » · écran de compte.

> Les captures doivent provenir d'un build réel : Play refuse les maquettes
> qui ne correspondent pas à l'interface livrée.

## Coordonnées et classement

- **Catégorie** : Maison et confort, ou Style de vie — à trancher selon la
  concurrence observée sur la requête « services près de chez moi ».
- **E-mail de contact** : adresse de l'éditeur, identique à celle des
  mentions légales.
- **Site web** : `https://ilipresto.fr`
- **Politique de confidentialité** : `https://ilipresto.fr/confidentialite`

## Zones de diffusion

Ouverture annoncée en Guadeloupe, Martinique et Guyane
(`PublicLandingConfigService.defaultLaunchMessage`). Décider si la fiche est
publiée pour la France entière dès le départ ou restreinte à ces
départements pendant la phase bêta — ce choix conditionne le volume de
testeurs disponibles pour le test fermé.
