"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ANTILLES_TRANSCRIPTION_CONTEXT = exports.CITY_POSTAL_MAP = exports.LISTING_TAXONOMY_VERSION = exports.LISTING_CATEGORY_VALUES = void 0;
exports.normalizeSearchKey = normalizeSearchKey;
exports.normalizeListingCategory = normalizeListingCategory;
exports.findPostalCode = findPostalCode;
exports.departmentFromPostalCode = departmentFromPostalCode;
exports.correctAntillesTranscript = correctAntillesTranscript;
exports.LISTING_CATEGORY_VALUES = [
    "Jardinage",
    "Bricolage / Travaux",
    "Aide à domicile",
    "Restauration / Extra",
    "Événementiel / DJ",
    "Garde d'enfants",
    "Cours & soutien",
    "Peinture",
    "Main-d'œuvre",
    "Autre",
];
exports.LISTING_TAXONOMY_VERSION = "ilipresto-ai-taxonomy-v2";
const CATEGORY_ALIASES = {
    jardinage: "Jardinage",
    jardin: "Jardinage",
    bricolage: "Bricolage / Travaux",
    travaux: "Bricolage / Travaux",
    "aide a domicile": "Aide à domicile",
    "aide à domicile": "Aide à domicile",
    restauration: "Restauration / Extra",
    extra: "Restauration / Extra",
    evenementiel: "Événementiel / DJ",
    événementiel: "Événementiel / DJ",
    dj: "Événementiel / DJ",
    "garde d'enfants": "Garde d'enfants",
    "garde enfants": "Garde d'enfants",
    cours: "Cours & soutien",
    soutien: "Cours & soutien",
    peinture: "Peinture",
    "main-d'oeuvre": "Main-d'œuvre",
    "main-d’œuvre": "Main-d'œuvre",
    manutention: "Main-d'œuvre",
    autre: "Autre",
};
exports.CITY_POSTAL_MAP = {
    "baie-mahault": "97122",
    "les abymes": "97139",
    "pointe-a-pitre": "97110",
    "le gosier": "97190",
    "sainte-anne": "97180",
    "saint-francois": "97118",
    "petit-bourg": "97170",
    lamentin: "97129",
    "capesterre-belle-eau": "97130",
    "basse-terre": "97100",
    goyave: "97128",
    "morne-a-l'eau": "97111",
    "sainte-rose": "97115",
    "le moule": "97160",
    "saint-claude": "97120",
    bouillante: "97125",
    deshaies: "97126",
    "trois-rivieres": "97114",
    "vieux-habitants": "97119",
    "vieux-fort": "97141",
    "anse-bertrand": "97121",
    "port-louis": "97117",
    "petit-canal": "97131",
    "la desirade": "97127",
    "terre-de-bas": "97136",
    "terre-de-haut": "97137",
    "grand-bourg": "97112",
    "saint-louis": "97134",
    "capesterre-de-marie-galante": "97140",
    "fort-de-france": "97200",
    "le lamentin": "97232",
    schoelcher: "97233",
    "le robert": "97231",
    "le francois": "97240",
    "le marin": "97290",
    "les trois-ilets": "97229",
    "sainte-luce": "97228",
    "sainte-anne-martinique": "97227",
    "la trinite": "97220",
    "le lorrain": "97214",
    "le carbet": "97221",
    "le diamant": "97223",
    "saint-esprit": "97270",
};
exports.ANTILLES_TRANSCRIPTION_CONTEXT = [
    "iliprestō",
    "Guadeloupe",
    "Martinique",
    "Baie-Mahault",
    "Les Abymes",
    "Pointe-à-Pitre",
    "Petit-Bourg",
    "Le Gosier",
    "Saint-François",
    "Fort-de-France",
    "Le Lamentin",
    "Schoelcher",
    "jardinage",
    "bricolage",
    "peinture",
    "aide à domicile",
    "déménagement",
    "plomberie",
    "électricité",
    "manutention",
    "traiteur",
    "baby-sitting",
].join(", ");
function normalizeSearchKey(value) {
    return value
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[’]/g, "'")
        .replace(/\s+/g, " ")
        .trim();
}
function normalizeListingCategory(value) {
    if (typeof value !== "string")
        return null;
    const normalized = normalizeSearchKey(value);
    const exact = exports.LISTING_CATEGORY_VALUES.find((candidate) => normalizeSearchKey(candidate) === normalized);
    return exact || CATEGORY_ALIASES[normalized] || null;
}
function findPostalCode(city) {
    if (typeof city !== "string" || !city.trim())
        return null;
    const normalized = normalizeSearchKey(city);
    const direct = exports.CITY_POSTAL_MAP[normalized];
    if (direct)
        return direct;
    return exports.CITY_POSTAL_MAP[normalized.replace(/\s+/g, "-")] || null;
}
function departmentFromPostalCode(postalCode) {
    if (typeof postalCode !== "string" || !/^\d{5}$/.test(postalCode))
        return null;
    return postalCode.startsWith("97") || postalCode.startsWith("98")
        ? postalCode.slice(0, 3)
        : postalCode.slice(0, 2);
}
function correctAntillesTranscript(value) {
    if (typeof value !== "string")
        return "";
    let text = value.replace(/\s+/g, " ").trim();
    const corrections = {
        "baie ma haut": "Baie-Mahault",
        "baie mahaut": "Baie-Mahault",
        "bye mahaut": "Baie-Mahault",
        "les abîmes": "Les Abymes",
        "les zabîmes": "Les Abymes",
        "pointe à pitre": "Pointe-à-Pitre",
        "fort de france": "Fort-de-France",
        "petit bourg": "Petit-Bourg",
        "le gosier": "Le Gosier",
        "saint francois": "Saint-François",
    };
    for (const [source, replacement] of Object.entries(corrections)) {
        text = text.replace(new RegExp(source, "gi"), replacement);
    }
    return text;
}
//# sourceMappingURL=listing_taxonomy.js.map