# Monitoring du Streaming Micro IA

## Intégration Admin

Le monitoring du WebSocket streaming est maintenant intégré dans l'espace admin sous le tuile **"Streaming"**.

### Accès
1. Ouvrir l'app Presto
2. Aller dans l'espace Admin (Compte → Admin)
3. Cliquer sur le tuile **"Streaming"** (icône vitesse - Speed)

### Métriques Affichées

#### KPIs (indicateurs clés)
- **Total Requests**: Nombre total de requêtes de streaming
- **Success Rate**: Pourcentage de requêtes réussies
- **Average Latency**: Temps moyen de traitement (ms)
- **Estimated Cost**: Coût estimé GCP pour aujourd'hui (USD)
- **Active Streams**: Nombre de flux actuels actifs
- **Error Count**: Nombre d'erreurs aujourd'hui

#### Backend Status
- **URL WebSocket**: wss://presto-microia-stream-151421230024.us-east1.run.app/stream
- **Region**: us-east1 (optimisé Caribbean/Guadeloupe)
- **Status**: Vérification automatique de la disponibilité

#### Trends (24h)
- Graphique d'évolution des requêtes sur les 24 dernières heures
- Permet de visualiser les pics d'utilisation

## Configuration Requise

### Variables d'environnement
```bash
# Pour tester le streaming en local
flutter run --dart-define=MICROIA_STREAM_URL=wss://presto-microia-stream-151421230024.us-east1.run.app/stream
```

### Cloud Functions (dépendance optionnelle)
Le monitoring fait appel à la Cloud Function `adminGetStreamingMetrics` pour récupérer les métriques en temps réel.

Si cette fonction n'existe pas, les métriques s'afficheront avec des valeurs par défaut.

## Backend WebSocket

**URL**: wss://presto-microia-stream-151421230024.us-east1.run.app/stream  
**Région**: us-east1 (Virginia)  
**Port**: 443 (WebSocket sécurisé)

### Architecture
- Client: Flutter (publish_offer_page.dart)
- Transport: WebSocket JSON
- Backend: Python FastAPI
- Services: Google Cloud Speech-to-Text + Gemini AI

### Performance Cible
- Latence: 3-8 secondes (vs 6-18s en mode legacy)
- Réduction: ~50-60% plus rapide

## Fichiers Liés

### Frontend
- [StreamingMonitoringPage](lib/pages/admin/streaming_monitoring_page.dart): Dashboard de monitoring (434 lignes)
- [AdminSpacePage](lib/pages/admin_space_page.dart): Espace admin avec tuile de monitoring
- [MicroIaStreamClient](lib/features/micro_ia/micro_ia_stream_client.dart): Client WebSocket
- [PublishOfferPage](lib/pages/publish_offer_page.dart): Intégration streaming audio

### Backend
- [app.py](backend/app.py): Serveur FastAPI WebSocket (434 lignes)
- [requirements.txt](backend/requirements.txt): Dépendances Python
- [Dockerfile](backend/Dockerfile): Configuration Cloud Run
- [README.md](backend/README.md): Documentation complète

## Dépannage

### Le monitoring affiche "Waiting for data..."
- Vérifier que le backend est accessible: https://presto-microia-stream-151421230024.us-east1.run.app/health
- Attendre 2-3 secondes de rechargement
- Vérifier la connexion réseau

### Les KPIs ne se mettent pas à jour
- Vérifier que `adminGetStreamingMetrics` Cloud Function est déployée
- Ou créer une Cloud Function simple qui retourne des données mock
- Sinon, les valeurs par défaut (0, "—") s'affichent

### Le streaming ne fonctionne pas en production
1. Vérifier que `MICROIA_STREAM_URL` est défini dans les variables d'environnement build
2. S'assurer que le backend Cloud Run est en état "Ready"
3. Vérifier que le client a les droits Firebase Auth
4. Consulter les logs Cloud Run: `gcloud run logs read presto-microia-stream --region us-east1`

## Coûts Estimés

### Cloud Run (Backend)
- Prix: ~$0.00002 par requête
- 1000 requêtes/jour = ~$2/jour = ~$60/mois

### Speech-to-Text
- Prix: $0.020 par 15 secondes
- 1000 requêtes × 20 sec = ~$26/jour

### Generative AI (Gemini)
- Prix: $0.075 par 1M input tokens
- Estimé: ~$5/jour pour 1000 requêtes

**Total estimé**: ~$100/jour pour 1000 requêtes (4000 requêtes/jour utilisateurs actifs)

## Logs et Debugging

### Logs Cloud Run
```bash
gcloud run logs read presto-microia-stream --region us-east1 --limit 100
```

### Logs Local (pendant flutter run)
```
I/MICROIA: Stream client initializing
I/MICROIA: Connected to wss://...
I/MICROIA: Audio chunk sent (1024 bytes)
I/MICROIA: Received partial: "Bonjour..."
I/MICROIA: Final result received
```

### Erreurs Courantes
1. **"Connection refused"** → Backend pas accessible
2. **"Timeout"** → Réseau lent ou API lente
3. **"Unauthorized"** → Token Firebase invalid
4. **"Language not supported"** → Changer de langue (actuellement fr-FR)

## Améliorations Futures

- [ ] Implémenter `adminGetStreamingMetrics` Cloud Function
- [ ] Ajouter graphique 24h temps réel (chart_flutter)
- [ ] Migrer vers un package audio supportant le streaming réel
- [ ] Tests de charge avec conditions réseau Caribbean simulées
- [ ] Extraction OfferDetailPage vers fichier séparé (11KB monolithe)
- [ ] Caching des métriques côté client (reduce Firebase calls)

## Support

Pour toute question:
1. Consulter [backend/README.md](backend/README.md)
2. Vérifier les logs via GCP Console
3. Tester avec: `--dart-define=MICROIA_STREAM_URL=...`
