"""Runs SQL on the game's Supabase project through the Management API, or reads/changes the auth
settings. The owner's access token is read from tmp/supabase_token.txt (git-ignored).

    python tools/supabase_sql.py "select count(*) from public.players"
    python tools/supabase_sql.py -f supabase/migrations/<file>.sql
    python tools/supabase_sql.py --auth-get smtp_host site_url
"""
import json, os, sys, urllib.error, urllib.request

REF = "nlaylfcbijvdwbbcuqhj"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKEN = open(os.path.join(ROOT, "tmp", "supabase_token.txt"), encoding="utf-8-sig").read().strip()


def api(method, path, body=None):
    req = urllib.request.Request(f"https://api.supabase.com/v1/projects/{REF}{path}", method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json"})
    try:
        return json.load(urllib.request.urlopen(req, timeout=60))
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()[:800]}


def sql(query):
    return api("POST", "/database/query", {"query": query})


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    if sys.argv[1] == "--auth-get":
        conf = api("GET", "/config/auth")
        print(json.dumps({k: conf.get(k) for k in sys.argv[2:]}, ensure_ascii=False, indent=1))
    else:
        q = open(sys.argv[2], encoding="utf-8").read() if sys.argv[1] == "-f" else sys.argv[1]
        print(json.dumps(sql(q), ensure_ascii=False, indent=1)[:6000])
