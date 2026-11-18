"""Wiki delle meccaniche per GitHub Pages: python3 tools/make_wiki.py -> docs/index.html

Testo: le pagine della wiki in gioco (wiki.gd, BBCode). Numeri: le costanti di main.gd e atmosphere.gd così come sono
scritte, con i loro commenti (senza preload, colori e shader). Rifallo dopo aver cambiato il gioco.
"""
import base64, datetime, html, re, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "index.html"
NUMBERS = ["main.gd", "atmosphere.gd"]
HEADING = "#e8c34a"  # [color=HEADING] da solo su una riga: titolo; altri colori da soli: sottotitolo


def icon(m):
    data = base64.b64encode((ROOT / m.group(1)).read_bytes()).decode()
    return f'<img class="ic" src="data:image/png;base64,{data}" alt="">'


def inline(s):
    s = re.sub(r"\[img=\w+\]res://(.+?)\[/img\]", icon, s)
    return re.sub(r"\[color=(#\w+)\](.*?)\[/color\]", r'<span style="color:\1">\2</span>', s)


def table(m):
    cols, cells = int(m.group(1)), [inline(c) for c in re.findall(r"\[cell\](.*?)\[/cell\]", m.group(2), re.S)]
    rows = ["<tr>" + "".join(f"<td>{c}</td>" for c in cells[i:i + cols]) + "</tr>" for i in range(0, len(cells), cols)]
    return "\x00<table>" + "".join(rows) + "</table>\n"


def page(text):
    text = re.sub(r"\[table=(\d+)\](.*?)\[/table\]\n?", table, html.escape(text, quote=False), flags=re.S)
    out, in_list = [], False
    for line in text.split("\n"):
        line = line.strip()
        bullet = line.startswith("•")
        if in_list and not bullet:
            out.append("</ul>")
            in_list = False
        if not line:
            continue
        if line.startswith("\x00"):
            out.append(line[1:])
        elif bullet:
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[1:].strip())}</li>")
        elif m := re.fullmatch(r"\[color=(#\w+)\](.*?)\[/color\]\s*((?:\[img=.*?\[/img\]\s*)*)", line):
            tag = "h3" if m.group(1) == HEADING else "h4"
            out.append(f"<{tag}>{inline(m.group(2))} {inline(m.group(3))}</{tag}>")
        else:
            out.append(f"<p>{inline(line)}</p>")
    return "\n".join(out + (["</ul>"] if in_list else []))


def wiki_pages():
    src = (ROOT / "wiki.gd").read_text()
    return re.findall(r'^\t\["(.+?)", """(.*?)"""\],', src, re.M | re.S)


def split_comment(line):
    """(codice, commento): il primo # fuori dalle virgolette."""
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == "\\":
                continue
            if ch == quote and line[i - 1] != "\\":
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "#":
            return line[:i], line[i:]
    return line, ""


def depth(code):
    code = re.sub(r'"(?:\\.|[^"\\])*"', "", code)
    return sum(code.count(c) for c in "([{") - sum(code.count(c) for c in ")]}")


def kept(unit):
    """Via shader e costanti solo grafiche: quelle in cui ogni valore è un preload o un colore (GEAR, con una tinta, resta)."""
    if unit[0].startswith("enum"):
        return True
    if '"""' in unit[0]:
        return False
    code = [split_comment(unit[0])[0].split("=", 1)[-1]] + [split_comment(l)[0] for l in unit[1:]]
    code = [c for c in code if c.strip().strip("{[()]}")]
    return not all("preload(" in c or "Color" in c for c in code)


def blocks(path):
    """Gruppi (commento + costanti che lo seguono, o righe vuote a separarli) della parte in cima al file, con le sole costanti ed enum utili."""
    lines = (ROOT / path).read_text().split("\n")
    end = next(i for i, l in enumerate(lines) if re.match(r"(func|class|var|@onready) ", l))
    groups, cur, i = [], [], 0
    while i < end:
        line = lines[i]
        if not line.strip():
            groups.append(cur)
            cur, i = [], i + 1
            continue
        if not re.match(r"(const|enum) ", line):
            if line.startswith("#"):
                if cur and cur[-1][0] == "decl":  # un commento dopo delle costanti apre un nuovo gruppo
                    groups.append(cur)
                    cur = []
                cur.append(("comment", [line]))
            i += 1
            continue
        unit, d, triple = [line], depth(split_comment(line)[0]), line.count('"""') % 2
        while (d > 0 or triple) and i + 1 < end:
            i += 1
            unit.append(lines[i])
            triple ^= lines[i].count('"""') % 2
            d += depth(split_comment(lines[i])[0])
        cur.append(("decl", unit))
        i += 1
    groups.append(cur)
    return [g for g in groups if any(k == "decl" and kept(u) for k, u in g)]


