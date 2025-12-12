import csv, json, os, re

CSV_PATH = "base-officielle-codes-postaux.csv"
OUT_DIR = "assets/data/cities"
os.makedirs(OUT_DIR, exist_ok=True)

ENC = "cp1252"     # ton CSV contient des caractères type "é"
DELIM = ";"        # vu dans l'en-tête

COL_INSEE = "#Code_commune_INSEE"
COL_NAME  = "Nom_de_la_commune"
COL_CP    = "Code_postal"

def dept_token(cp: str, insee: str):
    cp = str(cp).strip()
    insee = (insee or "").strip().upper()

    if not re.fullmatch(r"\d{5}", cp):
        return None

    # Corse: INSEE donne 2A/2B (plus fiable que l'heuristique)
    if insee.startswith(("2A", "2B")):
        return insee[:2]

    # DOM/COM/Monaco: 97x / 98x / 975 / 980 / 986 / 987 / 988 ...
    if cp.startswith(("97", "98")):
        return cp[:3]

    # Métropole
    return cp[:2]

by = {}

with open(CSV_PATH, "r", encoding=ENC, newline="") as f:
    reader = csv.DictReader(f, delimiter=DELIM)
    # check colonnes
    for col in (COL_INSEE, COL_NAME, COL_CP):
        if col not in (reader.fieldnames or []):
            raise SystemExit(f"Colonne manquante: {col}. Colonnes: {reader.fieldnames}")

    for row in reader:
        name = (row.get(COL_NAME) or "").strip()
        cp = (row.get(COL_CP) or "").strip()
        insee = (row.get(COL_INSEE) or "").strip()

        tok = dept_token(cp, insee)
        if not tok or not name:
            continue

        by.setdefault(tok, []).append({
            "name": name,
            "cp": cp,
            "dept": tok,
            "region": ""   # la base postale ne donne pas la région (on l'ajoute après si tu veux)
        })

print("TOKENS FOUND:", len(by), "ex:", sorted(by.keys())[:25], "...")

for tok, rows in by.items():
    rows.sort(key=lambda x: (x["name"].lower(), x["cp"]))
    out = os.path.join(OUT_DIR, f"cities_{tok}.json")
    with open(out, "w", encoding="utf-8") as ff:
        json.dump(rows, ff, ensure_ascii=False, indent=2)

print("✅ DONE. files written:", len(by))
