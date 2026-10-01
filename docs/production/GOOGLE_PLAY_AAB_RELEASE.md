# Google Play — AAB signé et certification de release

Ce document définit la voie de publication Android Store pour **iliprestō** (`fr.ilipresto.app`).

## 1. Architecture de signature retenue

- Le code source et les workflows restent sur GitHub.
- Le **keystore d'upload**, son alias et ses mots de passe ne sont ni commités ni stockés comme secrets de signature GitHub.
- Le matériel de signature est conservé dans **Google Secret Manager** du projet `presto-app-74abe`.
- GitHub Actions s'authentifie à Google Cloud par **Workload Identity Federation** puis lit uniquement les secrets nécessaires au build.
- Le bundle envoyé à Google Play est signé par la **clé d'upload**.
- Après activation de **Play App Signing**, Google conserve la **clé de signature d'application** utilisée pour signer les APK réellement distribués aux utilisateurs.

Les quatre secrets attendus par le workflow sont :

- `android-upload-keystore-b64`
- `android-upload-keystore-password`
- `android-upload-key-password`
- `android-upload-key-alias`

## 2. Sauvegarde obligatoire de la clé d'upload

Conserver au minimum deux copies chiffrées et indépendantes du keystore d'upload :

1. un coffre-fort de mots de passe / stockage chiffré principal ;
2. une sauvegarde hors ligne ou hors du poste de développement.

Ne jamais régénérer une nouvelle clé parce qu'un poste local a perdu le fichier. Après enregistrement auprès de Google Play, restaurer la clé existante ou utiliser la procédure officielle de réinitialisation de la clé d'upload.

Le script `android/generate_keystore.sh` exige désormais l'argument explicite `--create-new-upload-key` afin d'empêcher une création accidentelle.

## 3. Provisionner Google Secret Manager

À exécuter depuis un poste de confiance ou Cloud Shell, avec le vrai keystore d'upload existant.

```bash
PROJECT_ID="presto-app-74abe"
KEYSTORE="/chemin/securise/upload-keystore.jks"

for SECRET in \
  android-upload-keystore-b64 \
  android-upload-keystore-password \
  android-upload-key-password \
  android-upload-key-alias
do
  gcloud secrets describe "$SECRET" --project="$PROJECT_ID" >/dev/null 2>&1 || \
    gcloud secrets create "$SECRET" \
      --project="$PROJECT_ID" \
      --replication-policy="automatic"
done

base64 < "$KEYSTORE" | tr -d '\r\n' | \
  gcloud secrets versions add android-upload-keystore-b64 \
    --project="$PROJECT_ID" --data-file=-

read -rsp "Keystore password: " STORE_PASS; echo
printf '%s' "$STORE_PASS" | \
  gcloud secrets versions add android-upload-keystore-password \
    --project="$PROJECT_ID" --data-file=-

read -rsp "Key password: " KEY_PASS; echo
printf '%s' "$KEY_PASS" | \
  gcloud secrets versions add android-upload-key-password \
    --project="$PROJECT_ID" --data-file=-

read -rp "Key alias [upload]: " KEY_ALIAS
KEY_ALIAS="${KEY_ALIAS:-upload}"
printf '%s' "$KEY_ALIAS" | \
  gcloud secrets versions add android-upload-key-alias \
    --project="$PROJECT_ID" --data-file=-

unset STORE_PASS KEY_PASS KEY_ALIAS
```

Le compte de service utilisé par le WIF GitHub doit disposer de `roles/secretmanager.secretAccessor` **uniquement sur ces quatre secrets** si possible, plutôt qu'au niveau de tout le projet.

## 4. Empreintes de la clé d'upload

Pour relever les empreintes directement depuis le keystore :

```bash
keytool -list -v \
  -keystore /chemin/securise/upload-keystore.jks \
  -alias upload
```

Conserver les valeurs SHA-1 et SHA-256 dans le dossier de certification de release.

Le workflow compare automatiquement le certificat embarqué dans le `.aab` au certificat du keystore et échoue si les SHA-256 diffèrent.

## 5. Firebase / Google Sign-In

Avant de considérer le bundle certifié :