def code_line(line):
    code, comment = (html.escape(p, quote=False) for p in split_comment(line))
    code = re.sub(r"^(const|enum) (\w+)", r'\1 <b id="c-\2">\2</b>', code)
    return code + (f"<i>{comment}</i>" if comment else "")


def numbers(path):
    out = []
    for g in blocks(path):
        rows = [code_line(l) for k, u in g if k == "comment" or kept(u) for l in u]
        out.append("<pre>" + "\n".join(rows) + "</pre>")
    return "\n".join(out)


def slug(s):
    return re.sub(r"\W+", "-", s.lower()).strip("-")


def main():
    pages = wiki_pages()
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    nav = "".join(f'<a href="#{slug(t)}">{html.escape(t)}</a>' for t, _ in pages)
    nav += '<h2>Numeri</h2>' + "".join(f'<a href="#{slug(f)}">{f}</a>' for f in NUMBERS)
    body = "".join(f'<section id="{slug(t)}"><h2>{html.escape(t)}</h2>{page(txt)}</section>' for t, txt in pages)
    body += "".join(f'<section id="{slug(f)}"><h2>Numeri: {f}</h2>{numbers(f)}</section>' for f in NUMBERS)
    OUT.write_text(TEMPLATE.format(nav=nav, body=body, commit=commit, date=datetime.date.today().isoformat()))
    print(f"{OUT.relative_to(ROOT)}: {len(pages)} pagine, {OUT.stat().st_size // 1024} KB")


TEMPLATE = """<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>King — Meccaniche</title>
<style>
:root {{ --bg: #1f1a24; --panel: #2a2431; --line: #3d3547; --text: #e6e2d0; --muted: #a39d8f; --gold: #e8c34a; --sub: #d9c48a; }}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: var(--bg); color: var(--text); font: 16px/1.55 system-ui, sans-serif; }}
nav {{ position: fixed; inset: 0 auto 0 0; width: 230px; overflow-y: auto; padding: 20px 16px; background: var(--panel); border-right: 1px solid var(--line); }}
nav h1 {{ margin: 0 0 4px; font-size: 20px; color: var(--gold); }}
nav h2 {{ margin: 20px 0 6px; font-size: 13px; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); }}
nav small {{ color: var(--muted); }}
nav a {{ display: block; padding: 3px 0; color: var(--text); text-decoration: none; }}
nav a:hover {{ color: var(--gold); }}
main {{ margin-left: 230px; padding: 24px 40px 80px; max-width: 1100px; }}
section {{ padding-top: 8px; border-bottom: 1px solid var(--line); padding-bottom: 24px; }}
section > h2 {{ font-size: 28px; color: var(--gold); margin: 24px 0 8px; }}
h3 {{ color: var(--gold); margin: 22px 0 6px; font-size: 19px; }}
h4 {{ color: var(--sub); margin: 16px 0 4px; font-size: 16px; }}
p, li {{ max-width: 75ch; }}
ul {{ padding-left: 22px; margin: 6px 0; }}
li {{ margin: 3px 0; }}
.ic {{ width: 16px; height: 16px; image-rendering: pixelated; vertical-align: -2px; }}
table {{ display: block; overflow-x: auto; border-collapse: collapse; margin: 8px 0; }}
td {{ border: 1px solid var(--line); padding: 3px 10px; }}
pre {{ background: var(--panel); border: 1px solid var(--line); border-radius: 4px; padding: 10px 12px; white-space: pre-wrap; overflow-wrap: anywhere; font: 13px/1.5 ui-monospace, Menlo, monospace; }}
pre b {{ color: var(--gold); }}
pre i {{ color: #8fb87a; }}
:target {{ scroll-margin-top: 12px; }}
@media (max-width: 800px) {{
  nav {{ position: static; width: auto; border-right: 0; border-bottom: 1px solid var(--line); }}
  nav a {{ display: inline-block; margin-right: 12px; }}
  main {{ margin: 0; padding: 16px; }}
}}
</style>
</head>
<body>
<nav>
<h1>King</h1>
<small>Meccaniche · commit {commit} · {date}</small>
<h2>Wiki</h2>
{nav}
</nav>
<main>
<p><small style="color:var(--muted)">Testo: la wiki in gioco (<code>wiki.gd</code>). Numeri: le costanti di
<code>main.gd</code> e <code>atmosphere.gd</code> come sono nel codice. Dove non coincidono, vale il codice.
Generata da <code>tools/make_wiki.py</code>.</small></p>
{body}
</main>
</body>
</html>
"""

if __name__ == "__main__":
    main()
