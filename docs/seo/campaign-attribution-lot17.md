# Lot 17 — Attribution UTM et deep links

## Objectif

Relier chaque campagne à sa première visite, sa dernière visite et aux événements produit, puis ouvrir les destinations iliprestō de manière cohérente sur le Web, Android et iOS.

## Format de lien canonique

```text
https://ilipresto.fr/app/<destination>?utm_source=...&utm_medium=...&utm_campaign=...
```

Destinations prises en charge :

- `/app/offers/<id>` ;
- `/app/listings/<id>` ;
- `/app/profile/<id>` ;
- `/app/messages/<id>` ;
- `/app/messages-2/<id>` ;
- `/app/publish` ;
- `/app/account`.

Un schéma de secours Android est également accepté :

```text
ilipresto://offers/<id>?utm_source=push&utm_medium=notification&utm_campaign=reactivation
```

## Paramètres reconnus

- `utm_source` ;
- `utm_medium` ;
- `utm_campaign` ;
- `utm_id` ;
- `utm_term` ;
- `utm_content` ;
- `gclid`, `dclid`, `gbraid`, `wbraid`, `fbclid`, `ttclid`, `msclkid`.

Les valeurs des identifiants de clic ne sont jamais envoyées comme paramètres personnalisés. Seul leur type est conservé afin d’éviter de recopier un identifiant publicitaire opaque dans les événements produit.

## Consentement et conservation

La capture de l’URL est transitoire tant qu’aucun choix n’a été effectué. La persistance, les événements GA4 et l’enrichissement des événements produit ne sont activés qu’après consentement Analytics explicite.

- première touche : conservée 90 jours ;
- dernière touche : actualisée à chaque nouvelle campagne et conservée 90 jours ;
- refus Analytics : suppression des attributions persistées et de la capture en attente ;
- aucun identifiant utilisateur ajouté par ce lot.

## Événements

- `campaign_landing` : nouvelle arrivée attribuée ;
- `deep_link_open` : arrivée attribuée vers une destination applicative ;
- événements produit existants : enrichis avec les dimensions `first_*` et `last_*` lorsque le consentement Analytics est actif.

## Associations natives

Android :

- package `fr.ilipresto.app` ;
- App Links `https://ilipresto.fr/app/*` ;
- `android:autoVerify="true"` ;
- empreinte SHA-256 extraite du vrai keystore de publication pendant le workflow.

iOS :

- bundle `fr.ilipresto.app` ;
- domaine associé `applinks:ilipresto.fr` ;
- App ID construit depuis le vrai `IOS_TEAM_ID` ;
- chemins `/app` et `/app/*`.

Les fichiers servis sont :

- `/.well-known/assetlinks.json` ;
- `/.well-known/apple-app-site-association`.

## Certification

Le workflow `.github/workflows/campaign-attribution-lot17.yml` démarre après un déploiement Firebase réussi. Il :

1. exécute les tests Dart et le contrat Node ;
2. construit le Web du SHA déployé ;
3. génère les associations depuis les vrais secrets de signature ;
4. déploie Hosting avec les fichiers `.well-known` ;
5. vérifie en production le lien Web avec UTM, Android App Links et iOS Universal Links ;
6. archive les rapports 90 jours ;
7. publie `quality/campaign-attribution-lot17` ;
8. ouvre ou ferme l’issue de diagnostic du lot 17.

Les contrôles `campaign_attribution` et `deep_links_campaigns` restent `pending` tant que ce statut n’est pas vert sur le SHA réellement déployé.
