from pathlib import Path
import re
import unicodedata
from datetime import datetime

ROOT = Path(".")
OUT = Path(__import__("os").environ.get("REPORT_FILE", "docs/audit_cgu_checklist.md"))

SEARCH_DIRS = ["lib", "docs", "web"]
EXTS = {".dart", ".md", ".txt", ".html", ".json", ".yaml", ".yml"}

CHECKS = [
    {
        "point": "Objet de l’application",
        "patterns": [r"objet de l.?application", r"l.?application .* permet", r"service .* mise en relation", r"plateforme .* annonces"],
        "need": "Décrire clairement à quoi sert ilipresto."
    },
    {
        "point": "Rôle de la plateforme : mise en relation / publication d’annonces",
        "patterns": [r"mise en relation", r"publication d.?annonces", r"publier des annonces", r"consulter des annonces"],
        "need": "Dire que la plateforme permet de publier/consulter des annonces et de mettre en relation les utilisateurs."
    },
    {
        "point": "ilipresto n’est pas employeur",
        "patterns": [r"n.?est pas employeur", r"aucun contrat de travail", r"ne constitue pas un employeur"],
        "need": "Préciser explicitement qu’ilipresto n’est pas employeur des utilisateurs/prestataires."
    },
    {
        "point": "ilipresto n’est pas mandataire de paiement entre particuliers",
        "patterns": [r"n.?est pas mandataire de paiement", r"ne gere pas les paiements", r"pas intermediaire de paiement", r"paiement .* directement .* utilisateurs"],
        "need": "Dire qu’ilipresto n’agit pas comme mandataire ou intermédiaire de paiement entre particuliers."
    },
    {
        "point": "Chaque utilisateur reste responsable de ses prestations",
        "patterns": [r"utilisateur .* responsable", r"responsable de ses prestations", r"chaque utilisateur reste responsable", r"prestations .* sous sa responsabilite"],
        "need": "Indiquer que l’utilisateur est seul responsable de ses annonces, prestations, déclarations et obligations."
    },
    {
        "point": "Conditions d’inscription",
        "patterns": [r"conditions d.?inscription", r"inscription", r"creation de compte", r"créer un compte"],
        "need": "Décrire les conditions pour créer/utiliser un compte."
    },
    {
        "point": "Âge minimum",
        "patterns": [r"age minimum", r"âge minimum", r"mineur", r"18 ans", r"majeur"],
        "need": "Préciser l’âge minimum ou l’obligation d’être majeur/autorisé."
    },
    {
        "point": "Compte personnel",
        "patterns": [r"compte personnel", r"particulier", r"utilisateur particulier"],
        "need": "Définir l’usage d’un compte personnel/particulier."
    },
    {
        "point": "Compte professionnel",
        "patterns": [r"compte professionnel", r"compte pro", r"professionnel", r"siret", r"entreprise"],
        "need": "Définir l’usage d’un compte professionnel et les obligations pro éventuelles."
    },
    {
        "point": "Compte vérifié par téléphone",
        "patterns": [r"compte verifie", r"compte vérifié", r"telephone verifie", r"téléphone vérifié", r"verification .* telephone", r"vérification .* téléphone"],
        "need": "Expliquer ce que signifie un compte vérifié par téléphone et ses limites."
    },
    {
        "point": "Règles de publication",
        "patterns": [r"regles de publication", r"règles de publication", r"publier une annonce", r"contenu de l.?annonce", r"annonce doit"],
        "need": "Lister les règles de rédaction et de publication d’une annonce."
    },
    {
        "point": "Annonces interdites",
        "patterns": [r"annonces interdites", r"annonce interdite", r"contenus interdits", r"publication interdite"],
        "need": "Lister les catégories d’annonces interdites."
    },
    {
        "point": "Produits ou services interdits",
        "patterns": [r"produits .* interdits", r"services .* interdits", r"armes", r"drogues", r"contrefacon", r"illégal", r"illicite"],
        "need": "Interdire les produits/services illégaux, dangereux, réglementés ou contraires aux règles."
    },
    {
        "point": "Modération possible",
        "patterns": [r"moderation", r"modération", r"controler .* contenu", r"verifier .* annonce", r"se reserve le droit"],
        "need": "Dire que la plateforme peut contrôler/modérer certains contenus."
    },
    {
        "point": "Suspension de compte",
        "patterns": [r"suspension de compte", r"suspendre .* compte", r"compte .* suspendu"],
        "need": "Prévoir les cas de suspension temporaire ou définitive."
    },
    {
        "point": "Suppression de contenu",
        "patterns": [r"suppression de contenu", r"supprimer .* contenu", r"retirer .* annonce", r"suppression .* annonce"],
        "need": "Prévoir la suppression/retrait d’annonces ou messages non conformes."
    },
    {
        "point": "Signalement",
        "patterns": [r"signalement", r"signaler", r"procedure de signalement", r"procédure de signalement"],
        "need": "Expliquer comment signaler une annonce, un message ou un utilisateur."
    },
    {
        "point": "Blocage utilisateur",
        "patterns": [r"blocage utilisateur", r"bloquer .* utilisateur", r"utilisateur bloque", r"utilisateur bloqué"],
        "need": "Prévoir la possibilité de bloquer un utilisateur."
    },
    {
        "point": "Messagerie interne",
        "patterns": [r"messagerie interne", r"messages", r"conversation", r"echanges entre utilisateurs", r"échanges entre utilisateurs"],
        "need": "Expliquer l’usage de la messagerie interne."
    },
    {
        "point": "Notifications",
        "patterns": [r"notifications", r"notification push", r"alertes", r"messages .* notification"],
        "need": "Expliquer que l’utilisateur peut recevoir des notifications liées au service."
    },
    {
        "point": "Responsabilité en cas de litige entre utilisateurs",
        "patterns": [r"litige entre utilisateurs", r"en cas de litige", r"differend entre utilisateurs", r"différend entre utilisateurs"],
        "need": "Dire que les litiges liés aux prestations se règlent entre utilisateurs."
    },
    {
        "point": "Limites de responsabilité de la plateforme",
        "patterns": [r"limites de responsabilite", r"limitation de responsabilite", r"responsabilite de la plateforme", r"ne saurait etre tenue responsable"],
        "need": "Limiter la responsabilité d’ilipresto pour les contenus, prestations, paiements, litiges et disponibilité."
    },
    {
        "point": "Droit applicable",
        "patterns": [r"droit applicable", r"droit francais", r"droit français", r"loi française"],
        "need": "Indiquer le droit applicable aux CGU."
    },
    {
        "point": "Tribunal compétent si applicable",
        "patterns": [r"tribunal competent", r"tribunaux competents", r"juridiction competente", r"juridictions compétentes"],
        "need": "Ajouter la clause de compétence si elle est adaptée juridiquement."
    },
    {
        "point": "Modification des CGU",
        "patterns": [r"modification des cgu", r"modifier les cgu", r"mise a jour des cgu", r"mise à jour des cgu", r"evolution des conditions"],
        "need": "Prévoir que les CGU peuvent être modifiées et comment l’utilisateur est informé."
    },
]

