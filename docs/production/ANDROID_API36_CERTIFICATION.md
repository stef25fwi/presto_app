# Certification Android 16 / API 36 — P0 Google Play

## Objectif

Avant toute soumission Google Play à compter du 31 août 2026, iliprestō doit fournir une preuve reproductible que l'artefact Android final cible Android 16 / API 36 et que les fonctions mobiles critiques restent opérationnelles sous Android 16.

## Configuration verrouillée

- Flutter CI de référence : `3.44.6`.
- Java : `17`.
- Android Gradle Plugin : `8.11.1`.
- Gradle : `8.14`.
- `compileSdk = 36` explicite dans `android/app/build.gradle.kts`.
- `targetSdk = 36` explicite dans `android/app/build.gradle.kts`.
- Le workflow `.github/workflows/android-api36-certification.yml` doit être vert sur le SHA candidat.
- Le workflow `.github/workflows/release_android.yml` doit produire l'AAB signé et sa preuve `targetSdkVersion=36` avant tout upload Play.

## Preuves automatisées obligatoires

### PR / compatibilité Android 16

Le workflow `Android API 36 certification` doit produire et archiver, pour le même SHA :

1. `flutter --version`.
2. `flutter doctor -v`.
3. Versions Java, AGP et Gradle.
4. Installation/présence du SDK Android API 36.
5. `flutter analyze --fatal-infos` réussi.
6. `flutter test --reporter expanded` réussi.
7. Build Android sans erreur.
8. Manifest APK fusionné avec `targetSdkVersion=36`.
9. Permissions finales attendues : notifications, caméra et microphone.
10. Absence de `MANAGE_EXTERNAL_STORAGE`.
11. Démarrage de l'application sur un émulateur Android 16 / API 36.
12. Résolution des deep links `ilipresto://...` et `https://ilipresto.fr/app` sur Android 16.

### AAB réellement destiné à Google Play

Le workflow `Release Android (AAB → Play Console)` doit, **avant** l'étape d'upload Play :

1. utiliser Flutter `3.44.6` et Java 17 ;
2. enregistrer `flutter doctor -v` et le SHA Git ;
3. installer/vérifier la plateforme Android API 36 ;
4. rejouer analyse et tests Flutter ;
5. construire l'AAB release signé ;
6. lire le manifest du `.aab` final avec `bundletool` ;
7. échouer si `targetSdkVersion` n'est pas exactement `36` ;
8. archiver le manifest, la preuve `targetSdkVersion=36` et le SHA-256 de l'AAB ;
9. seulement ensuite autoriser l'envoi sur Google Play.

Les preuves sont conservées 90 jours et l'AAB de release 30 jours.

## Tests fonctionnels Android 16 obligatoires sur appareil réel

Les tests ci-dessous doivent être exécutés sur le **même SHA** que l'AAB candidat. Un émulateur ne suffit pas pour déclarer ces fonctions validées à 100 %.

| Contrôle | Procédure minimale | Résultat attendu | Preuve à archiver |
|---|---|---|---|
| Notifications | Installer la release, accepter/refuser puis réactiver la permission, envoyer une notification FCM, ouvrir la notification | Réception foreground/background, affichage correct, tap ouvre la destination attendue | vidéo/captures + identifiant du message + SHA |
| Photos / stockage | Sélectionner une photo via le sélecteur système, joindre/envoyer, recommencer après refus d'accès | Sélection et upload sans permission de stockage large, refus géré proprement | vidéo/captures + logs + SHA |
| Caméra | Ouvrir la caméra depuis le parcours prévu, autoriser/refuser, prendre une photo puis confirmer | Capture, retour dans l'app et traitement/upload corrects ; refus sans crash | vidéo + logs + SHA |
| Microphone | Démarrer un enregistrement, autoriser/refuser, arrêter, relire/envoyer | Enregistrement exploitable, durée correcte, refus géré sans crash | vidéo + fichier/logs + SHA |
| Deep links | Ouvrir un lien HTTPS vérifié et un schéma `ilipresto://` depuis une autre app | L'app s'ouvre sur la route métier attendue, sans écran intermédiaire erroné | vidéo + URL testée + SHA |
| Authentification | Tester les méthodes réellement activées : email/mot de passe, Google, téléphone/SMS et autres providers utilisés | Connexion, retour OAuth/SMS, persistance de session, déconnexion et reconnexion sans erreur | vidéo/captures + logs expurgés + SHA |

## Critère de sortie P0

Le P0 « Android API 36 » peut être déclaré **certifié** uniquement lorsque :

- le workflow `Android API 36 certification` est vert sur le SHA candidat ;
- le workflow `Release Android` a construit l'AAB signé du même SHA ;
- l'AAB final annonce `targetSdkVersion=36` ;
- les tests Android 16 sur appareil réel ci-dessus sont tous validés avec preuve ;
- aucune régression Android bloquante n'est ouverte sur ce SHA.

Une configuration de code correcte ou un simple `targetSdk = 36` n'est pas, à elle seule, une certification de soumission.
