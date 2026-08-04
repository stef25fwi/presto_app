"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_child_process_1 = require("node:child_process");
const node_fs_1 = __importDefault(require("node:fs"));
const node_os_1 = __importDefault(require("node:os"));
const node_path_1 = __importDefault(require("node:path"));
const node_test_1 = __importDefault(require("node:test"));
const ffmpeg_static_1 = __importDefault(require("ffmpeg-static"));
const audio_duration_1 = require("./audio_duration");
const REFERENCE_SECONDS = 3.5;
const TOLERANCE_SECONDS = 0.25;
/**
 * Les cas nominaux sont validés sur de vrais fichiers encodés par ffmpeg :
 * un analyseur qui ne saurait lire qu'un entête fabriqué à la main ne
 * prouverait rien sur les enregistrements réels de la Micro IA.
 */
const ENCODINGS = [
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
function encodeFixtures(directory) {
    if (!ffmpeg_static_1.default || !node_fs_1.default.existsSync(ffmpeg_static_1.default))
        return null;
    const buffers = new Map();
    for (const encoding of ENCODINGS) {
        const output = node_path_1.default.join(directory, encoding.file);
        const result = (0, node_child_process_1.spawnSync)(ffmpeg_static_1.default, [
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
        ], { encoding: "utf8" });
        if (result.status !== 0) {
            throw new Error(`ffmpeg a échoué pour ${encoding.name}: ${result.stderr}`);
        }
        buffers.set(encoding.name, node_fs_1.default.readFileSync(output));
    }
    return buffers;
}
(0, node_test_1.default)("estimateAudioDurationSeconds couvre tous les formats audio acceptés", (t) => {
    const directory = node_fs_1.default.mkdtempSync(node_path_1.default.join(node_os_1.default.tmpdir(), "audio-duration-"));
    t.after(() => node_fs_1.default.rmSync(directory, { recursive: true, force: true }));
    const buffers = encodeFixtures(directory);
    if (!buffers) {
        t.skip("ffmpeg-static indisponible");
        return;
    }
    for (const encoding of ENCODINGS) {
        const buffer = buffers.get(encoding.name);
        strict_1.default.ok(buffer, `fixture manquante: ${encoding.name}`);
        const seconds = (0, audio_duration_1.estimateAudioDurationSeconds)(buffer, encoding.contentType);
        strict_1.default.ok(seconds !== null, `durée non détectée pour ${encoding.name} (${encoding.contentType})`);
        strict_1.default.ok(Math.abs(seconds - REFERENCE_SECONDS) <= TOLERANCE_SECONDS, `durée ${seconds}s hors tolérance pour ${encoding.name}`);
    }
});
(0, node_test_1.default)("la détection de conteneur ignore un content-type erroné", (t) => {
    const directory = node_fs_1.default.mkdtempSync(node_path_1.default.join(node_os_1.default.tmpdir(), "audio-sniff-"));
    t.after(() => node_fs_1.default.rmSync(directory, { recursive: true, force: true }));
    const buffers = encodeFixtures(directory);
    if (!buffers) {
        t.skip("ffmpeg-static indisponible");
        return;
    }
    const flac = buffers.get("flac");
    strict_1.default.ok(flac);
    strict_1.default.equal((0, audio_duration_1.sniffAudioContainer)(flac), "flac");
    // Un navigateur qui déclare un mauvais type ne doit pas fausser la durée.
    const seconds = (0, audio_duration_1.estimateAudioDurationSeconds)(flac, "audio/wav");
    strict_1.default.ok(seconds !== null);
    strict_1.default.ok(Math.abs(seconds - REFERENCE_SECONDS) <= TOLERANCE_SECONDS);
});
(0, node_test_1.default)("containerFromContentType couvre les types déclarés par la Micro IA", () => {
    strict_1.default.equal((0, audio_duration_1.containerFromContentType)("audio/x-wav"), "wav");
    strict_1.default.equal((0, audio_duration_1.containerFromContentType)("audio/vnd.wave"), "wav");
    strict_1.default.equal((0, audio_duration_1.containerFromContentType)("audio/x-m4a"), "mp4");
    strict_1.default.equal((0, audio_duration_1.containerFromContentType)("audio/aac"), "mp4");
    strict_1.default.equal((0, audio_duration_1.containerFromContentType)("audio/mp3"), "mp3");
    strict_1.default.equal((0, audio_duration_1.containerFromContentType)("video/webm"), "webm");
    strict_1.default.equal((0, audio_duration_1.containerFromContentType)("audio/ogg"), "ogg");
    strict_1.default.equal((0, audio_duration_1.containerFromContentType)("audio/flac"), "flac");
    strict_1.default.equal((0, audio_duration_1.containerFromContentType)("application/pdf"), null);
});
(0, node_test_1.default)("un contenu illisible ne produit jamais de durée inventée", () => {
    strict_1.default.equal((0, audio_duration_1.estimateAudioDurationSeconds)(Buffer.alloc(0), "audio/wav"), null);
    strict_1.default.equal((0, audio_duration_1.estimateAudioDurationSeconds)(Buffer.from("pas un fichier audio"), "audio/mpeg"), null);
    // Entête WAV tronqué : aucun chunk `data` exploitable.
    const truncated = Buffer.concat([
        Buffer.from("RIFF"),
        Buffer.alloc(4),
        Buffer.from("WAVE"),
    ]);
    strict_1.default.equal((0, audio_duration_1.estimateAudioDurationSeconds)(truncated, "audio/wav"), null);
});
//# sourceMappingURL=audio_duration.test.js.map