# Prochaines Étapes - Système de Modération

## ✅ Implémentation Complétée

### Phase 1: Fondations (Complété)
- ✅ Widget ModerationBadge créé
- ✅ Widget UserModerationStatus créé
- ✅ Page ModerationPage (admin) créée
- ✅ Cloud Functions créées (email + notifications)
- ✅ Intégration dans OfferCard
- ✅ Intégration dans ProfilePage
- ✅ Modification du flow de publication

### Phase 2: Configuration

#### À faire immédiatement:
1. **Déployer les Cloud Functions**
   ```bash
   cd /workspaces/presto_app/functions
   firebase deploy --only functions:sendModerationWarningEmail,createModerationMessage,logModerationStats
   ```

2. **Configurer les variables d'environnement**
   ```bash
   # Créer un App Password Gmail avec 2FA activé
   firebase functions:config:set gmail.user="your-email@gmail.com" gmail.password="your-app-password"
   
   # Ou via Firebase Console:
   # Functions → Configuration
   ```

3. **Créer la collection admins**
   - Firestore → Collection `admins`
   - Document `admins`
   - Field `admins` (array): [uid1, uid2, ...]

4. **Mettre à jour Firestore Security Rules**
   ```
   match /notifications/{docId} {
     allow read: if request.auth != null && 
                 resource.data.userId == request.auth.uid;
     allow write: if request.auth != null &&
                  request.auth.uid in get(/databases/$(database)/documents/admins/admins).data.admins;
   }
   ```

#### Test du déploiement:
1. Publier une annonce de test
2. Vérifier que le status est `pending_moderation`
3. Accéder à ModerationPage (Admin)
4. Rejeter l'annonce avec raison
5. Vérifier réception d'email
6. Vérifier création de notification Firestore

## 🔮 Améliorations Futures

### Court terme (1-2 semaines)

1. **Auto-modération basée sur contenu**
   - Détection de mots interdits
   - Scoring automatique
   - Flag pour révision manuelle
   
2. **Historique de modération**
   - Audit log des actions
   - Qui a approuvé/rejeté, quand
   - Raisons enregistrées

3. **Filtres avancés**
   - Par catégorie, ville, date
   - Par statut de modérateur

### Moyen terme (1 mois)

4. **Système d'appel**
   - Utilisateur peut contester un rejet
   - Réévaluation par modérateur
   - Email de notification

5. **Modération par catégorie**
   - Règles spécifiques par type d'offre
   - Validations différentes

6. **Notifications avancées**
   - Push notifications pour admins
   - Webhook vers Slack/Discord
   - Dashboard en temps réel

### Long terme (2+ mois)

7. **Modération AI/ML**
   - Classification automatique
   - Detection de spam/scam
   - Score de confiance

8. **Statistiques et rapports**
   - Taux d'approbation par catégorie
   - Temps de modération moyen
   - Tendances de violations

9. **Bulk operations**
   - Approuver/rejeter plusieurs à la fois
   - Actions par catégorie
   - Appliquer règles génériques

## 📋 Checklist de Validation

### Tests unitaires à créer:
- [ ] Test: Badge affiche "Attente de validation" pour status pending_moderation
- [ ] Test: Badge affiche "Rejetée" pour moderation.status REJECTED
- [ ] Test: UserModerationStatus affiche pour user avec violations
- [ ] Test: ModerationPage charge les annonces en attente
- [ ] Test: Approbation met visibility.isPublic = true
- [ ] Test: Rejet crée notification et envoie email
- [ ] Test: Cloud Function logModerationStats retourne stats correctes

### Tests d'intégration:
- [ ] Publier → voir badge orange
- [ ] Rejeter → voir badge rouge + notification
- [ ] Approuver → annonce visible publiquement
- [ ] Profil → voir avertissements si violations
- [ ] Email → recevoir mail avec raison

### Tests de sécurité:
- [ ] Non-admin ne peut pas accéder ModerationPage
- [ ] Non-admin ne peut pas modifier moderation.status
- [ ] Utilisateur ne voit que ses propres notifications
- [ ] Impossible de modifier le contenu d'une notification

## 🔧 Fichiers à Monitorer

**Évolution future:**
- `/lib/pages/admin/moderation_page.dart` - Peut être étendu pour filtres/recherche
- `/lib/widgets/moderation_badge.dart` - Stable, peu d'évolution prévue
- `/lib/widgets/user_moderation_status.dart` - Peut afficher plus de détails
- `/functions/src/moderation.ts` - Ajouter auto-modération ici
- `/lib/pages/publish_offer_page.dart` - Intégrer validation côté client?

## 📱 Points de contact utilisateur

Les utilisateurs interagissent avec la modération aux points suivants:
1. **Publication** : Message feedback "Offre en attente de validation ⏳"
2. **Profil** : Avertissements visibles en container orange
3. **Annonce** : Badge "Rejetée" ou "Attente de validation"
4. **Email** : Notification avec raison du rejet
5. **Messages** : Notification interne (collection `notifications`)

## 🎯 Métriques de succès

Une fois déployé, vérifier:
- [ ] Temps de modération < 24h
- [ ] Taux de rejet < 5% (normal)
- [ ] Utilisateurs satisfaits (feedback)
- [ ] Aucun faux positif de rejet
- [ ] Email deliverability > 95%

## 📞 Support et Troubleshooting

**Si Cloud Functions ne déclenche pas:**
1. Vérifier les logs: `firebase functions:log`
2. Vérifier les env vars: `firebase functions:config:get`
3. Vérifier la syntaxe Firestore: console Firestore
4. Redéployer si modification de code

**Si emails ne sont pas envoyés:**
1. Vérifier les variables GMAIL_USER et GMAIL_PASSWORD
2. Vérifier que Gmail App Password est configuré (pas pwd principal)
3. Vérifier les logs Cloud Functions
4. Tester avec un compte Gmail de test

**Si badges ne s'affichent pas:**
1. Vérifier que `status` field existe sur l'offre
2. Vérifier les valeurs possibles: `pending_moderation`, `active`, etc.
3. Vérifier le hot-reload fonctionne

---

**Next owner:** À assigner
**Deadline:** Déploiement avant production
**Priority:** Haute (feature demandée)
