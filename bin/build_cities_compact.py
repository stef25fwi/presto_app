import json, glob, os
from collections import defaultdict

paths = sorted(glob.glob("assets/data/cities/cities_*.json"))

# clé: (dept, name_lower) -> {name, dept, cps:set}
bucket = {}

def key(dept, name):
  return (dept, name.strip().lower())

for p in paths:
  data = json.load(open(p, "r", encoding="utf-8"))
  if isinstance(data, dict):
    data = data.get("data", [])
  for r in data:
    name = str(r.get("name","")).strip()
    cp = str(r.get("cp","")).strip()
    dept = str(r.get("dept","")).strip()
    if not name or not cp or not dept:
      continue

    k = key(dept, name)
    if k not in bucket:
      bucket[k] = {"name": name, "dept": dept, "cps": set()}
    bucket[k]["cps"].add(cp)

out = []
for v in bucket.values():
  out.append({
    "name": v["name"],
    "dept": v["dept"],
    "cps": sorted(v["cps"]),
  })

out.sort(key=lambda x: (x["name"].lower(), x["dept"], x["cps"][0]))

os.makedirs("assets/data", exist_ok=True)
with open("assets/data/cities_compact.json", "w", encoding="utf-8") as f:
  json.dump(out, f, ensure_ascii=False, indent=2)

print("OK cities_compact.json ->", len(out), "communes")
