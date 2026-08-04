import { spawnSync } from "node:child_process";

import ffmpegPath from "ffmpeg-static";

/**
 * Durée d'un média local, mesurée par ffmpeg.
 *
 * ffmpeg-static n'embarque pas ffprobe : la durée est lue sur la sortie
 * d'analyse de ffmpeg lui-même. Retourne `null` si le média est illisible,
 * jamais une estimation inventée.
 */
export function probeDurationSeconds(filePath) {
  if (!ffmpegPath) return null;
  const result = spawnSync(ffmpegPath, ["-hide_banner", "-i", filePath], {
    encoding: "utf8",
  });
  const output = `${result.stderr || ""}${result.stdout || ""}`;
  const match = output.match(/Duration:\s*(\d+):(\d{2}):(\d{2}\.\d+)/);
  if (!match) return null;
  const seconds =
    Number(match[1]) * 3600 + Number(match[2]) * 60 + Number(match[3]);
  return Number(seconds.toFixed(3));
}
