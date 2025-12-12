import json, os, re, glob
from collections import defaultdict, Counter

DIR = "assets/data/cities"
paths = sorted(glob.glob(os.path.join(DIR, "cities_*.json")))

def expected_tokens():
    base = [f"{i:02d}" for i in range(1, 96) if i != 20] + ["2A", "2B"]
    # DOM (départements) + Mayotte + Saint-Pierre-et-Miquelon + Monaco (si tu veux)
    extra = ["971", "972", "973", "974", "976", "975", "980"]
    return base + extra

missing_files = []
present_tokens = []

bad_records = 0
total_records = 0
empty_files = []
dept_counts = Counter()
name_dups_by_dept = defaultdict(Counter)
cp_dups_by_dept = defaultdict(Counter)

def load_list(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):
        # fallback si jamais tu as {"data":[...]}
        data = data.get("data", [])
    if not isinstance(data, list):
        return []
    return data

def token_from_filename(p):
    m = re.search(r"cities_([0-9A-Za-z]{2,3})\.json$", os.path.basename(p))
    return m.group(1) if m else None

def is_cp_valid(cp):
    return bool(re.fullmatch(r"\d{5}", str(cp)))

for p in paths:
    token = token_from_filename(p)
    if token: present_tokens.append(token)

    data = load_list(p)
    if not data:
        empty_files.append(os.path.basename(p))
        continue

    seen_name_cp = set()
    for r in data:
        total_records += 1

        name = str(r.get("name", "")).strip()
        cp = str(r.get("cp", "")).strip()
        dept = str(r.get("dept", "")).strip()
        region = str(r.get("region", "")).strip()

        ok = True
        if not name or not cp or not dept:
            ok = False
        if not is_cp_valid(cp):
            ok = False

        # cohérence dept vs CP (DOM/TOM => 3 chiffres, sinon 2 sauf 2A/2B)
        if dept not in ("2A","2B"):
            if cp.startswith(("97","98")):
                if dept != cp[:3]: ok = False
            else:
                if dept != cp[:2]: ok = False

        if not ok:
            bad_records += 1

        dept_counts[dept] += 1
        name_dups_by_dept[dept][name.lower()] += 1
        cp_dups_by_dept[dept][cp] += 1

# trous fichiers
expected = expected_tokens()
present = set(present_tokens)
for t in expected:
    fname = f"cities_{t}.json"
    if not os.path.exists(os.path.join(DIR, fname)):
        missing_files.append(fname)

print("=== AUDIT CITIES ===")
print("Dossier:", DIR)
print("Nb fichiers trouvés:", len(paths))
print("Nb enregistrements:", total_records)
print("Enregistrements invalides:", bad_records)

print("\n--- Fichiers vides ---")
print("\n".join(empty_files) if empty_files else "OK")

print("\n--- Fichiers manquants (attendus) ---")
print("\n".join(missing_files) if missing_files else "OK")

print("\n--- Top 15 départements par volume ---")
for d, c in dept_counts.most_common(15):
    print(d, c)

print("\n--- Doublons (mêmes name+dept) : Top 10 ---")
dup_list = []
for d, cnt in name_dups_by_dept.items():
    for name, n in cnt.items():
        if n > 1 and name:
            dup_list.append((n, d, name))
dup_list.sort(reverse=True)
for n, d, name in dup_list[:10]:
    print(d, n, name)

print("\n--- Doublons (mêmes CP+dept) : Top 10 ---")
dup_cp = []
for d, cnt in cp_dups_by_dept.items():
    for cp, n in cnt.items():
        if n > 1 and cp:
            dup_cp.append((n, d, cp))
dup_cp.sort(reverse=True)
for n, d, cp in dup_cp[:10]:
    print(d, n, cp)
