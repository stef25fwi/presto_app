# Standard SEO des pages publiques iliprestō

Le point 4 impose une norme commune à toutes les pages destinées aux moteurs de recherche et aux visiteurs non connectés.

## Inventaire contrôlé

| URL canonique | Rôle |
|---|---|
| `https://ilipresto.fr/` | accueil national |
| `https://ilipresto.fr/a-propos` | profil public de l’organisation |
| `https://ilipresto.fr/guides/comment-fonctionne-ilipresto` | guide d’utilisation |
| `https://ilipresto.fr/guadeloupe` | lancement territorial Guadeloupe |
| `https://ilipresto.fr/martinique` | lancement territorial Martinique |
| `https://ilipresto.fr/guyane` | lancement territorial Guyane |
| `https://ilipresto.fr/mentions-legales` | mentions légales |
| `https://ilipresto.fr/confidentialite` | politique de confidentialité |
| `https://ilipresto.fr/cgu` | conditions générales d’utilisation |
| `https://ilipresto.fr/suppression-compte` | procédure de suppression du compte |

## Exigences obligatoires

Chaque page possède un `title`, un H1 et une meta description uniques, une URL stable, une canonical absolue, un contenu accessible sans authentification, un fil d’Ariane lorsque la page n’est pas l’accueil, des liens HTML internes, un texte alternatif pour le logo et des données structurées JSON-LD adaptées à son contenu.

Les cinq pages éditoriales ou territoriales sont de vraies pages HTML servies directement par Firebase Hosting. Les pages légales conservent leur contenu Flutter complet, mais leur title, leur description, leur canonical, leur H1, leur fil d’Ariane et leurs données structurées sont adaptés avant la première frame Flutter.

Les variantes avec slash final et les fichiers `.html` des pages HTML redirigent en HTTP 301 vers la forme canonique. Les dix URL canoniques sont contrôlées en production après chaque déploiement réussi.

## Contrôle automatique

```bash
node tools/quality/check_public_page_seo.mjs
node tools/quality/check_structured_data.mjs
```

Le workflow de préparation vérifie les métadonnées, le sitemap, le maillage, les graphes JSON-LD et les règles Firebase. Le workflow post-déploiement contrôle ensuite les dix URL réelles sur `ilipresto.fr`.
