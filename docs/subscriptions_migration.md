# Migration Abonnements

Objectif : initialiser les champs abonnement sur les documents users existants sans activer Stripe et sans appliquer de restriction.

Champs préparés :

- subscriptionPlan
- subscriptionStatus
- subscriptionExpiresAt
- phoneVerified
- proVerified

Règles de sécurité de la migration :

- dry-run par défaut
- n’écrit que les champs manquants
- ne remplace pas un plan ou un statut déjà présent
- ne touche pas aux règles Firestore
- n’ajoute aucune logique Stripe

Commande dry-run :

```bash
node tools/seed_subscription_fields.cjs
```

Commande ciblée sur un utilisateur :

```bash
node tools/seed_subscription_fields.cjs --uid=USER_UID
```

Commande réelle :

```bash
node tools/seed_subscription_fields.cjs --apply
```

Commande réelle avec limite réduite :

```bash
node tools/seed_subscription_fields.cjs --apply --limit=25
```

Comportement :

- subscriptionPlan manquant -> free
- subscriptionStatus manquant -> inactive
- subscriptionExpiresAt manquant -> null
- phoneVerified manquant -> recopié depuis isPhoneVerified ou phoneNumberVerified si présent, sinon false
- proVerified manquant -> recopié depuis siretVerified ou isProVerified si présent, sinon déduit du type de compte professionnel, sinon false

Vérification recommandée :

1. lancer le dry-run
2. vérifier les patchs proposés
3. appliquer sur un petit lot avec --limit
4. contrôler quelques documents users dans Firestore
5. seulement ensuite lancer la migration complète