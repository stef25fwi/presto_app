# Restrictions des clés API — 30 septembre 2026

Projet : `presto-app-74abe`. Auteur : Codex. Contrôle : `api-keys-restricted`.
**Statut : pending — collecte reçue, restrictions applicatives à corriger et valider.**

Le fichier de preuve était initialement absent. Les relevés opérateur ci-dessous
documentent maintenant les réglages GCP. Leur conformité reste à valider après
correction et essais sur les clients réels.

## Collecte en lecture seule depuis Cloud Shell

Dans le dépôt contenant les correctifs de la PR #1464 :

```bash
python3 tools/security/collect_external_evidence.py --github
```

Sans `gh` disponible et authentifié, omettre `--github` pour collecter GCP.
Le code 2 signifie collecte partielle ; les résultats obtenus sont conservés
sous `quality_reports/security-external/metadata.json`. Le collecteur liste
et décrit les clés sans appeler `get-key-string`, sans modifier les clés et
sans changer le registre. Les valeurs secrètes sont exclues de la sortie.

| Usage | Vérification requise |
|---|---|
| Web | Origines de production effectives, aucune origine universelle, API explicitement autorisées |
| Android | Package `fr.ilipresto.app`, empreintes de signature effectives, y compris signature Play si distribuée par Play |
| iOS | Bundle du binaire signé correspondant à Firebase et aux restrictions |
| Serveur / Places / VEO | Inventaire complet, APIs autorisées, restrictions compatibles avec l'exécution serveur |

Pour chaque clé, relever identifiant de ressource (jamais valeur), usage,
restrictions d'application, APIs autorisées, auteur et date. Réconcilier
les applications Firebase avec `GOOGLE_PLACES_API_KEY` et `VEO_API_KEY`.
Un export vide ou un refus IAM ne prouve pas la conformité. Ne pas appliquer
une restriction Web à une clé serveur. Après tout changement, valider Auth,
App Check et Places sur Web/Android/iOS avant attestation.

Lorsque le relevé réel est complet, remplacer cette preuve provisoire et
mettre ce seul contrôle à `verified` dans `quality/security-controls.json`.

Références :
- https://cloud.google.com/sdk/gcloud/reference/services/api-keys/list
- https://cloud.google.com/sdk/gcloud/reference/services/api-keys/describe

## Relevé Cloud Shell reçu le 30/09/2026

Source : export transmis par l'opérateur, collecté à
`2026-09-30T12:58:54.552838+00:00`, projet numérique `151421230024`.
Collecte sans erreur. Sept clés présentes, chacune avec une liste d'API
explicite. Aucune clé n'est attestée conforme par ce relevé.

| Clé / identifiant de ressource | Restrictions observées dans l'export |
|---|---|
| Clé API 1 — 69445b21-c1d7-4a51-94d8-18dc90869035 | API Vertex AI seule ; aucune restriction d'application exportée |
| iOS — 187a10af-5395-4c40-a949-6920e8905082 | Objet iOS vide ; liste de bundle IDs non renseignée dans l'export |
| Gemini — 200c59cd-42c3-4136-9c61-8f673b2ec9e6 | API generativelanguage seule ; aucune restriction d'application exportée |
| Browser — e489e9b6-ea2a-4634-9f48-1fd96ad6a19b | Objet Browser vide ; aucune origine exportée |
| Places serveur — 63c4c266-c0ec-44bf-b837-f39e33346749 | API places-backend seule ; aucune restriction d'application exportée |
| Android — 83512e8a-3c39-496f-b3a8-1dbddacdf97e | allowedApplications vide ; aucun couple package/empreinte exporté |
| Browser — 22d51620-5b04-490f-911e-9042a93a64a2 | Objet Browser vide ; aucune origine exportée |

