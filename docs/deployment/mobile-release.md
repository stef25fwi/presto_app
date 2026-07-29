# Publication mobile — Android (Play Store) et iOS (App Store)

Les deux chaînes sont pilotées par des workflows manuels
(`workflow_dispatch`), avec une case `upload` décochée par défaut : un
déclenchement produit d'abord un artefact vérifiable, et n'envoie sur le store
que si on le demande explicitement.

| Plateforme | Workflow | Sortie | Destination |
|---|---|---|---|
| Android | `.github/workflows/release_android.yml` | AAB signé | Play Console (piste au choix) |
| iOS | `.github/workflows/release_ios.yml` | IPA signé | TestFlight |
| Android (hors store) | `.github/workflows/build_apk.yml` | APK arm64 | Artefact seulement |

Le Play Store n'accepte plus l'APK pour une nouvelle application : `build_apk.yml`
reste utile pour installer une build sur un appareil de test, mais ne peut pas
servir à publier.

## Numérotation des versions

- Le **nom de version** (`1.0.1`) vient de `pubspec.yaml`.
- Le **build number** vient de `github.run_number`, qui est strictement
  croissant. Le suffixe figé de `pubspec.yaml` (`+2`) ne convient pas : les deux
  stores refusent un build number déjà utilisé.
- `APP_BUILD_NUMBER_OVERRIDE` propage ce même numéro dans l'application, pour
  que la version affichée et celle remontée par Crashlytics correspondent au
  build réellement publié.

Bumper la version publique reste manuel : modifier `version:` dans
`pubspec.yaml` avant de déclencher la release.

## Secrets GitHub à configurer

Tous dans l'environnement **`recaptcha`** (celui déjà utilisé par les workflows
existants).

### Android

| Secret | Contenu | État |
|---|---|---|
| `KEYSTORE_B64` | Keystore d'upload encodé base64 | déjà configuré |
| `KEYSTORE_PASSWORD` | Mot de passe du keystore | déjà configuré |
| `KEY_PASSWORD` | Mot de passe de la clé | déjà configuré |
| `KEY_ALIAS` | Alias de la clé | déjà configuré |
| `PLAY_SERVICE_ACCOUNT_JSON` | JSON du compte de service Play | **à créer** |

Obtenir `PLAY_SERVICE_ACCOUNT_JSON` :

1. Google Cloud Console → créer un compte de service dédié (sans rôle IAM GCP).
2. Générer une clé JSON pour ce compte.
3. Play Console → *Configuration* → *Accès à l'API* → associer le compte de
   service et lui accorder au minimum *Gérer les versions* sur l'application.
4. Coller le contenu JSON complet dans le secret.

L'API Play Developer n'accepte pas la fédération d'identité GitHub (WIF) : ce
compte de service utilise donc une vraie clé JSON, contrairement aux accès GCP du
reste du dépôt. La restreindre à cette seule application et la faire tourner
périodiquement.

### iOS

| Secret | Contenu |
|---|---|
| `IOS_DIST_CERT_P12_B64` | Certificat *Apple Distribution* (.p12) en base64 |
| `IOS_DIST_CERT_PASSWORD` | Mot de passe du .p12 |
| `IOS_PROVISIONING_PROFILE_B64` | Profil *App Store* (.mobileprovision) en base64 |
| `IOS_TEAM_ID` | Identifiant d'équipe Apple (10 caractères) |
| `APPSTORE_API_KEY_ID` | Identifiant de la clé App Store Connect |
| `APPSTORE_API_ISSUER_ID` | Issuer ID App Store Connect |
| `APPSTORE_API_PRIVATE_KEY` | Contenu du fichier `.p8` (avec les lignes `BEGIN/END`) |

Obtenir le certificat et le profil :

1. Apple Developer → *Certificates* → créer un certificat **Apple Distribution**.
2. L'installer dans le trousseau macOS, puis l'exporter en `.p12` avec un mot de
   passe.
3. Apple Developer → *Profiles* → créer un profil **App Store** pour
   `fr.ilipresto.app`, le télécharger.
4. Encoder les deux fichiers :
   ```bash
   base64 -i dist-cert.p12 | pbcopy
   base64 -i profile.mobileprovision | pbcopy
   ```

Obtenir la clé API :

1. App Store Connect → *Utilisateurs et accès* → *Intégrations* → *Clés API*.
2. Créer une clé avec le rôle **App Manager**.
3. Le `.p8` n'est téléchargeable **qu'une seule fois** — le conserver dans un
   gestionnaire de secrets.

Le workflow crée un trousseau éphémère, y importe le certificat, et le détruit
en fin de job (étape `Cleanup`, exécutée même en cas d'échec).

## Signature iOS : pourquoi manuelle

Le projet Xcode est en `CODE_SIGN_STYLE = Automatic`, ce qui convient en local
mais suppose une session Apple ID interactive qu'un runner CI n'a pas. Le
workflow force donc `CODE_SIGN_STYLE=Manual` avec l'identité et le profil
importés depuis les secrets, **sans modifier le projet Xcode** — le
développement local continue de fonctionner en signature automatique.

## Première publication

Ordre imposé par les plateformes :

**Android** — le tout premier bundle doit être envoyé **manuellement** via
l'interface Play Console. L'API refuse les envois tant qu'aucune version n'existe
pour le package. Procédure : lancer le workflow avec `upload` décoché, récupérer
l'artefact `.aab`, le déposer à la main sur une piste interne. Les envois
suivants peuvent passer par le workflow.

**iOS** — créer d'abord la fiche application dans App Store Connect avec le
bundle ID `fr.ilipresto.app`. TestFlight accepte ensuite les envois par API dès
le premier build.

## Déclencher une release

1. Vérifier que `main` est vert et que la checklist de release est passée
   (`docs/deployment/release-checklist.md`).
2. Bumper `version:` dans `pubspec.yaml` si le nom de version change.
3. GitHub → *Actions* → workflow voulu → *Run workflow*.
4. Premier passage : laisser `upload` décoché, contrôler l'artefact.
5. Second passage : cocher `upload`.
   - Android : choisir la piste (`internal` par défaut) et laisser `status` à
     `draft` pour garder la main sur la diffusion.
   - iOS : le build arrive dans TestFlight, la soumission App Store reste une
     action manuelle depuis App Store Connect.

## Limites connues

- Aucun de ces deux workflows n'a encore été exécuté avec de vrais identifiants :
  ils sont écrits d'après les conventions des plateformes mais **le premier
  déclenchement doit être surveillé**.
- Il n'y a pas de projet Firebase de staging distinct : les builds mobiles
  pointent sur le projet de production (`presto-app-74abe`). Une build TestFlight
  ou une piste interne Play écrit donc dans les données réelles.
- Les captures d'écran, textes de fiche et classification de contenu des stores
  ne sont pas automatisés.
