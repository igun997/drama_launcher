#!/usr/bin/env python3
"""Buat gambar lewat endpoint kompatibel OpenAI (URL, KEY dari berkas .env).

Pakai:
  python3 tools/genimg.py OUT.png "prompt" [--env .env] [--model cx/gpt-6.1-sol] [--size 1024x1024]

Rahasia dibaca dari berkas env dan tidak pernah dicetak atau disalin ke repo.
"""
import argparse, base64, json, pathlib, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent


def load_env(path):
    env = {}
    for line in pathlib.Path(path).read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("prompt")
    ap.add_argument("--env", default=str(ROOT / ".env"), help="berkas env berisi URL dan KEY (jangan di-commit)")
    ap.add_argument("--model", default="cx/gpt-6.1-sol")
    ap.add_argument("--size", default="1024x1024")
    a = ap.parse_args()

    env = load_env(a.env)
    base = env["URL"].rstrip("/")
    if not base.endswith("/v1"):
        base += "/v1"
    req = urllib.request.Request(
        base + "/images/generations",
        data=json.dumps({"model": a.model, "prompt": a.prompt, "size": a.size, "n": 1}).encode(),
        headers={"Authorization": "Bearer " + env["KEY"], "Content-Type": "application/json", "User-Agent": "curl/8.5.0"},
    )
    with urllib.request.urlopen(req, timeout=300) as r:
        d = json.load(r)["data"][0]
    out = pathlib.Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(base64.b64decode(d["b64_json"]))
    print("wrote", out)


if __name__ == "__main__":
    sys.exit(main())
