# Migration vers Workload Identity Federation (WIF)

Les workflows GitHub Actions (`deploy.yml`, `build_apk.yml`,
`microia-timings.yml`) s'authentifiaient auprès de GCP via une **clé JSON de
compte de service** encodée en base64 dans le secret `GOOGLE_CREDENTIALS_B64`,
décodée puis exportée dans l'environnement du runner. Cette clé longue durée
était sensible et avait fuité en clair dans les logs.

WIF supprime toute clé longue durée : le runner présente son **jeton OIDC
GitHub** (court, signé par GitHub), GCP le vérifie et renvoie un jeton d'accès
temporaire. Aucun secret cryptographique n'est stocké dans le dépôt.

## Ce qui a changé dans les workflows

- ajout de la permission `id-token: write` (nécessaire pour émettre le jeton
  OIDC) ;
- suppression de l'étape « Decode Google Credentials » ;
- l'étape `google-github-actions/auth@v3` utilise désormais
  `workload_identity_provider` + `service_account` au lieu de
  `credentials_json`.

L'action `auth` continue d'exporter `GOOGLE_APPLICATION_CREDENTIALS`, donc
`firebase` et `gcloud` en aval fonctionnent sans changement.

## Mise en service (à faire une fois, côté GCP + GitHub)

1. **Provisionner WIF** avec un compte admin GCP :

   ```bash
   bash tools/security/setup_workload_identity_federation.sh
   ```

   Le script crée le pool, le provider OIDC GitHub (restreint au dépôt
   `stef25fwi/presto_app` via condition d'attribut), accorde
   `roles/iam.workloadIdentityUser` au compte de service, puis imprime les
   deux valeurs à reporter.

2. **Ajouter deux secrets** dans l'environnement GitHub `recaptcha`
   (Settings → Environments → recaptcha → Secrets) :
   - `WIF_PROVIDER` — chemin complet du provider ;
   - `WIF_SERVICE_ACCOUNT` — `github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com`.

3. **Fusionner** les workflows migrés puis lancer un déploiement manuel pour
   vérifier que l'authentification passe (l'étape « Authenticate to Google
   Cloud » doit réussir sans clé).

4. **Nettoyer** une fois le déploiement vert :
   - supprimer le secret `GOOGLE_CREDENTIALS_B64` de l'environnement
     `recaptcha` ;
   - supprimer/révoquer la clé JSON du compte de service dans la console GCP
     (IAM → Comptes de service → clés). La clé exposée doit de toute façon
     être révoquée en priorité.

## Sécurité du provider

La condition `assertion.repository=='stef25fwi/presto_app'` garantit que seuls
les workflows de ce dépôt peuvent obtenir un jeton pour ce compte de service.
Sans cette condition, tout dépôt GitHub pourrait usurper l'identité. Pour
restreindre davantage (par branche ou environnement), ajouter une condition
sur `assertion.ref` ou `assertion.environment`.
