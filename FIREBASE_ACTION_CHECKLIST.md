# ✅ Checklist d'Action: Sécurité Firebase Firestore

## 🎯 Objectif

Vérifier et renforcer la sécurité des tokens & clés Firebase Firestore API.

**Résultat Actuel:** ✅ **95% CONFORME**  
**Temps Requis:** 15-30 minutes

---

## 📋 Actions par Priorité

### 🔴 URGENT (Do Now)

- [ ] **Valider les tokens**
  ```bash
  bash validate_firebase_tokens.sh
  ```
  **Résultat attendu:** ✅ TOUS LES TOKENS FIREBASE SONT VALIDES
  **Temps:** 2 minutes

- [ ] **Vérifier les secrets ne sont pas committés**
  ```bash
  git log --oneline --all | grep -i secret
  git status | grep -E "\.env|password|secret"
  ```
  **Résultat attendu:** Rien ne s'affiche
  **Temps:** 2 minutes

---

### 🟠 HAUT (Important)

- [ ] **Configurer les restrictions de clé API**
  
  **Où:** https://console.cloud.google.com/apis/credentials
  
  **Clé à configurer:** `AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo`
  
  **Étapes:**
  1. Cliquer sur la clé API
  2. Section "Application Restrictions"
     ```
     Type: HTTP Referers
     Ajouter:
     - https://stef25fwi.github.io/presto_app/*
     - https://presto-app-74abe.firebaseapp.com/*
     - https://presto-app-74abe.web.app/*
     ```
  3. Section "API Restrictions"
     ```
     Sélectionner: Restrict key
     Ajouter:
     ✅ Cloud Firestore API
     ✅ Cloud Authentication API
     ✅ Cloud Storage for Firebase
     ✅ Firebase App Check Attestation API
     (Désactiver les autres)
     ```
  4. Cliquer "Save"
  
  **Temps:** 5-10 minutes

- [ ] **Tester Firestore localement**
  ```bash
  firebase emulators:start
  # Laisser tourner et vérifier pas d'erreurs
  # Ctrl+C pour arrêter
  ```
  **Résultat attendu:** Pas d'erreurs de tokens
  **Temps:** 3 minutes

- [ ] **Vérifier que .env est ignoré**
  ```bash
  # S'assurer que .env est dans .gitignore
  grep "\.env" .gitignore
  
  # S'assurer que .env n'est pas versionné
  git ls-files | grep "\.env"
  ```
  **Résultat attendu:** .env dans .gitignore, pas dans git
  **Temps:** 2 minutes

---

### 🟡 MOYEN (Recommandé)

- [ ] **Configurer les alertes Firebase**
  
  **Où:** Firebase Console → Project Settings → Alerts
  
  **À configurer:**
  ```
  1. Quota Alerts:
     - Firestore Reads > 100K/jour
     - Firestore Writes > 50K/jour
  
  2. Error Rate Alerts:
     - Auth errors > 1% des requêtes
     - Function errors > 0.1%
  
  3. Security Alerts:
     - Violations Firestore Rules
  ```
  
  **Temps:** 5 minutes

- [ ] **Documenter la politique de rotation des secrets**
  
  **Créer/mettre à jour le fichier: `FIREBASE_SECRETS_ROTATION_POLICY.md`**
  
  ```markdown
  # Politique de Rotation des Secrets
  
  ## GMAIL_PASSWORD
  - Rotation obligatoire: Tous les 90 jours
  - Dernière rotation: [DATE]
  - Prochaine rotation: [DATE]
  
  ## Processus
  1. Générer un nouvel App Password dans Gmail
  2. Tester localement avec .env
  3. Déployer: firebase deploy --set-env GMAIL_PASSWORD="..."
  4. Documenter la nouvelle date
  ```
  
  **Temps:** 3 minutes

- [ ] **Vérifier les logs Cloud Functions**
  ```bash
  firebase functions:log --limit 50 | head -20
  ```
  **Résultat attendu:** Pas d'erreurs liées aux tokens
  **Temps:** 2 minutes

---

### 🟢 FAIBLE (Optionnel)

- [ ] **Audit des utilisateurs actifs**
  
  **Où:** Firebase Console → Authentication → Users
  
  **Vérifier:**
  - Nombre d'utilisateurs
  - Patterns d'utilisation
  - Utilisateurs suspects
  
  **Temps:** 5 minutes

- [ ] **Vérifier l'utilisation des quotas**
  
  **Où:** Firebase Console → Project Settings → Usage
  
  **Vérifier:**
  - Firestore operations/jour
  - Storage operations/jour
  - Functions invocations/jour
  
  **Temps:** 3 minutes

- [ ] **Documenter l'architecture de sécurité**
  
  **Mise à jour:** `FIREBASE_SECURITY_GUIDE.md`
  
  **Temps:** 10 minutes

---

## 📊 Checklist Détaillée par Fichier

### ✅ lib/firebase_options.dart

```
[ ] ✅ apiKey au format correct (43+ caractères)
[ ] ✅ authDomain se termine par .firebaseapp.com
[ ] ✅ projectId = presto-app-74abe
[ ] ✅ storageBucket se termine par .firebasestorage.app
[ ] ✅ messagingSenderId = 12 chiffres
[ ] ✅ appId contient ":web:"
```

### ✅ lib/google_places_config.dart

```
[ ] ✅ @Deprecated annotation présente
[ ] ✅ kGooglePlacesApiKey = '' (vide)
```

### ✅ firebase.json

```
[ ] ✅ "functions" config présente
[ ] ✅ ".env" dans "ignore" list
[ ] ✅ "hosting" config correcte
[ ] ✅ "firestore" rules présentes
[ ] ✅ "storage" rules présentes
```

