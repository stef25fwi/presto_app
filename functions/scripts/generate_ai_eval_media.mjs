#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

import ffmpegPath from "ffmpeg-static";
import sharp from "sharp";

import { probeDurationSeconds } from "./ai_media_probe.mjs";

/**
 * Corpus synthétique reproductible : aucune donnée utilisateur n'est
 * versionnée. La voix est produite par espeak-ng puis transcodée par ffmpeg
 * vers chaque conteneur réellement accepté par la Micro IA, afin que les
 * seuils de qualité soient mesurés sur les mêmes formats qu'en production.
 */

const AUDIO_ENCODERS = {
  wav: { args: ["-codec:a", "pcm_s16le", "-ar", "16000", "-ac", "1"] },
  mp3: { args: ["-codec:a", "libmp3lame", "-b:a", "64k", "-ar", "44100", "-ac", "1"] },
  ogg: { args: ["-codec:a", "libopus", "-b:a", "32k", "-ar", "48000", "-ac", "1"] },
  webm: { args: ["-codec:a", "libopus", "-b:a", "32k", "-ar", "48000", "-ac", "1"] },
  flac: { args: ["-codec:a", "flac", "-ar", "16000", "-ac", "1"] },
  m4a: { args: ["-codec:a", "aac", "-b:a", "64k", "-ar", "44100", "-ac", "1"] },
};

async function loadJsonl(filePath) {
  const raw = await fs.readFile(filePath, "utf8");
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(`${command} failed: ${result.stderr || result.stdout}`);
  }
  return result;
}

function espeakVoice(fixture) {
  const base = fixture.voice || "fr-fr";
  return fixture.variant ? `${base}+${fixture.variant}` : base;
}

function formatOf(fixture) {
  const declared = fixture.format || path.extname(fixture.audio).replace(".", "");
  const format = String(declared).toLowerCase();
  if (!AUDIO_ENCODERS[format]) {
    throw new Error(`Format audio non supporté pour ${fixture.id}: ${format}`);
  }
  return format;
}

function svgForCase(id) {
  const common = 'width="1024" height="768" viewBox="0 0 1024 768" xmlns="http://www.w3.org/2000/svg"';
  if (id === "plumber-sink") {
    return `<svg ${common}><rect width="1024" height="768" fill="#f6f1ea"/><rect x="210" y="170" width="600" height="170" rx="35" fill="#d7e7ef" stroke="#20445a" stroke-width="18"/><path d="M510 170v-90c0-45 80-45 80 0v50" fill="none" stroke="#20445a" stroke-width="28"/><path d="M320 340v120h380V340" fill="none" stroke="#20445a" stroke-width="22"/><path d="M540 460v105c0 75-120 75-120 150" fill="none" stroke="#ff6600" stroke-width="32"/><circle cx="420" cy="710" r="26" fill="#1a73e8"/></svg>`;
  }
  if (id === "garden-mower") {
    return `<svg ${common}><rect width="1024" height="768" fill="#dff2d8"/><path d="M0 560h1024v208H0z" fill="#68a84f"/><rect x="250" y="370" width="430" height="170" rx="45" fill="#ff6600" stroke="#17324d" stroke-width="18"/><circle cx="340" cy="555" r="75" fill="#253746"/><circle cx="610" cy="555" r="75" fill="#253746"/><path d="M640 380l150-220h90" fill="none" stroke="#17324d" stroke-width="28"/><path d="M180 610h650" stroke="#f7cf3a" stroke-width="18" stroke-dasharray="35 25"/></svg>`;
  }
  return `<svg ${common}><rect width="1024" height="768" fill="#cae8ff"/><circle cx="820" cy="140" r="85" fill="#ffd24a"/><path d="M0 520l250-240 180 180 150-140 280 280H0z" fill="#739b66"/><path d="M0 610h1024v158H0z" fill="#4f8bc9"/></svg>`;
}

