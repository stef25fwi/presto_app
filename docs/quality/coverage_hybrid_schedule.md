# Déclenchement hybride de Coverage Autopilot

Le workflow de couverture fonctionne avec trois déclencheurs complémentaires :

- immédiatement après une modification pertinente fusionnée sur `main` ;
- manuellement depuis GitHub Actions ;
- toutes les 15 minutes comme contrôle de sécurité.

La concurrence reste limitée par le groupe `coverage-autopilot` et le workflow ne crée aucune nouvelle tâche lorsqu’une issue `coverage-agent` est déjà ouverte.
