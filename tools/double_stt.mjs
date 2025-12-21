import fs from "fs";
import path from "path";
import process from "process";
import { SpeechClient } from "@google-cloud/speech";
import OpenAI from "openai";

function arg(name, def=null){
  const i = process.argv.indexOf(name);
  return i>=0 ? process.argv[i+1] : def;
}

const file = arg("--file");
if (!file) { console.error("Usage: node tools/double_stt.mjs --file <audio.flac|wav|mp3>"); process.exit(1); }

const buf = fs.readFileSync(file);
const ext = path.extname(file).toLowerCase().slice(1); // sans le point
const audio = { content: buf.toString("base64") };

// Mapping extension -> Google Speech-to-Text encoding
const encodingMap = {
  "flac": "FLAC",
  "wav": "LINEAR16",
  "mp3": "MP3",
  "ogg": "OGG_OPUS",
  "webm": "WEBM_OPUS"
};

const encoding = encodingMap[ext] || "LINEAR16"; // Défaut: LINEAR16 pour WAV

// Détecte la fréquence d'échantillonnage depuis le header WAV
function detectSampleRate(buffer) {
  if (ext !== "wav") return 16000; // Par défaut pour les autres formats
  
  // WAV header: sample rate est aux bytes 24-27 (little-endian)
  if (buffer.length < 28) return 16000;
  
  const sampleRate = buffer.readUInt32LE(24);
  console.log(`[WAV] Sample rate détecté: ${sampleRate} Hz`);
  return sampleRate;
}

const sampleRate = detectSampleRate(buf);

const googleClient = new SpeechClient();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

async function sttGoogle() {
  console.log(`[Google STT] Format détecté: ${ext} -> Encoding: ${encoding}, Sample Rate: ${sampleRate}`);
  const request = {
    config: {
      encoding: encoding,
      sampleRateHertz: sampleRate,
      languageCode: "fr-FR",
      enableAutomaticPunctuation: true,
    },
    audio
  };
  const [resp] = await googleClient.recognize(request);
  const best = resp.results?.[0]?.alternatives?.[0];
  return {
    transcript: best?.transcript ?? "",
    confidence: best?.confidence ?? null,
    raw: resp
  };
}

async function sttOpenAI() {
  try {
    const f = fs.createReadStream(file);
    const r = await openai.audio.transcriptions.create({
      file: f,
      model: "whisper-1",
      language: "fr",
    });
    return { transcript: r.text ?? "" };
  } catch (error) {
    console.error(`[OpenAI STT] Erreur: ${error.error?.message || error.message}`);
    return { transcript: "", error: true };
  }
}

const [g, o] = await Promise.all([sttGoogle(), sttOpenAI()]);

console.log("\n=== GOOGLE STT ===");
console.log("confidence:", g.confidence);
console.log(g.transcript);

if (!o.error) {
  console.log("\n=== OPENAI STT ===");
  console.log(o.transcript);

  // Décision simple: si Google confidence >= 0.85 => Google sinon OpenAI
  const chosen = (g.confidence !== null && g.confidence >= 0.85) ? "google" : "openai";
  console.log("\n=== CHOSEN ===", chosen);
  console.log(chosen === "google" ? g.transcript : o.transcript);
} else {
  console.log("\n⚠️ OpenAI STT indisponible (quota dépassé ou erreur API)");
  console.log("Utilisation de Google STT par défaut");
  console.log("\n=== CHOSEN ===", "google");
  console.log(g.transcript);
}
