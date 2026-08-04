import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import ffmpegPath from "ffmpeg-static";

import {
  containerFromContentType,
  estimateAudioDurationSeconds,
  sniffAudioContainer,
} from "./audio_duration";

const REFERENCE_SECONDS = 3.5;
const TOLERANCE_SECONDS = 0.25;

/**
 * Les cas nominaux sont validés sur de vrais fichiers encodés par ffmpeg :
 * un analyseur qui ne saurait lire qu'un entête fabriqué à la main ne
 * prouverait rien sur les enregistrements réels de la Micro IA.
 */
const ENCODINGS: ReadonlyArray<{
  name: string;
  file: string;
  contentType: string;
  args: readonly string[];
}> = [
  {
    name: "wav",
    file: "sample.wav",
    contentType: "audio/wav",
    args: ["-ar", "16000", "-ac", "1"],
  },
  {
    name: "mp3",
    file: "sample.mp3",
    contentType: "audio/mpeg",
    args: ["-codec:a", "libmp3lame", "-b:a", "64k", "-ar", "44100", "-ac", "1"],
  },
  {
    name: "mp3-vbr",
    file: "sample-vbr.mp3",
    contentType: "audio/mpeg",
    args: ["-codec:a", "libmp3lame", "-q:a", "5", "-ar", "44100", "-ac", "2"],
  },
  {
    name: "ogg-opus",
    file: "sample.ogg",
    contentType: "audio/ogg",
    args: ["-codec:a", "libopus", "-b:a", "32k", "-ac", "1"],
  },
  {
    name: "ogg-vorbis",
    file: "sample-vorbis.ogg",
    contentType: "audio/ogg",
    args: ["-codec:a", "libvorbis", "-q:a", "3", "-ar", "44100", "-ac", "1"],
  },
  {
    name: "flac",
    file: "sample.flac",
    contentType: "audio/flac",
    args: ["-codec:a", "flac", "-ar", "16000", "-ac", "1"],
  },
  {
    name: "m4a",
    file: "sample.m4a",
    contentType: "audio/mp4",
    args: ["-codec:a", "aac", "-b:a", "64k", "-ar", "44100", "-ac", "1"],
  },
  {
    name: "webm-opus",
    file: "sample.webm",
    contentType: "audio/webm",
    args: ["-codec:a", "libopus", "-b:a", "32k", "-ac", "1"],
  },
];

function encodeFixtures(directory: string): Map<string, Buffer> | null {
  if (!ffmpegPath || !fs.existsSync(ffmpegPath)) return null;
  const buffers = new Map<string, Buffer>();
  for (const encoding of ENCODINGS) {
    const output = path.join(directory, encoding.file);
    const result = spawnSync(
      ffmpegPath,
      [
        "-hide_banner",
        "-loglevel",
        "error",
        "-f",
        "lavfi",
        "-i",
        `sine=frequency=440:duration=${REFERENCE_SECONDS}`,
        ...encoding.args,
        "-y",
        output,
      ],
      { encoding: "utf8" },
    );
    if (result.status !== 0) {
      throw new Error(`ffmpeg a échoué pour ${encoding.name}: ${result.stderr}`);
    }
    buffers.set(encoding.name, fs.readFileSync(output));
  }
  return buffers;
}

test("estimateAudioDurationSeconds couvre tous les formats audio acceptés", (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "audio-duration-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));

  const buffers = encodeFixtures(directory);
  if (!buffers) {
    t.skip("ffmpeg-static indisponible");
    return;
  }

  for (const encoding of ENCODINGS) {
    const buffer = buffers.get(encoding.name);
    assert.ok(buffer, `fixture manquante: ${encoding.name}`);
    const seconds = estimateAudioDurationSeconds(buffer, encoding.contentType);
    assert.ok(
      seconds !== null,
      `durée non détectée pour ${encoding.name} (${encoding.contentType})`,
    );
    assert.ok(
      Math.abs(seconds - REFERENCE_SECONDS) <= TOLERANCE_SECONDS,
      `durée ${seconds}s hors tolérance pour ${encoding.name}`,
    );
  }
});

test("la détection de conteneur ignore un content-type erroné", (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "audio-sniff-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));

  const buffers = encodeFixtures(directory);
  if (!buffers) {
    t.skip("ffmpeg-static indisponible");
    return;
  }

  const flac = buffers.get("flac");
  assert.ok(flac);
  assert.equal(sniffAudioContainer(flac), "flac");
  // Un navigateur qui déclare un mauvais type ne doit pas fausser la durée.
  const seconds = estimateAudioDurationSeconds(flac, "audio/wav");
  assert.ok(seconds !== null);
  assert.ok(Math.abs(seconds - REFERENCE_SECONDS) <= TOLERANCE_SECONDS);
});

test("containerFromContentType couvre les types déclarés par la Micro IA", () => {
  assert.equal(containerFromContentType("audio/x-wav"), "wav");
  assert.equal(containerFromContentType("audio/vnd.wave"), "wav");
  assert.equal(containerFromContentType("audio/x-m4a"), "mp4");
  assert.equal(containerFromContentType("audio/aac"), "mp4");
  assert.equal(containerFromContentType("audio/mp3"), "mp3");
  assert.equal(containerFromContentType("video/webm"), "webm");
  assert.equal(containerFromContentType("audio/ogg"), "ogg");
  assert.equal(containerFromContentType("audio/flac"), "flac");
  assert.equal(containerFromContentType("application/pdf"), null);
});

test("un contenu illisible ne produit jamais de durée inventée", () => {
  assert.equal(estimateAudioDurationSeconds(Buffer.alloc(0), "audio/wav"), null);
  assert.equal(
    estimateAudioDurationSeconds(Buffer.from("pas un fichier audio"), "audio/mpeg"),
    null,
  );
  // Entête WAV tronqué : aucun chunk `data` exploitable.
  const truncated = Buffer.concat([
    Buffer.from("RIFF"),
    Buffer.alloc(4),
    Buffer.from("WAVE"),
  ]);
  assert.equal(estimateAudioDurationSeconds(truncated, "audio/wav"), null);
});