async function generateAudio(fixtures, transcriptionFile, workDirectory) {
  const manifest = [];
  for (const fixture of fixtures) {
    const format = formatOf(fixture);
    const output = path.resolve(path.dirname(transcriptionFile), fixture.audio);
    await fs.mkdir(path.dirname(output), { recursive: true });

    const sourceWav = path.join(workDirectory, `${fixture.id}.source.wav`);
    run("espeak-ng", [
      "-v",
      espeakVoice(fixture),
      "-s",
      String(fixture.speed || 145),
      "-w",
      sourceWav,
      fixture.expectedText,
    ]);

    run(ffmpegPath, [
      "-hide_banner",
      "-loglevel",
      "error",
      "-i",
      sourceWav,
      ...AUDIO_ENCODERS[format].args,
      "-y",
      output,
    ]);

    const bytes = await fs.readFile(output);
    manifest.push({
      id: fixture.id,
      accent: fixture.accent || fixture.voice || "fr-FR",
      variant: fixture.variant || null,
      speed: fixture.speed || 145,
      format,
      contentType: fixture.contentType || null,
      file: fixture.audio,
      sizeBytes: bytes.length,
      durationSeconds: probeDurationSeconds(output),
      sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    });
  }
  return manifest;
}

async function generateImages(fixtures, visionFile) {
  const manifest = [];
  for (const fixture of fixtures) {
    const output = path.resolve(path.dirname(visionFile), fixture.image);
    await fs.mkdir(path.dirname(output), { recursive: true });
    const pipeline = sharp(Buffer.from(svgForCase(fixture.id))).resize(1024, 768);
    const extension = path.extname(output).toLowerCase();
    if (extension === ".png") {
      await pipeline.png().toFile(output);
    } else if (extension === ".webp") {
      await pipeline.webp({ quality: 90 }).toFile(output);
    } else {
      await pipeline.jpeg({ quality: 90 }).toFile(output);
    }
    const bytes = await fs.readFile(output);
    manifest.push({
      id: fixture.id,
      file: fixture.image,
      format: extension.replace(".", ""),
      sizeBytes: bytes.length,
      sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    });
  }
  return manifest;
}

async function main() {
  if (!ffmpegPath) throw new Error("ffmpeg-static est requis pour transcoder le corpus");
  const root = process.cwd();
  const transcriptionFile = path.resolve(root, "evals/transcription_cases.jsonl");
  const visionFile = path.resolve(root, "evals/vision_cases.jsonl");
  const transcriptions = await loadJsonl(transcriptionFile);
  const visions = await loadJsonl(visionFile);

  const workDirectory = await fs.mkdtemp(path.join(os.tmpdir(), "ai-eval-media-"));
  let audioManifest;
  try {
    audioManifest = await generateAudio(transcriptions, transcriptionFile, workDirectory);
  } finally {
    await fs.rm(workDirectory, { recursive: true, force: true });
  }
  const imageManifest = await generateImages(visions, visionFile);

  const manifest = {
    generatedAt: new Date().toISOString(),
    privacy: "synthetic-no-user-data",
    accents: [...new Set(audioManifest.map((item) => item.accent))].sort(),
    audioFormats: [...new Set(audioManifest.map((item) => item.format))].sort(),
    imageFormats: [...new Set(imageManifest.map((item) => item.format))].sort(),
    audio: audioManifest,
    images: imageManifest,
  };
  const manifestPath = path.resolve(root, "evals/media/manifest.json");
  await fs.mkdir(path.dirname(manifestPath), { recursive: true });
  await fs.writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

  console.log(
    JSON.stringify({
      ok: true,
      privacy: manifest.privacy,
      transcriptionCases: audioManifest.length,
      visionCases: imageManifest.length,
      accents: manifest.accents,
      audioFormats: manifest.audioFormats,
      manifest: path.relative(root, manifestPath),
    }),
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