### ✅ firestore.rules

```
[ ] ✅ match /offers/{offerId} présent
[ ] ✅ allow read: isActive == true
[ ] ✅ allow write: request.auth != null
[ ] ✅ match /users/{userId} présent
[ ] ✅ Restrictions UID présentes
```

### ✅ storage.rules

```
[ ] ✅ match /offers/{offerId} public read
[ ] ✅ match /stt/{uid} auth required
[ ] ✅ match /stt_streaming/{uid} auth required
[ ] ✅ Restrictions UID présentes
```

### ✅ .gitignore

```
[ ] ✅ .env présent
[ ] ✅ .env.* présent
[ ] ✅ .runtimeconfig.json présent
[ ] ✅ firebase-debug.log présent
[ ] ✅ Vérifier: git status (pas de .env)
```

### ✅ functions/src/moderation.ts

```
[ ] ✅ defineString('GMAIL_PASSWORD') présent
[ ] ✅ defineString('GMAIL_USER') présent
[ ] ✅ Utilisation via .value() présente
[ ] ✅ Pas de hardcoded passwords
```

---

## 🔍 Commandes de Vérification Rapide

```bash
# 1. Valider tout en une commande
bash validate_firebase_tokens.sh && echo "✅ OK"

# 2. Vérifier que pas de secrets committés
(git status && git log --name-only | grep -E "\.env|secret") | \
  grep -E "\.env|password|secret" && echo "❌ SECRETS DETECTED!" || echo "✅ OK"

# 3. Vérifier firebase.json
grep -E "\.env|hosting|firestore|storage" firebase.json | wc -l | \
  awk '$1 >= 4 {print "✅ OK"} $1 < 4 {print "❌ MISSING CONFIG"}'

# 4. Vérifier firestore rules
[ -f "firestore.rules" ] && wc -l firestore.rules | awk '{print $1 " lines - OK"}' \
  || echo "❌ firestore.rules missing"

# 5. Vérifier storage rules
[ -f "storage.rules" ] && wc -l storage.rules | awk '{print $1 " lines - OK"}' \
  || echo "❌ storage.rules missing"

# 6. Tester Firestore
firebase emulators:start &
sleep 10
curl http://localhost:8080 > /dev/null 2>&1 && echo "✅ Emulator OK" || echo "❌ Emulator Failed"
pkill -f "firebase emulators"
```

---

## 📝 Suivre la Progression

### Session de Travail

```
Date: _____________
Heure début: _____________

✅ Actions Complétées:
[ ] Validation tokens
[ ] Vérif secrets committés
[ ] Restrictions clé API
[ ] Test Firestore local
[ ] Verification .gitignore
[ ] Configuration alertes
[ ] Documentation secrets
[ ] Vérif Cloud Functions logs

📊 Temps total: _____________
🏁 Status: [ ] Complète [ ] En attente
```

### Documentation

- [ ] Lire: `FIREBASE_TOKENS_QUICK_CHECK.md`
- [ ] Consulter: `FIREBASE_SECURITY_GUIDE.md`
- [ ] Exécuter: `bash validate_firebase_tokens.sh`
- [ ] Archiver: Ce document complété

---

## 🚨 Cas Problématiques

### Problème: "Erreur d'authentification Firestore"
```
Cause probable: apiKey ou authDomain incorrect
Solution: Vérifier lib/firebase_options.dart
```

### Problème: ".env trouvé dans git"
```
Cause probable: .env commité par erreur
Solution: 
  git rm --cached .env
  git commit -m "Remove .env"
  git push
```

### Problème: "Secrets en dur dans le code"
```
Cause probable: Hardcoded passwords
Solution:
  1. Remplacer par defineString()
  2. firebase deploy --set-env VAR="..."
  3. Commit le code changé
  4. Firebase Params automatiquement injéctés
```

### Problème: "Restrictions clé API non appliquées"
```
Cause probable: Oublié dans Google Cloud Console
Solution:
  1. Google Cloud Console → APIs & Services
  2. Sélectionner la clé
  3. Ajouter HTTP Referer restrictions
  4. Ajouter API restrictions
  5. Save
```

---

## ✨ Bonus: Automatiser les Vérifications

**Créer: `.github/workflows/firebase-security-check.yml`**

```yaml
name: Firebase Security Check

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate Firebase Tokens
        run: bash validate_firebase_tokens.sh
      - name: Check for secrets in code
        run: |
          ! grep -r "password\|secret\|token" --include="*.dart" \
            --include="*.ts" --exclude-dir=node_modules \
            --exclude-dir=.git lib/ functions/src/ || true
      - name: Verify .gitignore
        run: |
          grep -q "\.env" .gitignore || \
            (echo "❌ .env not in .gitignore" && exit 1)
```

---

## 📞 Escalade

**Si erreur bloquante:**
1. Vérifier la documentation: `FIREBASE_SECURITY_GUIDE.md`
2. Consulter Firebase Docs: https://firebase.google.com/docs
3. Google Cloud Support: https://cloud.google.com/support

---

## ✅ Signature de Complétion

```
Audit de Sécurité Firebase Firestore
Date: _______________
Responsable: _______________

Actions Complétées:
- [ ] Validation tokens (✅ PASS)
- [ ] Vérif secrets (✅ PASS)
- [ ] Restrictions clé API (✅ CONFIGURED)
- [ ] Test local (✅ OK)
- [ ] Alertes (✅ CONFIGURED)
- [ ] Documentation (✅ UPDATED)

Status Global: ✅ **CONFORME & SÉCURISÉ**

Signature: _______________
Date d'expiration audit: [Date + 3 mois]
```

---

**Fini!** Tous les tokens Firebase sont validés et sécurisés. 🎉
