"""Controllo delle traduzioni: python3 tools/check_translations.py [lingua]   (di base: it)

Legge locale/<lingua>.po e cerca nel gioco i testi da tradurre: le chiamate tr("..."), tr_n("...", "..."),
TranslationServer.translate("...") negli script, i testi delle scene (text, tooltip_text, placeholder_text, title) e i
nomi degli enum mostrati con named() (main.gd), col loro contesto. Segnala:
- i testi senza voce nel .po;
- le voci con segnaposto (%s, %d, %.1f...) diversi o in un altro ordine (il % di GDScript è posizionale);
- le voci con tag BBCode o icone [img] diversi;
- le traduzioni uguali a un altro testo inglese con un'altra traduzione (i Control le ritradurrebbero).
I testi composti a mano (senza tr) non li vede: quelli vanno guardati in gioco.
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STR = r'"((?:\\.|[^"\\])*)"'
FORMAT = re.compile(r"%(?:%|[-+ 0#]*\d*(?:\.\d+)?[sdifxXc])")
TAG = re.compile(r"\[/?(?:color|img|b|i|u|table|cell|center|url|font_size)[^\]]*\]")


def unescape(s):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def read_po(path):
    """{(contesto, msgid): [msgstr, ...]} e {(contesto, msgid): msgid_plural}"""
    entries, plurals, cur, key = {}, {}, {}, None

    def flush():
        if cur.get("msgid"):
            k = (cur.get("msgctxt", ""), cur["msgid"])
            entries[k] = [cur[f] for f in sorted(cur) if f.startswith("msgstr")]
            if "msgid_plural" in cur:
                plurals[k] = cur["msgid_plural"]
        cur.clear()

    for line in path.read_text(encoding="utf-8").split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if m := re.match(r"(msgctxt|msgid_plural|msgid|msgstr(?:\[\d\])?)\s+" + STR + "$", line):
            if m.group(1) in ("msgctxt", "msgid") and ("msgstr" in cur or "msgstr[0]" in cur):
                flush()
            key = m.group(1)
            cur[key] = unescape(m.group(2))
        elif m := re.fullmatch(STR, line):
            cur[key] += unescape(m.group(1))
    flush()
    return entries, plurals


def enums():
    """{nome dell'enum: [nomi mostrati]} di main.gd e atmosphere.gd"""
    out = {}
    for f in ("main.gd", "atmosphere.gd"):
        for m in re.finditer(r"^enum (\w+) \{(.*?)\}", (ROOT / f).read_text(), re.M | re.S):
            body = re.sub(r"#.*", "", m.group(2))
            out[m.group(1)] = [" ".join(w.capitalize() for w in k.split("_")) for k in re.findall(r"\b[A-Z][A-Z_]*\b", body)]
    return out


def wanted():
    """[(contesto, msgid, plurale o None, dove)] di quello che il gioco traduce"""
    out = []
    names = enums()
    for f in sorted(ROOT.glob("*.gd")):
        text = f.read_text()
        for n, line in enumerate(text.split("\n"), 1):
            where = f"{f.name}:{n}"
            for m in re.finditer(r"\b(?:tr|TranslationServer\.translate)\(\s*" + STR + r"(?:\s*,\s*" + STR + r")?\s*\)", line):
                out.append((unescape(m.group(2) or ""), unescape(m.group(1)), None, where))
            for m in re.finditer(r"\b(?:tr_n|TranslationServer\.translate_plural)\(\s*" + STR + r"\s*,\s*" + STR
                                 + r"\s*,[^,)]+(?:,\s*" + STR + r")?\s*\)", line):
                out.append((unescape(m.group(3) or ""), unescape(m.group(1)), unescape(m.group(2)), where))
            for m in re.finditer(r"\bnamed\(\s*(?:Main\.|main\.)?(\w+)\s*,[^,)]+(?:,\s*" + STR + r")?\s*\)", line):
                for name in names.get(m.group(1), []):
                    out.append((unescape(m.group(2) or ""), name, None, f"{where} ({m.group(1)})"))
    for f in sorted(ROOT.glob("*.tscn")):
        for m in re.finditer(r"^(?:text|tooltip_text|placeholder_text|title) = " + STR, f.read_text(), re.M | re.S):
            s = unescape(m.group(1))
            if re.search(r"[A-Za-z]{2}", s):
                out.append(("", s, None, f.name))
    return out


def main():
    lang = sys.argv[1] if len(sys.argv) > 1 else "it"
    entries, plurals = read_po(ROOT / "locale" / f"{lang}.po")
    problems = 0
    seen = set()
    for ctx, msgid, plural, where in wanted():
        if (ctx, msgid) in seen:
            continue
        seen.add((ctx, msgid))
        if (ctx, msgid) not in entries or not any(entries[(ctx, msgid)]):
            print(f"manca  {where}: " + (f"[{ctx}] " if ctx else "") + repr(msgid))
            problems += 1
        elif plural and plurals.get((ctx, msgid)) != plural:
            print(f"plurale {where}: {msgid!r} -> nel .po {plurals.get((ctx, msgid))!r}, nel codice {plural!r}")
            problems += 1
    plain = {msgid: strs[0] for (ctx, msgid), strs in entries.items() if not ctx and strs}
    for (ctx, msgid), strs in entries.items():
        sources = [msgid, plurals.get((ctx, msgid), msgid)]
        for i, s in enumerate(strs):
            src = sources[min(i, 1)]
            if FORMAT.findall(src) != FORMAT.findall(s):
                print(f"segnaposto: {msgid!r}\n  {FORMAT.findall(src)} -> {FORMAT.findall(s)}")
                problems += 1
            if sorted(TAG.findall(src)) != sorted(TAG.findall(s)):
                print(f"tag: {msgid!r}")
                problems += 1
            if s in plain and s != msgid and plain[s] != s:
                print(f"ritradotto: {msgid!r} -> {s!r}, che è anche un testo inglese ({plain[s]!r})")
                problems += 1
    print(f"{len(entries)} voci, {len(seen)} testi nel gioco, {problems} problemi")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