Le second relevé direct transmis par l’opérateur le 30/09/2026 confirme les
objets vides sur les quatre clés clientes ; il ne s’agit pas d’une perte de
projection du collecteur.
Les champs camelCase du collecteur correspondent au schéma REST documenté.
Les fichiers Android, iOS et Firebase du dépôt déclarent `fr.ilipresto.app` ;
les empreintes de signature Android doivent venir des certificats réels,
notamment celui de Play si utilisé, jamais d'une valeur supposée.

Les trois clés serveur doivent être rapprochées de leurs usages. Une clé
serverless ne doit pas recevoir une restriction de referrer Web ou une IP
éphémère Cloud Shell : cela casserait Places/VEO. Conserver les scopes API
existants lors de l'ajout des restrictions clientes ; vérifier ensuite
Auth/App Check/Remote Config sur les plateformes concernées. Ne pas supprimer
les clés anciennes sans preuve qu'aucun client déployé ne les utilise.

**Décision : contrôle toujours pending.** L'accès de collecte est maintenant
prouvé par l'export opérateur, mais les restrictions attendues ne le sont pas.


## Correction préparée après confirmation directe

La clé iOS `187a10af-5395-4c40-a949-6920e8905082` n’a aucun bundle autorisé
renseigné. Le bundle du dépôt est `fr.ilipresto.app`. La commande suivante a été tentée par l’opérateur puis refusée par GCP ;
elle n’a donc pas ajouté la restriction :

```bash
gcloud services api-keys update 187a10af-5395-4c40-a949-6920e8905082 \
  --project=presto-app-74abe \
  --append \
  --allowed-bundle-ids=fr.ilipresto.app \
  --check-existing-usage
```

`--append` conserve les restrictions existantes. Le contrôle de trafic doit
rester activé ; une incompatibilité doit être investiguée avant toute reprise.
Après application, collecter les restrictions et tester Auth/App Check sur le
binaire iOS. Cette étape seule ne valide pas le contrôle global.

Avant modification Web/Android, relever `apiKeyId` des applications Firebase
et les certificats Android enregistrés (métadonnées, sans valeurs de clés).
L’association Firebase doit être rapprochée de la configuration des binaires
réellement distribués ; les certificats enregistrés ne prouvent pas à eux seuls
qu’ils couvrent toutes les signatures distribuées, notamment Play.

Le code `lib/firebase_options.dart` réutilise la clé Web sur Windows/Linux.
L’ajout de referrers sur cette clé exige de vérifier les clients effectivement
supportés et les autres usages. Les deux clés Browser ne doivent pas être
modifiées en bloc sans identification de leurs consommateurs. Aucune empreinte
Android n’est inventée. Aucun contrôle du registre n’est promu.

Références complémentaires :
- https://docs.cloud.google.com/sdk/gcloud/reference/services/api-keys/update
- https://firebase.google.com/docs/reference/firebase-management/rest/v1beta1/projects.webApps
- https://firebase.google.com/docs/reference/firebase-management/rest/v1beta1/projects.androidApps


## Résultat opérateur : protection de trafic et associations Firebase

Le 30/09/2026, la mise à jour iOS avec `--check-existing-usage` a échoué en
`FAILED_PRECONDITION` / `APIKEYS_RESTRICTION_INCOMPATIBLE_WITH_USAGE`.
GCP signale du trafic incompatible sur les sept derniers jours pour :
`generativelanguage.googleapis.com`, `places-backend.googleapis.com`,
`speech.googleapis.com`, `static-maps-backend.googleapis.com`.
Le diagnostic n’identifie pas les appelants et ne démontre pas que ces requêtes
ont réussi. Aucun contournement du contrôle, élargissement des API autorisées,
ou attribution à un secret serveur n’est décidé sur cette seule base.

Les ressources Firebase lues par l’opérateur confirment :

