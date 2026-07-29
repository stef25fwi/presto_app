#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

import sharp from "sharp";

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

async function main() {
  const root = process.cwd();
  const transcriptionFile = path.resolve(root, "evals/transcription_cases.jsonl");
  const visionFile = path.resolve(root, "evals/vision_cases.jsonl");
  const transcriptions = await loadJsonl(transcriptionFile);
  const visions = await loadJsonl(visionFile);

  for (const fixture of transcriptions) {
    const output = path.resolve(path.dirname(transcriptionFile), fixture.audio);
    await fs.mkdir(path.dirname(output), { recursive: true });
    run("espeak-ng", [
      "-v",
      fixture.voice || "fr-fr",
      "-s",
      String(fixture.speed || 145),
      "-w",
      output,
      fixture.expectedText,
    ]);
  }

  for (const fixture of visions) {
    const output = path.resolve(path.dirname(visionFile), fixture.image);
    await fs.mkdir(path.dirname(output), { recursive: true });
    const pipeline = sharp(Buffer.from(svgForCase(fixture.id))).resize(1024, 768);
    if (path.extname(output).toLowerCase() === ".png") {
      await pipeline.png().toFile(output);
    } else if (path.extname(output).toLowerCase() === ".webp") {
      await pipeline.webp({ quality: 90 }).toFile(output);
    } else {
      await pipeline.jpeg({ quality: 90 }).toFile(output);
    }
  }

  console.log(
    JSON.stringify({
      ok: true,
      privacy: "synthetic-no-user-data",
      transcriptionCases: transcriptions.length,
      visionCases: visions.length,
    }),
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