1. ouvrir Firebase Console > projet `presto-app-74abe` > paramètres du projet ;
2. sélectionner l'application Android `fr.ilipresto.app` ;
3. ajouter les SHA-1 et SHA-256 de la **clé d'upload** ;
4. télécharger et intégrer un `google-services.json` à jour si Firebase en génère un nouveau ;
5. relancer le workflow AAB.

Le workflow vérifie que le SHA-1 de la clé d'upload est bien présent dans `android/app/google-services.json` pour `fr.ilipresto.app`. Il ne peut pas certifier depuis ce fichier seul que le SHA-256 est enregistré côté console : ce point reste à contrôler dans Firebase Console.

## 6. Construire le vrai AAB Store

Lancer manuellement le workflow GitHub :

`Build signed Android AAB (Google Play)`

Le workflow :

- utilise Flutter `3.44.6` de façon déterministe ;
- exécute `flutter analyze --fatal-infos` ;
- construit `flutter build appbundle --release` ;
- applique un `versionCode` explicite ;
- produit `dist/app-release.aab` ;
- vérifie la signature JAR du bundle ;
- compare le SHA-256 du signataire du AAB à celui du vrai upload keystore ;
- vérifie le SHA-1 Firebase de `fr.ilipresto.app` ;
- génère `release-certification.txt` ;
- exporte le certificat public `upload_certificate.pem` ;
- archive les trois fichiers dans un artifact GitHub.

Le numéro de build peut être fourni manuellement au lancement du workflow. S'il est laissé vide, le numéro du run GitHub est utilisé. Pour tout AAB chargé dans Play Console, le `versionCode` doit être strictement supérieur aux versions déjà chargées.

## 7. Premier upload — Internal testing

Dans Google Play Console :

1. ouvrir l'application iliprestō ;
2. activer/configurer **Play App Signing** si ce n'est pas déjà fait ;
3. ouvrir le canal **Internal testing** ;
4. créer une release ;
5. charger exactement le `app-release.aab` produit par le workflow ;
6. relever tous les avertissements et erreurs Play Console avant de poursuivre ;
7. ne pas promouvoir la release tant que ces avertissements n'ont pas été analysés.

Pour une nouvelle application Play, le premier AAB signé par la clé d'upload permet à Google de reconnaître cette clé comme clé d'importation lorsque Play App Signing est utilisé avec une clé de signature gérée par Google.

## 8. Empreintes Play App Signing à ajouter après le premier upload

Après activation de Play App Signing, ouvrir la page de signature de l'application dans Play Console et relever :

- SHA-1 du **certificat de signature d'application** ;
- SHA-256 du **certificat de signature d'application** ;
- SHA-1/SHA-256 du **certificat de clé d'upload** pour comparaison.

Ajouter également les SHA-1/SHA-256 du **certificat de signature d'application Play** dans Firebase pour `fr.ilipresto.app`, car les APK installés depuis Google Play sont signés par cette clé et non par la clé d'upload.

Conserver les deux familles d'empreintes :

- clé d'upload = authentifie les bundles envoyés à Google Play ;
- clé Play App Signing = signe les APK distribués aux utilisateurs.

## 9. Facebook Login

Le projet Flutter actuel utilise Firebase Authentication pour le social login et ne déclare pas de package Flutter Facebook natif dédié dans `pubspec.yaml`.

Si une plateforme Android est néanmoins configurée dans l'application Meta/Facebook, enregistrer les key hashes/certificats exigés par Meta pour :

- la clé d'upload si elle est utilisée pour des installations directes ;
- surtout la clé **Play App Signing** pour les installations provenant de Google Play.

Ce contrôle est conditionnel à la configuration réelle de l'application Meta.

## 10. Gate de promotion vers Production

Ne promouvoir vers Production que si les éléments suivants correspondent **exactement** à la release testée :

- package : `fr.ilipresto.app` ;
- `versionName` ;
- `versionCode` ;
- commit Git complet ;
- SHA-256 du fichier `app-release.aab` ;
- SHA-1/SHA-256 de la clé d'upload ;
- SHA-1/SHA-256 de la clé Play App Signing ;
- résultat des tests Internal testing ;
- avertissements Play Console traités.

Le fichier `release-certification.txt` généré par le workflow est la référence technique du bundle avant upload. Après le premier upload Internal testing, compléter la fiche de release avec les empreintes Play App Signing et les avertissements/contrôles Play Console.