| Application | Clé associée | Identité |
|---|---|---|
| Web 1:151421230024:web:1f974719da2f98822b3efd | e489e9b6-ea2a-4634-9f48-1fd96ad6a19b | Application Web principale |
| Android 1:151421230024:android:339090c7418b3d7c2b3efd | 83512e8a-3c39-496f-b3a8-1dbddacdf97e | fr.ilipresto.app |
| iOS 1:151421230024:ios:c3a75745c492983d2b3efd | 187a10af-5395-4c40-a949-6920e8905082 | fr.ilipresto.app |

Empreintes SHA-1 enregistrées pour Android :

- 37c41a3947967a59e3efbd21e67c97d75fdcdd62
- fd4a4037722307133c15e9c6da72570120e37447
- 87f5a3f7075bc85e86b5e8df34a1ec773277685b
- 945981042660b58de9e15945835cfd870f9f0006

La commande Android suivante est préparée avec les quatre certificats
réellement enregistrés, sans contourner le contrôle de trafic. Elle n’est pas
encore attestée appliquée. Après réussite, vérifier les restrictions, les
signatures des versions distribuées et Auth/App Check sur un appareil.

```bash
gcloud services api-keys update 83512e8a-3c39-496f-b3a8-1dbddacdf97e \
  --project=presto-app-74abe --append --check-existing-usage \
  --allowed-application=package_name=fr.ilipresto.app,sha1_fingerprint=37c41a3947967a59e3efbd21e67c97d75fdcdd62 \
  --allowed-application=package_name=fr.ilipresto.app,sha1_fingerprint=fd4a4037722307133c15e9c6da72570120e37447 \
  --allowed-application=package_name=fr.ilipresto.app,sha1_fingerprint=87f5a3f7075bc85e86b5e8df34a1ec773277685b \
  --allowed-application=package_name=fr.ilipresto.app,sha1_fingerprint=945981042660b58de9e15945835cfd870f9f0006
```

Prochaine investigation iOS : identifier les appelants du trafic incompatible
via les métriques API par identifiant de credential et réconcilier les usages
serveur. Le code source relie Places à `GOOGLE_PLACES_API_KEY` et VEO à
`VEO_API_KEY` (ou à la saisie administrateur), sans réutilisation directe de la
constante iOS dans ces modules. Cela ne prouve pas les valeurs ou configurations
réellement déployées. Conserver le contrôle global en `pending`.


## Refus Android et diagnostic de trafic préparé

L’opérateur signale ensuite le même `FAILED_PRECONDITION` sur la tentative
Android, avec les quatre mêmes services. Son collage contient des fragments
parasites ; le diagnostic reçu ne permet pas d’inférer l’origine des appels,
ni de certifier une nouvelle configuration Android. Aucune réussite d’ajout
des restrictions clientes n’est attestée.

`tools/security/collect_api_usage.py` lit uniquement les en-têtes des séries
Cloud Monitoring `serviceruntime.googleapis.com/api/request_count` sur les
sept derniers jours pour ces quatre services. Il conserve l’UUID de credential
quand disponible et les codes/classes HTTP ; les identifiants non UUID sont
hachés pour corrélation. Il ne lit pas les valeurs de clés ou secrets,
n’exporte pas le jeton OAuth, ne récupère pas le contenu des requêtes et ne
modifie ni GCP ni le registre de sécurité. La pagination est suivie.

```bash
git pull --ff-only origin fix/ilipresto-audit-integration-20260930
python3 tools/security/collect_api_usage.py
```

La sortie permet de rapprocher les UUID Android/iOS des services et codes
observés, si ces dimensions sont disponibles. Ce diagnostic n’identifie pas
nécessairement les appelants, ne fournit pas les volumes et une sortie vide
ne prouve pas l’absence de trafic. Un refus IAM/Monitoring reste une collecte
échouée, pas une preuve de conformité. Ne pas désactiver le contrôle de trafic
ou élargir les scopes pour contourner l’erreur avant réconciliation des usages.

Validation locale : huit tests des deux collecteurs réussis, couvrant projection
sans valeurs sensibles, conservation des codes 200/403 et UUID, pagination et
sanitisation des erreurs. La collecte de trafic réelle reste à exécuter par
l’opérateur authentifié Cloud Shell.

