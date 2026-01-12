# 🚀 Instructions de Déploiement

## Déploiement Complet avec Messagerie Firebase

### Option 1: Script Automatique (Recommandé)

```bash
chmod +x deploy_messaging.sh
./deploy_messaging.sh
```

Ce script effectuera automatiquement :
1. ✅ Analyse du code Flutter
2. ✅ Nettoyage des builds
3. ✅ Installation des dépendances
4. ✅ Build Flutter Web en mode release
5. ✅ Déploiement sur Firebase Hosting

### Option 2: Commandes Manuelles

```bash
# 1. Vérifier les erreurs
flutter analyze

# 2. Nettoyer les builds précédents
flutter clean

# 3. Installer les dépendances
flutter pub get

# 4. Build en mode release
flutter build web --release

# 5. Déployer sur Firebase
firebase deploy --only hosting
```

## Après le Déploiement

### 🔒 Configurer les Règles Firestore

Les règles de sécurité Firestore doivent être mises à jour pour la messagerie :

```bash
firebase deploy --only firestore:rules
```

Vérifiez que [firestore.rules](firestore.rules) contient les règles appropriées pour :
- ✅ Conversations (lecture/écriture limitée aux participants)
- ✅ Messages (création limitée aux participants)
- ✅ Signalements

### 🧪 Tester les Fonctionnalités

1. **Ouvrir l'application** : https://presto-app-74abe.web.app/

2. **Vider le cache** :
   - Chrome/Edge : `Ctrl + Shift + R`
   - Firefox : `Ctrl + F5`
   - Safari : `Cmd + Shift + R`

3. **Tester la messagerie** :
   - ✅ Se connecter avec un compte
   - ✅ Cliquer sur "Envoyer un message" depuis une offre
   - ✅ Envoyer un message
   - ✅ Vérifier la réception en temps réel
   - ✅ Consulter la boîte de réception depuis le profil
   - ✅ Vérifier le badge de notifications

### 🐛 Dépannage

#### Le déploiement échoue

```bash
# Vérifier la connexion Firebase
firebase login

# Vérifier le projet actif
firebase projects:list
firebase use presto-app-74abe
```

#### Les nouveaux fichiers ne sont pas déployés

```bash
# Nettoyer complètement
flutter clean
rm -rf build/
flutter pub get
flutter build web --release
firebase deploy --only hosting
```

#### Les changements ne sont pas visibles

1. **Vider le cache du navigateur** (important !)
2. **Désactiver le Service Worker** :
   - F12 → Application → Service Workers → Unregister
   - F12 → Application → Storage → Clear site data
3. **Forcer le rechargement** : `Ctrl + Shift + R`

#### Erreurs Firestore

```bash
# Vérifier les règles Firestore
firebase firestore:rules get

# Redéployer les règles
firebase deploy --only firestore:rules
```

## URLs de l'Application

- 🌐 **Production** : https://presto-app-74abe.web.app/
- 🌐 **Alternatif** : https://presto-app-74abe.firebaseapp.com/

## Monitoring

### Firebase Console

- **Hosting** : https://console.firebase.google.com/project/presto-app-74abe/hosting
- **Firestore** : https://console.firebase.google.com/project/presto-app-74abe/firestore
- **Authentication** : https://console.firebase.google.com/project/presto-app-74abe/authentication

### Logs en Temps Réel

```bash
# Logs Firestore
firebase firestore:logs

# Logs Functions (si utilisées)
firebase functions:log
```

## Rollback (en cas de problème)

Pour revenir à une version précédente :

```bash
# Lister les versions déployées
firebase hosting:clone presto-app-74abe:SOURCE_VERSION DESTINATION_VERSION

# Ou redéployer depuis un commit git précédent
git checkout <commit-hash>
./deploy_messaging.sh
```

## Checklist Post-Déploiement

- [ ] Application accessible à l'URL de production
- [ ] Connexion utilisateur fonctionnelle
- [ ] Messagerie : envoi de messages OK
- [ ] Messagerie : réception en temps réel OK
- [ ] Badge de notifications OK
- [ ] Aucune erreur dans la console navigateur
- [ ] Aucune erreur dans Firebase Console
- [ ] Firestore Rules déployées et actives

---

**🎉 Votre application avec messagerie Firebase est maintenant en production !**
