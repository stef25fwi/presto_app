"use strict";
/**
 * Estimation de la durée audio sans dépendance native.
 *
 * La Micro IA accepte wav, mp3, ogg, webm, flac et mp4/m4a. La durée sert au
 * calcul de coût, aux métriques de latence par seconde d'audio et aux gardes
 * de volumétrie : elle doit donc être disponible pour tous ces conteneurs et
 * pas seulement pour le WAV.
 *
 * Chaque analyseur retourne `null` lorsque l'entête est absent, tronqué ou
 * non exploitable. Aucune valeur approximative n'est inventée : une durée
 * absente reste `null` afin que les métriques ne soient jamais faussées.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.sniffAudioContainer = sniffAudioContainer;
exports.containerFromContentType = containerFromContentType;
exports.estimateWavDuration = estimateWavDuration;
exports.estimateFlacDuration = estimateFlacDuration;
exports.estimateOggDuration = estimateOggDuration;
exports.estimateMp4Duration = estimateMp4Duration;
exports.estimateMp3Duration = estimateMp3Duration;
exports.estimateWebmDuration = estimateWebmDuration;
exports.estimateAudioDurationSeconds = estimateAudioDurationSeconds;
const MAX_MP3_FRAMES = 500_000;
/**
 * Accès octet borné : les analyseurs vérifient déjà leurs longueurs, mais
 * `noUncheckedIndexedAccess` impose une lecture explicitement sûre.
 */
