# Commandes de correction iliprestō

Chaque script repart de `main`, exige un dépôt propre, crée une branche dédiée, applique le lot et lance les tests. Aucun push ni déploiement automatique.

```bash
bash commandes_correction_ilipresto/01_proteger_numeros.sh /workspaces/presto_app
bash commandes_correction_ilipresto/02_dependances_critiques.sh /workspaces/presto_app
bash commandes_correction_ilipresto/03_supprimer_fallback_messagerie.sh /workspaces/presto_app
bash commandes_correction_ilipresto/04_retirer_splash_3_5s.sh /workspaces/presto_app
bash commandes_correction_ilipresto/05_runapp_avant_initialisations.sh /workspaces/presto_app
bash commandes_correction_ilipresto/06_storage_appcheck.sh /workspaces/presto_app
bash commandes_correction_ilipresto/07_desactiver_otp_incomplet.sh /workspaces/presto_app
bash commandes_correction_ilipresto/08_carrousel_villes.sh /workspaces/presto_app
bash commandes_correction_ilipresto/09_tests_rules_ci.sh /workspaces/presto_app
bash commandes_correction_ilipresto/10_preparer_decoupage_flutter.sh /workspaces/presto_app
```

Après validation d’un lot :

```bash
git add -A
git commit -m "message du lot"
git push -u origin "$(git branch --show-current)"
```

Préparation abonnements, sans Stripe ni restrictions :

```bash
node tools/seed_subscription_fields.cjs
node tools/seed_subscription_fields.cjs --uid=USER_UID
node tools/seed_subscription_fields.cjs --apply --limit=25
```

Voir aussi [docs/subscriptions_migration.md](docs/subscriptions_migration.md).

Audit et nettoyage des users legacy/test :

```bash
node tools/cleanup_legacy_user_stubs.cjs
node tools/cleanup_legacy_user_stubs.cjs --apply --limit=25
node tools/manage_test_seed_users.cjs
node tools/manage_test_seed_users.cjs --apply --limit=25
node tools/manage_test_seed_users.cjs --apply --with-auth --limit=25
node tools/manage_test_seed_auth.cjs
node tools/manage_test_seed_auth.cjs --apply
```

Voir aussi [docs/users_audit_20260706.md](docs/users_audit_20260706.md).
