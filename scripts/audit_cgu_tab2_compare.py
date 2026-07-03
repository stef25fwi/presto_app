from pathlib import Path
import re, unicodedata, os
from datetime import datetime
RAW = Path(os.environ["CGU_RAW_FILE"])
REPORT = Path(os.environ["REPORT_FILE"])
CHECKS = [
    ("Objet de l’application", ["objet de l'application", "objet de l’application", "application permet", "plateforme", "service", "annonces", "mise en relation"]),
    ("Rôle de la plateforme : mise en relation / publication d’annonces", ["mise en relation", "publication d'annonces", "publication d’annonces", "publier des annonces", "consulter des annonces", "plateforme d'annonces"]),
    ("ilipresto n’est pas employeur", ["n'est pas employeur", "n’est pas employeur", "aucun contrat de travail", "ne constitue pas un employeur", "employeur"]),
    ("ilipresto n’est pas mandataire de paiement entre particuliers", ["mandataire de paiement", "intermédiaire de paiement", "intermediaire de paiement", "ne gère pas les paiements", "paiement directement", "paiements entre utilisateurs"]),
    ("Chaque utilisateur reste responsable de ses prestations", ["responsable de ses prestations", "chaque utilisateur reste responsable", "utilisateur reste responsable", "sous sa responsabilité", "obligations fiscales", "obligations sociales"]),
    ("Conditions d’inscription", ["conditions d'inscription", "conditions d’inscription", "inscription", "création de compte", "creer un compte", "créer un compte"]),
    ("Âge minimum", ["âge minimum", "age minimum", "18 ans", "majeur", "mineur"]),
    ("Compte personnel", ["compte personnel", "particulier", "compte particulier"]),
    ("Compte professionnel", ["compte professionnel", "compte pro", "professionnel", "siret", "entreprise"]),
    ("Compte vérifié par téléphone", ["compte vérifié", "compte verifie", "téléphone vérifié", "telephone verifie", "vérification téléphone", "verification telephone"]),
    ("Règles de publication", ["règles de publication", "regles de publication", "publier une annonce", "annonce doit", "contenu de l'annonce", "contenu de l’annonce"]),
    ("Annonces interdites", ["annonces interdites", "annonce interdite", "contenus interdits", "publication interdite"]),
    ("Produits ou services interdits", ["produits interdits", "services interdits", "armes", "drogues", "stupéfiants", "contrefaçon", "illicite", "illégal"]),
    ("Modération possible", ["modération", "moderation", "se réserve le droit", "se reserve le droit", "retirer", "masquer", "refuser"]),
    ("Suspension de compte", ["suspension de compte", "suspendre le compte", "compte suspendu", "désactiver le compte", "desactiver le compte"]),
    ("Suppression de contenu", ["suppression de contenu", "supprimer un contenu", "supprimer une annonce", "retirer une annonce", "contenu supprimé"]),
    ("Signalement", ["signalement", "signaler", "procédure de signalement", "procedure de signalement"]),
    ("Blocage utilisateur", ["blocage utilisateur", "bloquer un utilisateur", "utilisateur bloqué", "utilisateur bloque"]),
    ("Messagerie interne", ["messagerie interne", "messages", "conversation", "échanges entre utilisateurs", "echanges entre utilisateurs"]),
    ("Notifications", ["notifications", "notification push", "alertes"]),
    ("Responsabilité en cas de litige entre utilisateurs", ["litige entre utilisateurs", "en cas de litige", "différend entre utilisateurs", "differend entre utilisateurs"]),
    ("Limites de responsabilité de la plateforme", ["limites de responsabilité", "limitation de responsabilité", "responsabilité de la plateforme", "ne saurait être tenue responsable", "ne saurait etre tenue responsable"]),
    ("Droit applicable", ["droit applicable", "droit français", "droit francais", "loi française"]),
    ("Tribunal compétent si applicable", ["tribunal compétent", "tribunal competent", "tribunaux compétents", "juridiction compétente", "juridictions compétentes"]),
    ("Modification des CGU", ["modification des cgu", "modifier les cgu", "mise à jour des cgu", "mise a jour des cgu", "évolution des conditions"]),
]
def norm(s):
    s = s.lower()
    s = unicodedata.normalize("NFD", s)
    return "".join(c for c in s if unicodedata.category(c) != "Mn")
raw = RAW.read_text(encoding="utf-8", errors="ignore")
lines = raw.splitlines()
def find_proofs(keywords):
    proofs = []
    for line in lines:
        nline = norm(line)
        for kw in keywords:
            if norm(kw) in nline:
                proofs.append(line.strip()[:240])
                break
        if len(proofs) >= 5:
            break
    return proofs
ok = partial = missing = 0
rows = []
for point, keywords in CHECKS:
    proofs = find_proofs(keywords)
    if len(proofs) >= 2:
        status = "✅ OK probable"
        ok += 1
    elif len(proofs) == 1:
        status = "🟡 Partiel / à vérifier"
        partial += 1
    else:
        status = "❌ Manquant probable"
        missing += 1
    rows.append((point, status, proofs))
REPORT.parent.mkdir(parents=True, exist_ok=True)
with REPORT.open("w", encoding="utf-8") as f:
    f.write("# Audit ciblé CGU — onglet case 2\n\n")
    f.write(f"Date UTC : {datetime.utcnow().isoformat(timespec='seconds')}Z\n\n")
    f.write(f"Extraction analysée : `{RAW}`\n\n")
    f.write("## Résumé\n\n")
    f.write(f"- ✅ OK probable : {ok}\n")
    f.write(f"- 🟡 Partiel / à vérifier : {partial}\n")
    f.write(f"- ❌ Manquant probable : {missing}\n\n")
    f.write("## Comparatif point par point\n\n")
    f.write("| Point CGU | Statut | Preuves trouvées |\n")
    f.write("|---|---:|---|\n")
    for point, status, proofs in rows:
        proof_txt = "<br>".join(p.replace("|", "/") for p in proofs) if proofs else "Aucune preuve trouvée dans le bloc CGU extrait"
        f.write(f"| {point} | {status} | {proof_txt} |\n")
    f.write("\n## Points à corriger en priorité\n\n")
    for point, status, proofs in rows:
        if "❌" in status or "🟡" in status:
            f.write(f"- {status} — **{point}**\n")
print("==================================================")
print(" RÉSULTAT AUDIT CIBLÉ CGU")
print("==================================================")
print(f"✅ OK probable        : {ok}")
print(f"🟡 Partiel / vérifier : {partial}")
print(f"❌ Manquant probable  : {missing}")
print("")
print(f"Rapport : {REPORT}")
print("")
print("À compléter en priorité :")
for point, status, proofs in rows:
    if "❌" in status or "🟡" in status:
        print(f"- {status} {point}")
