# 🧪 Guide de Test - Premium AI (Chirp 3 EU + Gemini)

## 📋 Pré-requis

### 1. Installer les dépendances Flutter
```bash
cd /workspaces/presto_app
flutter pub get
```

### 2. Installer les dépendances Functions
```bash
cd functions
npm install
```

### 3. Créer le recognizer Speech-to-Text EU
```bash
gcloud speech recognizers create presto-default \
  --location=eu \
  --model=chirp_3 \
  --language-codes=fr-FR \
  --project=presto-app-74abe
```

### 4. Activer les APIs nécessaires
- Speech-to-Text API (eu-speech.googleapis.com)
- Vertex AI API
- Cloud Storage API
- Firebase Extensions API

### 5. Vérifier les permissions IAM
Le compte de service doit avoir :
- `roles/speech.client`
- `roles/aiplatform.user`
- `roles/storage.objectViewer`

## 🚀 Déploiement

### 1. Déployer les Cloud Functions
```bash
cd /workspaces/presto_app
firebase deploy --only functions
```

Attendez le message :
```
✔  functions: Finished running predeploy script.
✔  Deploy complete!
```

### 2. Lancer l'app Flutter
```bash
flutter run
```

Ou pour le web :
```bash
flutter run -d chrome
```

## 🧪 Test Étape par Étape

### Test 1 : Bouton IA Simple (OpenAI)
1. Ouvrir la page "Je publie une offre"
2. Dans le champ "Décris ton besoin", taper : "Besoin d'un jardinier pour taille de haie demain à Pointe-à-Pitre"
3. Cliquer sur **"Remplir automatiquement"**
4. ✅ Vérifier que :
   - Le titre est rempli
   - La description est remplie
   - La catégorie est "Jardinage"
   - La ville est "Pointe-à-Pitre"
   - ❌ Téléphone et Budget restent vides

### Test 2 : Bouton Premium (Audio Chirp 3 + Gemini)
1. Ouvrir la page "Je publie une offre"
2. Cliquer sur **"🎙️ Premium (Audio)"**
3. Parler pendant 5-10 secondes : 
   > "Bonjour, je cherche un plombier pour réparer une fuite urgente dans ma cuisine. C'est pour demain matin à Les Abymes. Budget environ 150 euros."
4. Cliquer sur **"Arrêter l'enregistrement"**
5. Attendre le traitement (10-20 secondes)
6. ✅ Vérifier que :
   - Un message "Transcription Premium réussie!" apparaît
   - Le titre est rempli (ex: "Réparation fuite urgente")
   - La description contient les détails
   - La catégorie est "Bricolage"
   - La ville est "Les Abymes"
   - ❌ Téléphone et Budget restent vides (même si mentionnés dans l'audio)

### Test 3 : Vérifier les logs Cloud Functions
```bash
firebase functions:log --only transcribeAndDraftOffer
```

Vous devriez voir :
- Les appels à l'API Speech-to-Text EU
- La transcription complète
- L'appel à Gemini
- Le JSON retourné

## 🐛 Dépannage

### Erreur : "OPENAI_API_KEY manquante"
Configurer la clé :
```bash
firebase functions:config:set openai.key="sk-..."
firebase deploy --only functions
```

### Erreur : "Recognizer not found"
Vérifier que le recognizer existe :
```bash
gcloud speech recognizers list --location=eu --project=presto-app-74abe
```

Si absent, le créer (voir Pré-requis #3)

### Erreur : "Permission denied"
Vérifier les permissions IAM :
```bash
gcloud projects get-iam-policy presto-app-74abe
```

### Erreur : "Audio upload failed"
Vérifier Firebase Storage :
1. Console Firebase → Storage
2. Règles de sécurité :
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /stt/{userId}/{allPaths=**} {
      allow write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null;
    }
  }
}
```

### L'app Flutter ne compile pas
```bash
flutter clean
flutter pub get
flutter run
```

## 📊 Métriques à surveiller

### Console Google Cloud
- **Speech-to-Text** : Durée audio transcrite (EU region)
- **Vertex AI** : Nombre de requêtes Gemini
- **Cloud Storage** : Espace utilisé par les fichiers audio

### Coûts estimés
- Speech-to-Text Chirp 3 : ~0,016€/min
- Vertex AI Gemini : ~0,0005€/requête
- Cloud Storage : ~0,026€/GB/mois
- Cloud Functions : Gratuit jusqu'à 2M invocations

## ✅ Checklist Test Complet

- [ ] Installation dépendances Flutter
- [ ] Installation dépendances Functions
- [ ] Recognizer créé en région EU
- [ ] APIs activées
- [ ] Functions déployées avec succès
- [ ] Test bouton IA simple réussi
- [ ] Test bouton Premium Audio réussi
- [ ] Téléphone/Budget jamais modifiés
- [ ] Transcription visible dans les logs
- [ ] Pas d'erreurs dans la console

## 🎯 Résultat Attendu

Après un enregistrement audio de 10 secondes décrivant un besoin, l'application doit :
1. ✅ Uploader l'audio vers Cloud Storage
2. ✅ Appeler `transcribeAndDraftOffer`
3. ✅ Transcrire avec Chirp 3 (endpoint EU)
4. ✅ Générer un brouillon avec Gemini
5. ✅ Remplir titre, description, catégorie, ville
6. ❌ NE PAS toucher téléphone/budget
7. ✅ Afficher un message de succès

Temps total : 10-20 secondes