function byteAt(buffer, offset) {
    return offset >= 0 && offset < buffer.length ? buffer.readUInt8(offset) : 0;
}
function readUInt24BE(buffer, offset) {
    if (offset + 3 > buffer.length)
        return null;
    return ((byteAt(buffer, offset) << 16) |
        (byteAt(buffer, offset + 1) << 8) |
        byteAt(buffer, offset + 2));
}
function round(seconds) {
    if (!Number.isFinite(seconds) || seconds <= 0)
        return null;
    return Number(seconds.toFixed(2));
}
/** Reconnaît le conteneur à partir des octets réels, pas du type déclaré. */
function sniffAudioContainer(buffer) {
    if (buffer.length < 12)
        return null;
    if (buffer.toString("ascii", 0, 4) === "RIFF" &&
        buffer.toString("ascii", 8, 12) === "WAVE") {
        return "wav";
    }
    if (buffer.toString("ascii", 0, 4) === "fLaC")
        return "flac";
    if (buffer.toString("ascii", 0, 4) === "OggS")
        return "ogg";
    if (byteAt(buffer, 0) === 0x1a &&
        byteAt(buffer, 1) === 0x45 &&
        byteAt(buffer, 2) === 0xdf &&
        byteAt(buffer, 3) === 0xa3) {
        return "webm";
    }
    if (buffer.toString("ascii", 4, 8) === "ftyp")
        return "mp4";
    if (buffer.toString("ascii", 0, 3) === "ID3")
        return "mp3";
    if (byteAt(buffer, 0) === 0xff && (byteAt(buffer, 1) & 0xe0) === 0xe0)
        return "mp3";
    return null;
}
/** Déduit le conteneur du content-type lorsque les octets ne suffisent pas. */
function containerFromContentType(contentType) {
    const value = (contentType || "").toLowerCase();
    if (value.includes("wav") || value.includes("wave"))
        return "wav";
    if (value.includes("flac"))
        return "flac";
    if (value.includes("ogg") || value.includes("opus"))
        return "ogg";
    if (value.includes("webm") || value.includes("matroska"))
        return "webm";
    if (value.includes("mp4") || value.includes("m4a") || value.includes("aac")) {
        return "mp4";
    }
    if (value.includes("mpeg") || value.includes("mp3"))
        return "mp3";
    return null;
}
function estimateWavDuration(buffer) {
    if (buffer.length < 12 || buffer.toString("ascii", 0, 4) !== "RIFF")
        return null;
    let byteRate = 0;
    let offset = 12;
    while (offset + 8 <= buffer.length) {
        const id = buffer.toString("ascii", offset, offset + 4);
        const size = buffer.readUInt32LE(offset + 4);
        const body = offset + 8;
        if (id === "fmt " && body + 16 <= buffer.length) {
            byteRate = buffer.readUInt32LE(body + 8);
        }
        if (id === "data") {
            if (!byteRate)
                return null;
            const available = Math.min(size, Math.max(0, buffer.length - body));
            return round(available / byteRate);
        }
        offset = body + size + (size % 2);
    }
    return null;
}
function estimateFlacDuration(buffer) {
    if (buffer.toString("ascii", 0, 4) !== "fLaC")
        return null;
    let offset = 4;
    while (offset + 4 <= buffer.length) {
        const header = byteAt(buffer, offset);
        const isLast = (header & 0x80) !== 0;
        const type = header & 0x7f;
        const length = readUInt24BE(buffer, offset + 1);
        if (length === null)
            return null;
        const body = offset + 4;
        if (type === 0) {
            if (body + 18 > buffer.length)
                return null;
            const sampleRate = (byteAt(buffer, body + 10) << 12) |
                (byteAt(buffer, body + 11) << 4) |
                (byteAt(buffer, body + 12) >> 4);
            // 36 bits : 4 bits de poids fort puis 4 octets.
            const totalSamples = (byteAt(buffer, body + 13) & 0x0f) * 2 ** 32 + buffer.readUInt32BE(body + 14);
            if (!sampleRate || !totalSamples)
                return null;
            return round(totalSamples / sampleRate);
        }
        if (isLast)
            return null;
        offset = body + length;
    }
    return null;
}
function readOggPage(buffer, offset) {
    if (offset + 27 > buffer.length)
        return null;
    if (buffer.toString("ascii", offset, offset + 4) !== "OggS")
        return null;
    const granuleLow = buffer.readUInt32LE(offset + 6);
    const granuleHigh = buffer.readUInt32LE(offset + 10);
    const segmentCount = byteAt(buffer, offset + 26);
    const tableStart = offset + 27;
    if (tableStart + segmentCount > buffer.length)
        return null;
    let payloadLength = 0;
    for (let index = 0; index < segmentCount; index += 1) {
        payloadLength += byteAt(buffer, tableStart + index);
    }
    return {
        granulePosition: granuleHigh * 2 ** 32 + granuleLow,
        serial: buffer.readUInt32LE(offset + 14),
        payloadStart: tableStart + segmentCount,
        payloadLength,
    };
}
function estimateOggDuration(buffer) {
    const first = readOggPage(buffer, 0);
    if (!first)
        return null;
    const payload = buffer.subarray(first.payloadStart, first.payloadStart + first.payloadLength);
    let sampleRate = 0;
    let preSkip = 0;
    if (payload.length >= 19 && payload.toString("ascii", 0, 8) === "OpusHead") {
        // Les positions granulaires Opus sont toujours exprimées à 48 kHz.
        sampleRate = 48_000;
        preSkip = payload.readUInt16LE(10);
    }
    else if (payload.length >= 16 &&
        byteAt(payload, 0) === 0x01 &&
        payload.toString("ascii", 1, 7) === "vorbis") {
        sampleRate = payload.readUInt32LE(12);
    }
    else {
        return null;
    }
    if (!sampleRate)
        return null;
    const lastPageOffset = buffer.lastIndexOf("OggS", buffer.length, "ascii");
    if (lastPageOffset < 0)
        return null;
    const last = readOggPage(buffer, lastPageOffset);
    if (!last || last.serial !== first.serial)
        return null;
    const samples = last.granulePosition - preSkip;
    return round(samples / sampleRate);
}
function estimateMp4Duration(buffer) {
    const mvhd = findMp4Atom(buffer, 0, buffer.length, ["moov", "mvhd"]);
    if (!mvhd)
        return null;
    const { start, end } = mvhd;
    if (start + 4 > end)
        return null;
    const version = byteAt(buffer, start);
    if (version === 1) {
        if (start + 32 > end)
            return null;
        const timescale = buffer.readUInt32BE(start + 20);
        const durationHigh = buffer.readUInt32BE(start + 24);
        const durationLow = buffer.readUInt32BE(start + 28);
        const duration = durationHigh * 2 ** 32 + durationLow;
        if (!timescale)
            return null;
        return round(duration / timescale);
    }
    if (start + 20 > end)
        return null;
    const timescale = buffer.readUInt32BE(start + 12);
    const duration = buffer.readUInt32BE(start + 16);
    if (!timescale)
        return null;
    return round(duration / timescale);
}
function findMp4Atom(buffer, from, to, pathNames) {
    const [wanted, ...rest] = pathNames;
    let offset = from;
    while (offset + 8 <= to) {
        let size = buffer.readUInt32BE(offset);
        const name = buffer.toString("ascii", offset + 4, offset + 8);
        let headerSize = 8;
        if (size === 1) {
            if (offset + 16 > to)
                return null;
            const high = buffer.readUInt32BE(offset + 8);
            const low = buffer.readUInt32BE(offset + 12);
            size = high * 2 ** 32 + low;
            headerSize = 16;
        }
        else if (size === 0) {
            size = to - offset;
        }
        if (size < headerSize)
            return null;
        const bodyStart = offset + headerSize;
        const bodyEnd = Math.min(to, offset + size);
        if (name === wanted) {
            if (rest.length === 0)
                return { start: bodyStart, end: bodyEnd };
            return findMp4Atom(buffer, bodyStart, bodyEnd, rest);
        }
        offset += size;
    }
    return null;
}
const MP3_BITRATES_V1_L3 = [
    0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0,
];
const MP3_BITRATES_V2_L3 = [
    0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0,
];
const MP3_SAMPLE_RATES = [44_100, 48_000, 32_000, 0];
function parseMp3Frame(buffer, offset) {
    if (offset + 4 > buffer.length)
        return null;
    if (byteAt(buffer, offset) !== 0xff)
        return null;
    if ((byteAt(buffer, offset + 1) & 0xe0) !== 0xe0)
        return null;
    const versionBits = (byteAt(buffer, offset + 1) >> 3) & 0x03;
    const layerBits = (byteAt(buffer, offset + 1) >> 1) & 0x03;
    if (versionBits === 1 || layerBits !== 0x01)
        return null; // réservé ou hors Layer III
    const bitrateIndex = (byteAt(buffer, offset + 2) >> 4) & 0x0f;
    const sampleRateIndex = (byteAt(buffer, offset + 2) >> 2) & 0x03;
    const padding = (byteAt(buffer, offset + 2) >> 1) & 0x01;
    const channelMode = (byteAt(buffer, offset + 3) >> 6) & 0x03;
    if (bitrateIndex === 0 || bitrateIndex === 0x0f)
        return null;
    if (sampleRateIndex === 3)
        return null;
    const mpegVersion = versionBits === 3 ? 1 : 2;
    const sampleRateDivider = versionBits === 3 ? 1 : versionBits === 2 ? 2 : 4;
    const sampleRate = (MP3_SAMPLE_RATES[sampleRateIndex] ?? 0) / sampleRateDivider;
    const bitrate = ((mpegVersion === 1
        ? MP3_BITRATES_V1_L3[bitrateIndex]
        : MP3_BITRATES_V2_L3[bitrateIndex]) ?? 0) * 1_000;
    if (!sampleRate || !bitrate)
        return null;
    const samplesPerFrame = mpegVersion === 1 ? 1_152 : 576;
    const frameLength = Math.floor((samplesPerFrame / 8) * (bitrate / sampleRate)) + padding;
    if (frameLength <= 4)
        return null;
    return {
        frameLength,
        sampleRate,
        samplesPerFrame,
        mono: channelMode === 3,
        mpegVersion,
    };
}
function skipId3(buffer) {
    if (buffer.length < 10 || buffer.toString("ascii", 0, 3) !== "ID3")
        return 0;
    const size = ((byteAt(buffer, 6) & 0x7f) << 21) |
        ((byteAt(buffer, 7) & 0x7f) << 14) |
        ((byteAt(buffer, 8) & 0x7f) << 7) |
        (byteAt(buffer, 9) & 0x7f);
    return Math.min(buffer.length, 10 + size);
}
function findFirstMp3Frame(buffer, from) {
    const limit = Math.min(buffer.length - 4, from + 200_000);
    for (let offset = from; offset <= limit; offset += 1) {
        if (parseMp3Frame(buffer, offset))
            return offset;
    }
    return -1;
}
function readMp3VbrFrameCount(buffer, frameStart, frame) {
    const sideInfoSize = frame.mpegVersion === 1 ? (frame.mono ? 17 : 32) : frame.mono ? 9 : 17;
    const tagOffset = frameStart + 4 + sideInfoSize;
    if (tagOffset + 12 <= buffer.length) {
        const tag = buffer.toString("ascii", tagOffset, tagOffset + 4);
        if (tag === "Xing" || tag === "Info") {
            const flags = buffer.readUInt32BE(tagOffset + 4);
            if ((flags & 0x01) !== 0 && tagOffset + 12 <= buffer.length) {
                const frames = buffer.readUInt32BE(tagOffset + 8);
                return frames > 0 ? frames : null;
            }
            return null;
        }
    }
    const vbriOffset = frameStart + 4 + 32;
    if (vbriOffset + 18 <= buffer.length &&
        buffer.toString("ascii", vbriOffset, vbriOffset + 4) === "VBRI") {
        const frames = buffer.readUInt32BE(vbriOffset + 14);
        return frames > 0 ? frames : null;
    }
    return null;
}
function estimateMp3Duration(buffer) {
    const start = findFirstMp3Frame(buffer, skipId3(buffer));
    if (start < 0)
        return null;
    const first = parseMp3Frame(buffer, start);
    if (!first)
        return null;
    const vbrFrames = readMp3VbrFrameCount(buffer, start, first);
    if (vbrFrames) {
        return round((vbrFrames * first.samplesPerFrame) / first.sampleRate);
    }
    let offset = start;
    let samples = 0;
    let frames = 0;
    while (offset + 4 <= buffer.length && frames < MAX_MP3_FRAMES) {
        const frame = parseMp3Frame(buffer, offset);
        if (!frame) {
            const next = findFirstMp3Frame(buffer, offset + 1);
            if (next < 0)
                break;
            offset = next;
            continue;
        }
        samples += frame.samplesPerFrame / frame.sampleRate;
        frames += 1;
        offset += frame.frameLength;
    }
    return frames ? round(samples) : null;
}
function readVint(buffer, offset, stripMarker) {
    if (offset < 0 || offset >= buffer.length)
        return null;
    const first = byteAt(buffer, offset);
    if (first === 0)
        return null;
    let length = 1;
    let mask = 0x80;
    while (length <= 8 && (first & mask) === 0) {
        mask >>= 1;
        length += 1;
    }
    if (length > 8 || offset + length > buffer.length)
        return null;
    let value = stripMarker ? first & (mask - 1) : first;
    let unknown = stripMarker ? (first & (mask - 1)) === mask - 1 : false;
    for (let index = 1; index < length; index += 1) {
        const byte = byteAt(buffer, offset + index);
        value = value * 256 + byte;
        if (byte !== 0xff)
            unknown = false;
    }
    return { value, length, unknown };
}
const EBML_SEGMENT = 0x18538067;
const EBML_INFO = 0x1549a966;
const EBML_TIMECODE_SCALE = 0x2ad7b1;
const EBML_DURATION = 0x4489;
function findEbmlChild(buffer, from, to, wantedId) {
    let offset = from;
    while (offset < to) {
        const id = readVint(buffer, offset, false);
        if (!id)
            return null;
        const size = readVint(buffer, offset + id.length, true);
        if (!size)
            return null;
        const bodyStart = offset + id.length + size.length;
        const bodyEnd = size.unknown ? to : Math.min(to, bodyStart + size.value);
        if (id.value === wantedId)
            return { start: bodyStart, end: bodyEnd };
        if (bodyEnd <= offset)
            return null;
        offset = bodyEnd;
    }
    return null;
}
function estimateWebmDuration(buffer) {
    const segment = findEbmlChild(buffer, 0, buffer.length, EBML_SEGMENT);
    if (!segment)
        return null;
    const info = findEbmlChild(buffer, segment.start, segment.end, EBML_INFO);
    if (!info)
        return null;
    const scaleElement = findEbmlChild(buffer, info.start, info.end, EBML_TIMECODE_SCALE);
    let timecodeScale = 1_000_000;
    if (scaleElement) {
        let scale = 0;
        for (let offset = scaleElement.start; offset < scaleElement.end; offset += 1) {
            scale = scale * 256 + byteAt(buffer, offset);
        }
        if (scale > 0)
            timecodeScale = scale;
    }
    const durationElement = findEbmlChild(buffer, info.start, info.end, EBML_DURATION);
    if (!durationElement)
        return null;
    const width = durationElement.end - durationElement.start;
    let duration;
    if (width === 4)
        duration = buffer.readFloatBE(durationElement.start);
    else if (width === 8)
        duration = buffer.readDoubleBE(durationElement.start);
    else
        return null;
    return round((duration * timecodeScale) / 1_000_000_000);
}
/**
 * Durée en secondes ou `null` si le conteneur ne l'expose pas.
 *
 * Les enregistrements WebM produits en flux par `MediaRecorder` n'ont pas
 * toujours d'élément `Duration` : dans ce cas la fonction retourne `null`
 * plutôt qu'une estimation trompeuse.
 */
function estimateAudioDurationSeconds(buffer, contentType) {
    if (!Buffer.isBuffer(buffer) || buffer.length === 0)
        return null;
    const container = sniffAudioContainer(buffer) || containerFromContentType(contentType);
    try {
        switch (container) {
            case "wav":
                return estimateWavDuration(buffer);
            case "flac":
                return estimateFlacDuration(buffer);
            case "ogg":
                return estimateOggDuration(buffer);
            case "mp4":
                return estimateMp4Duration(buffer);
            case "webm":
                return estimateWebmDuration(buffer);
            case "mp3":
                return estimateMp3Duration(buffer);
            default:
                return null;
        }
    }
    catch {
        return null;
    }
}
//# sourceMappingURL=audio_duration.js.map