Références :
- https://docs.cloud.google.com/monitoring/api/resources#tag_consumed_api
- https://docs.cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.timeSeries/list


## Trafic réel fourni : appels refusés, décision de reprise ciblée

Diagnostic Cloud Monitoring transmis par l’opérateur : fenêtre du
`2026-09-23T13:31:54.011597+00:00` au `2026-09-30T13:31:54.011597+00:00`.
Pour les UUID iOS et Android, les quatre services signalés par le contrôle
(`generativelanguage`, `places-backend`, `speech`, `static-maps-backend`)
n’apparaissent qu’en HTTP 403 dans les en-têtes reçus. Aucune série 2xx pour
ces UUID et services n’est présente dans cette collecte. La clé Web principale
présente également 403 sur ces quatre services. La seconde clé Browser apparaît
403 pour Gemini et Places, sans série Speech/Static Maps dans le relevé.
Une série Speech 200 utilise un autre credential, anonymisé par le collecteur.

Cela explique que le contrôle de trafic refuse la mise à jour même pour des
services dont les requêtes sont déjà refusées. La collecte ne donne ni les
volumes, ni l’origine des requêtes, ni la garantie d’exhaustivité de toute
l’activité. Elle ne démontre pas une compromission ou une réussite de ces appels.

Décision : les commandes iOS et Android préparées plus haut peuvent être
reprises avec `--no-check-existing-usage` à la place de
`--check-existing-usage`, en conservant `--append` et les API autorisées.
Le contournement est maintenant motivé par les codes 403 observés ; il ne doit
pas ajouter les quatre services interdits à la liste des API. Ne pas appliquer
cette décision aux clés serveur ou aux clés Browser non encore réconciliées.

L’opérateur doit ensuite relancer la collecte des restrictions et essayer
Auth/App Check sur iOS et Android. Aucune exécution réussie de la reprise n’est
encore attestée. Le contrôle global reste `pending`, ainsi que l’inventaire des
secrets jusqu’à confirmation des responsables et rotations/non-applicabilité.


## Restrictions natives appliquées et relues le 30/09/2026

La sortie Cloud Shell fournie par l’opérateur confirme maintenant la réussite
des deux mises à jour et leur relecture, avec comparaison des listes d’API
avant/après : `API autorisées inchangées.` pour les deux clés.

| Plateforme | UUID | Configuration relue | updateTime GCP |
|---|---|---|---|
| iOS | 187a10af-5395-4c40-a949-6920e8905082 | allowedBundleIds = [fr.ilipresto.app] | 2026-09-30T13:35:28.743097Z |
| Android | 83512e8a-3c39-496f-b3a8-1dbddacdf97e | Quatre allowedApplications, package fr.ilipresto.app et empreintes enregistrées listées plus haut | 2026-09-30T13:35:35.409074Z |

Cette preuve porte sur les réglages GCP appliqués, pas sur la validation d’un
binaire distribué. Auth/App Check sur appareils, correspondance avec la
signature Play si distribuée par Play et autres fonctions Firebase restent
à valider. Aucun résultat fonctionnel réel n’est inventé.

Pour le Web principal, `.firebaserc` et `web/index.html` identifient les domaines
`ilipresto.fr`, `www.ilipresto.fr`, `ilipresto.web.app`,
`ilipresto.firebaseapp.com`, `presto-app-74abe.web.app` et
`presto-app-74abe.firebaseapp.com`. Ces six origines HTTPS sont proposées pour
la restriction de production, sans origine universelle. Les preview channels
et usages de développement doivent être réconciliés séparément.

Aucun build Windows/Linux n’a été trouvé dans les workflows inspectés, mais
`lib/firebase_options.dart` partage la clé Web avec ces plateformes : cela ne
prouve pas l’absence d’utilisateurs de ces clients. Clarifier leur usage avant
restriction de referrer. La deuxième clé Browser nécessite également
l’identification de ses consommateurs avant restriction ou désactivation.

