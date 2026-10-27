"""Look up each bank's iPhone app in Apple's public search (Philippines store)
and print the top matches with their developer, so the right one can be picked.

Usage: python -I appstore_lookup.py
"""
import json
import urllib.parse
import urllib.request

TERMS = {
    "gcash": "GCash",
    "maya": "Maya savings loans cards",
    "gotyme": "GoTyme Bank",
    "maribank": "MariBank",
    "bdo": "BDO Digital Banking",
    "bpi": "BPI mobile",
    "metrobank": "Metrobank",
    "landbank": "LANDBANK Mobile Banking",
    "pnb": "PNB Digital Banking",
    "securitybank": "Security Bank Mobile",
    "unionbank": "UnionBank Online",
    "rcbc": "RCBC Pulz",
    "chinabank": "China Bank Mobile",
    "eastwest": "EastWest Mobile",
    "psbank": "PSBank Mobile",
    "aub": "AUB Mobile Banking",
    "pbcom": "PBCom",
}


def search(term):
    url = "https://itunes.apple.com/search?" + urllib.parse.urlencode(
        {"term": term, "country": "ph", "entity": "software", "limit": 5}
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)["results"]


out = {}
for bank, term in TERMS.items():
    try:
        out[bank] = [
            {
                "app": r.get("trackName"),
                "by": r.get("sellerName") or r.get("artistName"),
                "art": r.get("artworkUrl512"),
            }
            for r in search(term)
        ]
    except Exception as e:
        out[bank] = f"failed: {type(e).__name__}"
import sys
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps(out, indent=1, ensure_ascii=False))
