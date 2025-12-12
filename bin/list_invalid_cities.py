import json, glob, re, os

DIR="assets/data/cities"
paths=sorted(glob.glob(os.path.join(DIR,"cities_*.json")))

def dept_from_cp(cp):
    cp=str(cp)
    if not re.fullmatch(r"\d{5}", cp): return None
    if cp.startswith(("97","98")): return cp[:3]
    if cp.startswith("20"): return "20"  # sera re-routé en 2A/2B plus bas
    return cp[:2]

bad=[]
for p in paths:
    data=json.load(open(p,"r",encoding="utf-8"))
    if isinstance(data, dict): data=data.get("data",[])
    for i,r in enumerate(data):
        name=str(r.get("name","")).strip()
        cp=str(r.get("cp","")).strip()
        dept=str(r.get("dept","")).strip()
        ok=True
        if not name or not re.fullmatch(r"\d{5}", cp): ok=False
        expected=dept_from_cp(cp)
        if expected and dept not in ("2A","2B"):
            if expected!="20" and dept!=expected: ok=False
        if not ok:
            bad.append((os.path.basename(p), i, r))
print("INVALID:", len(bad))
for f,i,r in bad[:200]:
    print(f, i, r)
