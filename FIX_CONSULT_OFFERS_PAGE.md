# 🔧 Correction: Liste des Annonces "Je consulte"

## Problème Identifié

La page "Je consulte les offres" ne chargeait pas les annonces car les règles Firestore ne reconnaissaient pas le champ `isActive` utilisé par le code.

## Solution Appliquée

### 1. Modification des Règles Firestore

**Fichier:** `firestore.rules`

La fonction `isPublicOffer()` a été mise à jour pour supporter le champ `isActive`:

```javascript
function isPublicOffer() {
  // Public si explicitement public OU si "status" legacy = active
  // ✅ Supporte aussi isActive pour compatibilité
  return (resource.data.visibility.isPublic == true)
    || (resource.data.status == 'active')
    || (resource.data.isActive == true);
}
```

**Avant:**
```javascript
function isPublicOffer() {
  return (resource.data.visibility.isPublic == true)
    || (resource.data.status == 'active');
}
```

**Après:**
```javascript
function isPublicOffer() {
  return (resource.data.visibility.isPublic == true)
    || (resource.data.status == 'active')
    || (resource.data.isActive == true);
}
```

## Déploiement

### Commande à Exécuter

```bash
cd /workspaces/presto_app
firebase deploy --only firestore:rules
```

### Résultat Attendu

```
✔  cloud.firestore: rules file firestore.rules compiled successfully
✔  firestore: released rules firestore.rules to cloud.firestore
✔  Deploy complete!
```

## Vérification

### 1. Après le Déploiement

1. Ouvrir l'application
2. Aller sur "Je consulte les offres"
3. Les annonces devraient maintenant se charger

### 2. Test de la Requête

Le code utilise cette requête:
```dart
Query<Map<String, dynamic>> query = 
    FirebaseFirestore.instance.collection('offers');

query = query.where('isActive', isEqualTo: true);
```

Cette requête fonctionnera maintenant grâce à la règle mise à jour.

## Explications Techniques

### Pourquoi ça ne fonctionnait pas ?

Les règles Firestore contrôlent l'accès aux données. La fonction `isPublicOffer()` était appelée pour vérifier si une offre peut être lue publiquement :

```javascript
match /offers/{offerId} {
  allow read: if isPublicOffer() || isAdmin() || isOwnerByField(resource.data);
  ...
}
```

Avant la correction, `isPublicOffer()` ne vérifiait que:
- `visibility.isPublic == true`
- `status == 'active'`

Mais le code Flutter filtrait sur `isActive`, qui n'était pas reconnu !

### Solution

Ajout de `|| (resource.data.isActive == true)` dans la fonction pour supporter les trois formats:
1. `visibility.isPublic` (nouveau format)
2. `status == 'active'` (ancien format legacy)
3. `isActive == true` (format actuel utilisé par le code)

## Structure des Offres

Les offres dans Firestore peuvent avoir ces champs de visibilité:

```json
{
  "title": "Mon offre",
  "isActive": true,          // ← Utilisé par le code actuel
  "status": "active",         // ← Format legacy
  "visibility": {
    "isPublic": true          // ← Nouveau format
  }
}
```

Les règles supportent maintenant les 3 formats pour une compatibilité maximale.

## Fichiers Modifiés

- ✅ `/workspaces/presto_app/firestore.rules`

## État Actuel

- ✅ Règles modifiées
- ⏳ Déploiement en attente
- ⏳ Test en attente

## Actions à Faire

1. **Déployer les règles:**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Tester l'application:**
   - Ouvrir "Je consulte les offres"
   - Vérifier que les annonces se chargent

3. **Si ça ne fonctionne toujours pas:**
   - Vérifier la console Firebase pour les erreurs
   - Vérifier que les offres ont bien `isActive: true`
   - Vérifier les logs de l'application

## Diagnostic Supplémentaire

Si les annonces ne se chargent toujours pas après le déploiement:

### 1. Vérifier les Offres dans Firestore

Console Firebase > Firestore Database > Collection `offers`

Vérifier qu'il existe des documents avec:
```json
{
  "isActive": true,
  "title": "...",
  "location": "...",
  "category": "..."
}
```

### 2. Vérifier les Logs

Dans la console de l'application (DevTools), chercher:
```
[OFFERS][QUERY] ...
```

### 3. Vérifier les Index

Si une erreur mentionne des index manquants:
```
failed-precondition: index required
```

Suivre le lien fourni dans l'erreur pour créer l'index automatiquement.

## Support

- **Fichier règles:** `/workspaces/presto_app/firestore.rules`
- **Code de la page:** `/workspaces/presto_app/lib/main.dart` (ligne 3037)
- **Fonction de requête:** `_buildOffersQuery()` (ligne ~3650)

---

**Date:** 12 Janvier 2026  
**Statut:** ✅ Correction appliquée, en attente de déploiement
