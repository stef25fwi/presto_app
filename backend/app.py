"""
Micro IA Stream Backend - WebSocket server for real-time transcription & draft generation
Streaming architecture: Audio → Google STT → Gemini Draft Generation → Client
"""

import json
import base64
import logging
import os
from io import BytesIO
from typing import Optional, Dict, Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

from google.cloud import speech
import google.generativeai as genai

# Configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GCP_PROJECT = os.getenv("GCP_PROJECT", "151421230024")

if not GEMINI_API_KEY:
    logger.warning("⚠️ GEMINI_API_KEY not set - draft generation will be disabled")
else:
    genai.configure(api_key=GEMINI_API_KEY)

# Initialize clients
speech_client = speech.SpeechClient()
app = FastAPI(title="Micro IA Stream", version="1.0.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class StreamConfig(BaseModel):
    """Configuration pour un stream audio"""
    language_code: str = "fr-FR"
    city_hint: Optional[str] = None
    category_hint: Optional[str] = None


@app.websocket("/stream")
async def websocket_stream(websocket: WebSocket):
    """
    WebSocket endpoint pour streaming audio temps réel
    
    Protocol:
    → {"event": "start", "languageCode": "fr-FR", "cityHint": "Paris", "categoryHint": "Jardinage"}
    → {"event": "audio", "chunk": "base64_encoded_pcm16"}
    → {"event": "stop"}
    
    ← {"event": "partial", "transcript": "..."}
    ← {"event": "final", "transcript": "...", "draft": {...}, "quality": {...}, "modeUsed": "streaming"}
    ← {"event": "error", "message": "..."}
    """
    await websocket.accept()
    logger.info("✅ WebSocket client connected")
    
    try:
        audio_chunks = []
        config = None
        transcript_full = ""
        
        while True:
            message = await websocket.receive_text()
            data = json.loads(message)
            event = data.get("event")
            
            if event == "start":
                # Initialize streaming session
                config = StreamConfig(
                    language_code=data.get("languageCode", "fr-FR"),
                    city_hint=data.get("cityHint"),
                    category_hint=data.get("categoryHint"),
                )
                audio_chunks = []
                logger.info(f"🎤 Stream started: {config.language_code}")
                
            elif event == "audio":
                # Accumulate audio chunks
                chunk_b64 = data.get("chunk", "")
                if chunk_b64:
                    audio_chunks.append(base64.b64decode(chunk_b64))
                    logger.debug(f"📦 Received audio chunk: {len(chunk_b64)} bytes")
                
            elif event == "stop":
                # Process accumulated audio
                if not audio_chunks:
                    await websocket.send_json({
                        "event": "error",
                        "message": "No audio data received"
                    })
                    continue
                
                try:
                    # Combine audio chunks
                    audio_bytes = b"".join(audio_chunks)
                    
                    # Transcribe with Google STT
                    logger.info(f"🎯 Transcribing {len(audio_bytes)} bytes...")
                    transcript = await _transcribe_audio(
                        audio_bytes,
                        config.language_code
                    )
                    transcript_full = transcript
                    
                    # Send partial result
                    await websocket.send_json({
                        "event": "partial",
                        "transcript": transcript
                    })
                    
                    # Generate draft with Gemini
                    logger.info(f"✨ Generating draft with Gemini...")
                    draft_result = await _generate_draft(
                        transcript=transcript,
                        city_hint=config.city_hint,
                        category_hint=config.category_hint,
                    )
                    
                    # Send final result
                    await websocket.send_json({
                        "event": "final",
                        "transcript": transcript,
                        "draft": draft_result.get("draft"),
                        "quality": draft_result.get("quality", {}),
                        "modeUsed": "streaming"
                    })
                    
                    audio_chunks = []
                    logger.info("✅ Stream processing completed")
                    
                except Exception as e:
                    logger.error(f"❌ Error processing audio: {e}")
                    await websocket.send_json({
                        "event": "error",
                        "message": str(e)
                    })
            
            else:
                logger.warning(f"⚠️ Unknown event: {event}")
                
    except WebSocketDisconnect:
        logger.info("👋 WebSocket client disconnected")
    except Exception as e:
        logger.error(f"❌ WebSocket error: {e}")
        try:
            await websocket.send_json({
                "event": "error",
                "message": f"Server error: {str(e)}"
            })
        except:
            pass


async def _transcribe_audio(audio_bytes: bytes, language_code: str) -> str:
    """Transcribe audio using Google Cloud Speech-to-Text"""
    try:
        # Configure audio
        audio = speech.RecognitionAudio(content=audio_bytes)
        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000,
            language_code=language_code,
            enable_automatic_punctuation=True,
        )
        
        # Recognize speech
        response = speech_client.recognize(config=config, audio=audio)
        
        # Extract transcript
        transcript = ""
        for result in response.results:
            for alternative in result.alternatives:
                transcript += alternative.transcript + " "
        
        return transcript.strip()
        
    except Exception as e:
        logger.error(f"STT error: {e}")
        return ""


async def _generate_draft(
    transcript: str,
    city_hint: Optional[str] = None,
    category_hint: Optional[str] = None,
) -> Dict[str, Any]:
    """Generate offer draft using Gemini API"""
    
    if not GEMINI_API_KEY:
        logger.warning("Gemini API not configured - returning empty draft")
        return {"draft": None}
    
    try:
        # Build prompt
        context = []
        if category_hint:
            context.append(f"Catégorie: {category_hint}")
        if city_hint:
            context.append(f"Lieu: {city_hint}")
        
        context_str = "\n".join(context) if context else ""
        
        prompt = f"""Tu es un expert en rédaction d'annonces de services. 
À partir du texte vocal suivant (transcrit en français), génère un brouillon d'annonce professionnelle pour une plateforme de services.

Contexte additionnel:
{context_str}

Texte transcrit:
"{transcript}"

Réponds UNIQUEMENT en JSON valide avec cette structure exacte:
{{
    "title": "Titre court et attractif (max 60 caractères)",
    "description": "Description détaillée (2-3 phrases professionnelles)",
    "category": "Catégorie détectée ou '{category_hint or 'Autre'}' si aucune",
    "budget_min": 0,
    "budget_max": 0,
    "location": "{city_hint or 'À déterminer'}",
    "is_urgent": false,
    "tags": ["tag1", "tag2"]
}}"""

        # Call Gemini
        model = genai.GenerativeModel('gemini-pro')
        response = model.generate_content(prompt)
        
        # Parse response
        response_text = response.text.strip()
        if response_text.startswith("```json"):
            response_text = response_text[7:]
        if response_text.startswith("```"):
            response_text = response_text[3:]
        if response_text.endswith("```"):
            response_text = response_text[:-3]
        
        draft = json.loads(response_text.strip())
        
        return {
            "draft": draft,
            "quality": {
                "confidence": 0.85,
                "completeness": 0.9,
            }
        }
        
    except Exception as e:
        logger.error(f"Gemini error: {e}")
        return {"draft": None, "quality": {"error": str(e)}}


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "service": "Micro IA Stream",
        "version": "1.0.0"
    }


@app.get("/")
async def root():
    """Welcome endpoint"""
    return {
        "message": "Micro IA Stream Server",
        "docs": "/docs",
        "websocket": "/stream"
    }


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
