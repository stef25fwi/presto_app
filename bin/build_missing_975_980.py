import csv, json, os, re
from collections import defaultdict

CSV_PATH="base-officielle-codes-postaux.csv"
OUT_DIR="assets/data/cities"
os.makedirs(OUT_DIR, exist_ok=True)

def dept_token_from_row(row):
    cp = (row.get("Code_postal") or row.get("code_postal") or "").strip()
    insee = (row.get("Code_commune_INSEE") or row.get("code_commune_insee") or "").strip()
    if not re.fullmatch(r"\d{5}", cp):
        return None
    # Corse: le code INSEE commence par 2A/2B -> on respecte ça (mieux que l'heuristique)
    if insee.startswith(("2A","2B")):
        return insee[:2]
    # DOM/COM/Monaco: on groupe par préfixe 3 chiffres (97x/98x/975/980/986/987/988…)
    if cp.startswith(("97","98")):
        return cp[:3]
    # Métropole
    return cp[:2]

wanted={"975","980"}  # tu peux ajouter {"986","987","988","984"} si tu veux

by=defaultdict(list)
with open(CSV_PATH, newline="", encoding="utf-8") as f:
    r=csv.DictReader(f)
    for row in r:
        name = (row.get("Nom_commune") or row.get("nom_commune") or "").strip()
        cp = (row.get("Code_postal") or row.get("code_postal") or "").strip()
        tok = dept_token_from_row(row)
        if not tok or tok not in wanted: 
            continue
        if not name: 
            continue
        by[tok].append({"name":name,"cp":cp,"dept":tok,"region":""})

for tok, rows in by.items():
    rows.sort(key=lambda x:(x["name"].lower(), x["cp"]))
    out=os.path.join(OUT_DIR, f"cities_{tok}.json")
    with open(out,"w",encoding="utf-8") as f:
        json.dump(rows,f,ensure_ascii=False,indent=2)
    print("WROTE", out, "rows=", len(rows))
