# Micro IA Stream Backend

Service WebSocket Python FastAPI pour transcription audio temps réel et génération de brouillons d'annonces avec Gemini.

## Architecture

```
Client (Flutter/Dart)
    ↓ WebSocket (wss://...)
    ├─ event: "start" (languageCode, hints)
    ├─ event: "audio" (chunks base64 PCM16)
    └─ event: "stop"
    ↓
Server (FastAPI)
    ├─ Google Cloud Speech-to-Text (STT)
    ├─ Google Gemini API (Draft generation)
    └─ Real-time responses (partial + final)
```

## Configuration requise

1. **Google Cloud Project** avec :
   - ✅ Speech-to-Text API activée
   - ✅ Generative AI API activée
   - ✅ Service account avec clés JSON

2. **Variables d'environnement** :
   ```bash
   export GEMINI_API_KEY="your-gemini-api-key"
   export GCP_PROJECT="your-project-id"
   export PORT=8080
   ```

3. **Authentification Google Cloud** :
   ```bash
   gcloud auth application-default login
   # ou
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/credentials.json"
   ```

## Installation locale

```bash
# 1. Créer venv
python3 -m venv venv
source venv/bin/activate  # Linux/macOS
# ou
venv\Scripts\activate  # Windows

# 2. Installer dépendances
pip install -r requirements.txt

# 3. Lancer serveur
python app.py
```

Le serveur écoute sur `http://localhost:8080`
- WebSocket: `ws://localhost:8080/stream`
- Health: `http://localhost:8080/health`
- Docs: `http://localhost:8080/docs`

## Déploiement Cloud Run

```bash
# 1. Depuis le répertoire backend
cd backend

# 2. Déployer
gcloud run deploy presto-microia-stream \
  --source . \
  --region us-east1 \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY=$GEMINI_API_KEY

# 3. Copier l'URL du service
# Exemple: https://presto-microia-stream-xxxxx-ue.a.run.app

# 4. Utiliser en WebSocket
# wss://presto-microia-stream-xxxxx-ue.a.run.app/stream
```

## Protocole WebSocket

### Client → Server

**Start event** (obligatoire):
```json
{
  "event": "start",
  "languageCode": "fr-FR",
  "cityHint": "Guadeloupe",
  "categoryHint": "Jardinage"
}
```

**Audio event** (répété):
```json
{
  "event": "audio",
  "chunk": "base64_encoded_pcm16_bytes"
}
```

**Stop event** (fin du stream):
```json
{
  "event": "stop"
}
```

### Server → Client

**Partial result** (transcription en cours):
```json
{
  "event": "partial",
  "transcript": "Je cherche quelqu'un pour..."
}
```

**Final result** (complet avec draft):
```json
{
  "event": "final",
  "transcript": "Je cherche quelqu'un pour jardiner ma maison",
  "draft": {
    "title": "Besoin aide jardinage maison",
    "description": "Recherche jardinier expérimenté...",
    "category": "Jardinage",
    "budget_min": 0,
    "budget_max": 0,
    "location": "Guadeloupe",
    "is_urgent": false,
    "tags": ["jardinage", "maison"]
  },
  "quality": {
    "confidence": 0.85,
    "completeness": 0.9
  },
  "modeUsed": "streaming"
}
```

**Error event**:
```json
{
  "event": "error",
  "message": "Erreur de transcription..."
}
```

## Performance

- **Latence STT**: 2-5s (Google Cloud Speech)
- **Latence Gemini**: 1-3s (draft generation)
- **Total**: ~3-8s vs 6-18s (ancien système)
- **Réduction**: **50-60% de latence**

## Troubleshooting

### Error: "GEMINI_API_KEY not set"
```bash
export GEMINI_API_KEY="your-key-here"
python app.py
```

### Error: "Google Cloud credentials not found"
```bash
gcloud auth application-default login
```

### WebSocket connection refused
- Vérifier que le serveur écoute (http://localhost:8080/health)
- Vérifier firewall/ports
- Vérifier URL WebSocket (ws:// pour local, wss:// pour HTTPS)

### Draft generation slow
- C'est normal (Gemini prend 1-3s)
- Réduire la complexité du prompt si besoin
- Ajouter timeout côté client (12s)

## Coûts GCP estimés

| Service | Coût | Notes |
|---------|------|-------|
| Speech-to-Text | $0.024/15 min | ~$1.73/jour (1000 req) |
| Gemini API | Gratuit (beta) | Peut changer |
| Cloud Run | ~$0.10/jour | 256MB, 1 instance |
| **Total** | **~$2/jour** | Hautement dépendant du trafic |

## Next Steps

1. ✅ Backend déployé sur Cloud Run
2. ⏳ Réactiver streaming côté Flutter (ligne 90 publish_offer_page.dart)
3. ⏳ Tester avec `flutter run --dart-define=MICROIA_STREAM_URL=wss://...`
4. ⏳ Monitorer performance et coûts GCP
