# Amorçage Google du suivi SEO expert

## État qui déclenche cette procédure

Le suivi technique du site peut être entièrement sain alors que Search Console et GA4 restent indisponibles. Le run du 4 août 2026 a confirmé :

- authentification Workload Identity Federation réussie ;
- 12 URL indexables sur 12 saines ;
- refus `serviceusage.googleapis.com/AUTH_PERMISSION_DENIED` lors de l’activation des API ;
- Search Console et GA4 non exploitables tant que les API et les accès produit ne sont pas configurés.

L’identité utilisée par GitHub Actions est :

```text
github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com
```

## Principe de moindre privilège

Le compte GitHub ne reçoit pas le rôle permanent `roles/serviceusage.serviceUsageAdmin`. L’activation des API est une opération d’administration unique, exécutée par un administrateur du projet. Le compte GitHub reçoit seulement `roles/serviceusage.serviceUsageConsumer`, qui permet de consommer des API déjà activées.

## Étape 1 — Google Cloud Shell

Ouvrir Google Cloud Shell avec un compte administrateur du projet `presto-app-74abe`, puis exécuter depuis le dépôt :

```bash
bash tools/seo/bootstrap_google_measurement_access.sh
```

Le script :

1. vérifie le projet et le compte de service ;
2. active `searchconsole.googleapis.com` ;
3. active `analyticsadmin.googleapis.com` ;
4. active `analyticsdata.googleapis.com` ;
5. accorde au compte GitHub le rôle de consommation des services ;
6. confirme individuellement l’état de chaque API.

Le compte administrateur qui exécute le script doit posséder une autorisation permettant `serviceusage.services.enable`, par exemple le rôle `roles/serviceusage.serviceUsageAdmin`.

## Étape 2 — Search Console

Dans la propriété de domaine `sc-domain:ilipresto.fr` :

1. ouvrir **Paramètres** ;
2. ouvrir **Utilisateurs et autorisations** ;
3. cliquer sur **Ajouter un utilisateur** ;
4. saisir `github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com` ;
5. choisir **Accès complet** ;
6. enregistrer.

L’accès complet est recommandé pour garantir l’accès à tous les rapports nécessaires au suivi, sans accorder le rôle de propriétaire.

## Étape 3 — Google Analytics 4

Dans la propriété GA4 associée au measurement ID `G-NT4PEHQ3CJ` :

1. ouvrir **Administration** ;
2. dans la colonne Propriété, ouvrir **Gestion des accès à la propriété** ;
3. cliquer sur **Ajouter des utilisateurs** ;
4. saisir `github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com` ;
5. attribuer uniquement le rôle **Lecteur** ;
6. enregistrer.

Le rôle Éditeur ou Administrateur n’est pas nécessaire pour lire les rapports organiques.

## Étape 4 — Validation

Relancer manuellement le workflow GitHub Actions **SEO continuous monitoring** avec l’option d’exiger les données externes.

La validation finale attendue est :

- pages saines : `12/12` ;
- disponibilité SEO : `100 %` ;
- Search Console : `available` ;
- GA4 : `available` ;
- aucune alerte critique ;
- fermeture automatique de l’issue `#1173`.

## Sécurité

- ne pas créer de clé JSON pour le compte de service ;
- ne pas placer de jeton Google dans GitHub ;
- conserver Workload Identity Federation ;
- ne pas attribuer de rôle propriétaire Search Console ;
- ne pas attribuer de rôle GA4 supérieur à Lecteur ;
- retirer tout rôle temporaire d’administration utilisé par une personne après l’amorçage, s’il n’est plus nécessaire.