**Statut global : pending.** Les restrictions natives sont désormais attestées
par la sortie opérateur ; Web, usages serveur et essais fonctionnels restent
à compléter. L’inventaire des responsables/rotations des secrets reste distinct.


## Périmètre utilisateur confirmé : Web iPad et Web Android

L’utilisateur précise le 30/09/2026 : « ipad web et android web ». Le périmètre
actuel à valider est donc Safari/iPad et navigateur/Android. La restriction
Web principale peut être préparée pour la clé Firebase associée
`e489e9b6-ea2a-4634-9f48-1fd96ad6a19b`, avec les six domaines de production
identifiés plus haut. Pour chaque domaine HTTPS, inclure le domaine nu et le
motif de chemin `/*`, conformément à la documentation Google. Ne pas autoriser
un sous-domaine universel ni tous les sites Firebase.

La reprise utilise `--append --no-check-existing-usage` : les quatre services
incompatibles observés pour cette clé n’apparaissaient qu’en HTTP 403 dans le
relevé reçu. Relire les restrictions après modification et comparer les
`apiTargets` avant/après. Cette modification Web n’est pas encore attestée
appliquée. Tester ensuite Auth et publication sur les deux navigateurs.

La seconde clé Browser `22d51620-5b04-490f-911e-9042a93a64a2` n’est pas la clé
associée à l’application Web principale. Son identification reste nécessaire,
sans suppression automatique ni présomption qu’elle est inutilisée.

Référence : https://docs.cloud.google.com/api-keys/docs/add-restrictions-api-keys


## Web principal : modification appliquée et relue

La sortie opérateur du 30/09/2026 confirme la réussite de la mise à jour de
`e489e9b6-ea2a-4634-9f48-1fd96ad6a19b`, avec
`updateTime = 2026-09-30T13:47:10.064650Z`. Les douze referrers HTTPS attendus
(six domaines, domaine nu et chemin `/*`) figurent dans la relecture.
La comparaison avant/après confirme `API autorisées inchangées.`

Les réglages GCP des trois clés principales Web/Android/iOS sont maintenant
attestés par les sorties opérateur. Les essais fonctionnels sur Safari/iPad,
navigateur/Android et les binaires natifs ne sont pas encore attestés.
Le contrôle global reste `pending` : ancienne clé Browser et trois clés
serveur restent à réconcilier, notamment les restrictions applicatives serveur
compatibles avec l’architecture d’exécution. Ne pas leur appliquer de referrers
Web ou d’IP Cloud Shell. L’identification des apps Web associées à l’ancienne
clé peut être collectée sans télécharger les valeurs des clés.


## Application Web active unique et traitement de la clé Browser historique

Le relevé Firebase Management transmis le 30/09/2026 liste une seule application
Web active : `ilipresto`, App ID `1:151421230024:web:1f974719da2f98822b3efd`,
clé associée `e489e9b6-ea2a-4634-9f48-1fd96ad6a19b`. L’ancienne clé
`22d51620-5b04-490f-911e-9042a93a64a2` n’est associée à aucune application
Web active dans ce relevé. Cela ne prouve pas son absence dans un ancien
binaire, une ancienne configuration ou un autre consommateur.

Décision préparée : conserver cette clé et lui appliquer les mêmes referrers
que la clé Web principale, sans changer les API autorisées. Le trafic relevé
pour cette clé vers Gemini et Places était HTTP 403. Le contournement du
contrôle de trafic reste ciblé, sans autoriser ces services. Les consommateurs
historiques servis sur les mêmes domaines restent dans le périmètre autorisé ;
les usages hors de ces domaines ne sont pas attestés. Relecture et comparaison
des apiTargets requises. L’application effective de cette décision n’est pas
encore confirmée. Ne pas supprimer la clé sur la seule base de ce relevé.