def normalize(s: str) -> str:
    s = s.lower()
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return s

def iter_files():
    for d in SEARCH_DIRS:
        p = ROOT / d
        if not p.exists():
            continue
        for f in p.rglob("*"):
            if f.is_file() and f.suffix.lower() in EXTS:
                if "build" in f.parts:
                    continue
                yield f

files = list(iter_files())

all_text = []
file_texts = {}
for f in files:
    try:
        txt = f.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        continue
    if re.search(r"CGU|Conditions|conditions|legal|mentions|confidential|utilisation|annonce|messagerie|notification", txt, re.I):
        file_texts[f] = txt
        all_text.append(f"\n\n===== FILE: {f} =====\n{txt}")

corpus = normalize("\n".join(all_text))

def find_matches(patterns):
    results = []
    for f, txt in file_texts.items():
        lines = txt.splitlines()
        for i, line in enumerate(lines, start=1):
            nline = normalize(line)
            for pat in patterns:
                if re.search(pat, nline, re.I):
                    results.append((str(f), i, line.strip()[:220]))
                    break
    return results

rows = []
ok = partial = missing = 0

for check in CHECKS:
    matches = find_matches(check["patterns"])
    if len(matches) >= 2:
        status = "✅ OK probable"
        ok += 1
    elif len(matches) == 1:
        status = "🟡 À vérifier / partiel"
        partial += 1
    else:
        status = "❌ Manquant probable"
        missing += 1

    rows.append({
        "point": check["point"],
        "status": status,
        "matches": matches[:5],
        "need": check["need"],
    })

OUT.parent.mkdir(parents=True, exist_ok=True)

with OUT.open("w", encoding="utf-8") as md:
    md.write("# Audit CGU — ilipresto\n\n")
    md.write(f"Date UTC : {datetime.utcnow().isoformat(timespec='seconds')}Z\n\n")

    md.write("## Résumé\n\n")
    md.write(f"- ✅ OK probable : {ok}\n")
    md.write(f"- 🟡 À vérifier / partiel : {partial}\n")
    md.write(f"- ❌ Manquant probable : {missing}\n\n")

    md.write("## Fichiers analysés contenant du contenu légal / CGU probable\n\n")
    for f in sorted(file_texts):
        md.write(f"- `{f}`\n")
    md.write("\n")

    md.write("## Comparaison point par point\n\n")
    md.write("| Point CGU | Statut | Preuves trouvées | Action recommandée |\n")
    md.write("|---|---:|---|---|\n")

    for r in rows:
        if r["matches"]:
            proof = "<br>".join([f"`{f}:{line}` — {snippet.replace('|','/')}" for f, line, snippet in r["matches"]])
        else:
            proof = "Aucune preuve trouvée automatiquement"
        md.write(f"| {r['point']} | {r['status']} | {proof} | {r['need']} |\n")

    md.write("\n## Blocs à compléter en priorité\n\n")
    for r in rows:
        if "❌" in r["status"] or "🟡" in r["status"]:
            md.write(f"- {r['status']} **{r['point']}** : {r['need']}\n")

    md.write("\n## Commandes utiles après correction\n\n")
    md.write("```bash\n")
    md.write("flutter analyze --no-fatal-infos\n")
    md.write("flutter build web --release --no-wasm-dry-run\n")
    md.write("```\n")

print("==================================================")
print(" RESULTAT AUDIT CGU")
print("==================================================")
print(f"✅ OK probable        : {ok}")
print(f"🟡 À vérifier/partiel : {partial}")
print(f"❌ Manquant probable  : {missing}")
print("")
print(f"Rapport généré : {OUT}")
print("")
print("Points à compléter en priorité :")
for r in rows:
    if "❌" in r["status"] or "🟡" in r["status"]:
        print(f"- {r['status']} {r['point']}")

