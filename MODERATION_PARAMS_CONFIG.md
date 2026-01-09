# Configuration des Paramètres Firebase Functions - Modération

## Migration vers le nouveau système de paramètres

Firebase a déprécié `functions.config()` en faveur du nouveau système `params`. Ce guide montre comment configurer les paramètres Gmail pour le système de modération.

## ⚠️ Important: Changement d'API Firebase

À partir de mars 2026, l'ancien système `functions.config()` sera complètement supprimé.

**Le code a été migré vers le nouveau système `params`.**

## 🔧 Configuration

### Option 1: Utiliser le script automatique (Recommandé)

1. **Créer vos identifiants Gmail:**
   - Aller sur https://myaccount.google.com/apppasswords
   - S'assurer que 2FA est activé
   - Sélectionner "Mail" et votre appareil
   - Copier le mot de passe (16 caractères)

2. **Configurer `.env.local`:**
   ```bash
   cd /workspaces/presto_app/functions
   cat > .env.local << EOF
   GMAIL_USER=your-email@gmail.com
   GMAIL_PASSWORD=your-16-character-app-password
   EOF
   ```

3. **Exécuter le script:**
   ```bash
   chmod +x ../configure_params.sh
   ../configure_params.sh
   ```

### Option 2: Configuration manuelle

1. **Configurer les variables localement pour développement:**
   ```bash
   cd /workspaces/presto_app/functions
   # Créer .env.local avec vos credentials
   echo "GMAIL_USER=your-email@gmail.com" > .env.local
   echo "GMAIL_PASSWORD=your-app-password" >> .env.local
   ```

2. **Déployer avec les paramètres:**
   ```bash
   firebase deploy \
     --only functions:sendModerationWarningEmail,createModerationMessage,logModerationStats \
     --set-env GMAIL_USER="your-email@gmail.com" \
     --set-env GMAIL_PASSWORD="your-app-password"
   ```

### Option 3: Via Firebase Console

1. Aller dans Firebase Console → Cloud Functions → Configuration
2. Ajouter les variables d'environnement
3. Redéployer les functions

## 📋 Créer les identifiants Gmail

### Étape 1: Activer 2FA (si pas déjà fait)

1. Aller sur https://myaccount.google.com/security
2. Cliquer "2-Step Verification"
3. Suivre les instructions

### Étape 2: Créer un App Password

1. Aller sur https://myaccount.google.com/apppasswords
2. Sélectionner "Mail" comme application
3. Sélectionner votre appareil (ou "Windows Computer")
4. Cliquer "Generate"
5. Copier le mot de passe (16 caractères)
6. Ne pas utiliser votre vrai mot de passe!

## ✅ Vérifier la configuration

```bash
# Vérifier les functions déployées
firebase functions:list

# Voir les logs
firebase functions:log --limit 50

# Tester une fonction
firebase functions:shell
> logModerationStats({})
```

## 🚀 Tests de bout en bout

1. **Publier une offre:**
   - L'annonce doit avoir `status: 'pending_moderation'`
   - Badge orange "Attente de validation" doit s'afficher

2. **Rejeter l'offre:**
   - Admin → Modération → Rejeter avec raison
   - Cloud Function `sendModerationWarningEmail` doit s'exécuter
   - Email doit être envoyé à l'utilisateur

3. **Vérifier les logs:**
   ```bash
   firebase functions:log | grep "Moderation warning email"
   ```

## 📚 Nouvelle architecture

### Avant (Déprecié)
```typescript
import * as functions from 'firebase-functions';
const config = functions.config();
const user = config.gmail.user;
```

### Après (Nouveau)
```typescript
import { defineString } from 'firebase-functions/params';
const gmailUser = defineString('GMAIL_USER');
const user = await gmailUser.value();
```

## 🆘 Dépannage

### Erreur: "GMAIL_USER is not set"

**Solution:** Vérifier que les paramètres sont déployés:
```bash
firebase deploy --only functions
# Vérifier dans Firebase Console → Cloud Functions → Configuration
```

### Erreur: "Email not sent"

**Checklist:**
- [ ] App Password créé (pas le mot de passe principal)
- [ ] 2FA activé sur le compte Gmail
- [ ] Variables d'environnement déployées
- [ ] Vérifier les logs: `firebase functions:log`

### Erreur: "Permission denied"

**Solution:** S'assurer que les Cloud Functions ont accès à Firestore:
- Aller dans Firebase Console → Cloud Functions
- Vérifier que le compte de service a les bonnes permissions
- Voir aussi Firestore Security Rules

## 📚 Ressources

- [Firebase Functions Params Documentation](https://firebase.google.com/docs/functions/config-env#new)
- [Migration Guide](https://firebase.google.com/docs/functions/config-env#migrate-config)
- [Gmail App Passwords](https://support.google.com/accounts/answer/185833)

## 🎯 Prochaines étapes

1. Configurer les paramètres (voir ci-dessus)
2. Déployer les Cloud Functions
3. Tester le système complet
4. Mettre en production

---

**Dernière mise à jour:** 2026-01-09
**Status:** ✅ Migré vers Firebase Functions v2 et params
