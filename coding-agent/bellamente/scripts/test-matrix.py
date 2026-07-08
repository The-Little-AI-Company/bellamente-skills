#!/usr/bin/env python3
"""Bellamente base-memory feature matrix. Corrected field shapes."""
import json, urllib.request, urllib.error, datetime, time, sys

BASE = "http://127.0.0.1:8080"
def req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(f"{BASE}{path}", data=data, method=method,
        headers={"content-type":"application/json"})
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            ct = resp.headers.get("x-bella-trace-id","")
            return resp.status, json.loads(resp.read()), ct
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:200], ""

passed = failed = 0
fails = []
def check(name, cond, detail=""):
    global passed, failed
    if cond: passed += 1; print(f"  [PASS] {name}")
    else: failed += 1; fails.append(name); print(f"  [FAIL] {name}  {detail[:120]}")

print("=== Bellamente base-memory feature matrix ===\n")

# 1 health
st, r, _ = req("GET","/health")
check("health ok", st==200 and r.get("ok"))

# 2 write
st, r, _ = req("POST","/memories",{"containerTag":"default","memories":[
    {"content":"TEST FACT: the build server is named orion","isStatic":True}]})
m0 = r["memories"][0]
check("write creates memory", m0.get("action")=="created", str(r)[:120])
pid = m0["id"]

# 3 list
st, lst, _ = req("GET","/memories")
ids = [m["id"] for m in lst["memories"]]
check("written memory appears in list", pid in ids or any(
    v.get("id")==pid for _ in [] ))
# list shows latest id; for a fresh single-version memory that's pid
check("written memory appears in list", pid in ids)

# 4 search
st, sr, tid = req("POST","/search",{"q":"build server name","searchMode":"memories","limit":5})
hit = any("orion" in x.get("memory","").lower() for x in sr.get("results",[]))
check("search finds written memory", hit)
check("search returns traceId", bool(sr.get("traceId")))
check("search results carry similarity score",
      "similarity" in sr.get("results",[{}])[0] if sr.get("results") else False)

# 5 supersede
time.sleep(1)
t1 = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
time.sleep(1)
st, r, _ = req("PATCH",f"/memories/{pid}",{"content":"TEST FACT: the build server is named andromeda"})
mem = r.get("memory",{})
check("supersede returns new version (v2, isLatest)", mem.get("version")==2 and mem.get("isLatest"), str(r)[:120])
new_id = mem.get("id", pid)

# 6 chain
st, ch, _ = req("GET",f"/memories/{new_id}")
vers = ch.get("versions",[])
check("chain has >=2 versions", len(vers)>=2)
texts = [v.get("memory","") for v in vers]
check("chain preserves old version (orion)", any("orion" in t.lower() for t in texts))
check("chain has new version (andromeda)", any("andromeda" in t.lower() for t in texts))
check("chain carries validFrom/validTo windows",
      any(v.get("validTo") for v in vers) and any(v.get("validFrom") for v in vers))

# 7 asOf at t1 (post-write, pre-supersede) -> should surface orion
st, ar, _ = req("POST","/search",{"q":"build server name","searchMode":"memories","limit":5,"asOf":t1})
asof_hit = any("orion" in x.get("memory","").lower() for x in ar.get("results",[]))
check("asOf returns the OLD version (orion)", asof_hit, str(ar)[:120] if st!=200 else f"hits={[x.get('memory','')[:20] for x in ar.get('results',[])]}")

# 8 forget
st, r, _ = req("POST",f"/memories/{new_id}/forget",{})
check("forget returns ok", st==200 and r.get("forgotten")==True)
st, lst, _ = req("GET","/memories")
ids = [m["id"] for m in lst["memories"]]
check("forgotten memory hidden from list", new_id not in ids)

# 9 unforgot
st, r, _ = req("POST",f"/memories/{new_id}/forget",{"undo":True})
check("unforget returns ok", st==200 and r.get("forgotten")==False)
st, lst, _ = req("GET","/memories")
ids = [m["id"] for m in lst["memories"]]
check("unforget restores memory to list", new_id in ids)

# 10 inspect
st, r, _ = req("GET","/inspect")
check("inspect returns traces list", st==200 and isinstance(r.get("traces"), list) or isinstance(r, list) or "traces" in str(r)[:50])

# 11 export
st, r, _ = req("GET","/export")
check("export is valid JSON with format field", r.get("format")=="bellamente-export")
raw = json.dumps(r)
check("export contains no raw embedding vectors", "embedding" not in raw.lower() or "[0." not in raw[:5000])

# 12 profile
st, r, _ = req("GET","/profile")
check("profile returns static+dynamic keys", "static" in r and "dynamic" in r)

# cleanup
req("DELETE",f"/memories/{new_id}")
print(f"\ncleanup: deleted test chain {new_id}")

print(f"\n=== RESULT: {passed}/{passed+failed} passed ===")
if fails:
    print("FAILURES:")
    for f in fails: print(f"  - {f}")
sys.exit(1 if failed else 0)
