#!/usr/bin/env python3
"""Build the study-note PDFs from the Markdown sources in notes/.

Usage:
    pip install -r requirements.txt
    python build.py            # build every module
    python build.py 01         # build only module 01

For each module directory notes/module-NN/ this script:
  * concatenates the *.md files in name order,
  * renders them to HTML (tables, syntax-highlighted SystemVerilog),
  * adds a cover page and a table of contents with page numbers,
  * writes pdf/<name>.pdf,
  * extracts every code block tagged  ```systemverilog file=<name>.sv
    into examples/module-NN/<name>.sv so it can be run in a simulator.
"""
import html
import pathlib
import re
import sys

from markdown_it import MarkdownIt
from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name
from weasyprint import HTML

ROOT = pathlib.Path(__file__).resolve().parent

COURSE_TITLE = "SystemVerilog Interview Preparation"
COURSE_SUBTITLE = "Detailed study notes for Design Verification roles"

# module number -> (title, output file name)
MODULES = {
    "01": (
        "SystemVerilog Fundamentals and Data Types",
        "SystemVerilog_Module_01_Fundamentals_and_Data_Types.pdf",
    ),
}

FORMATTER = HtmlFormatter(nowrap=True, style="friendly")

CSS = (
    """
@page {
  size: A4;
  margin: 21mm 16mm 19mm 16mm;
  @top-left   { content: "__HEADER__"; font: 8pt "Liberation Sans", sans-serif; color: #6b7280; }
  @top-right  { content: string(chapter); font: 8pt "Liberation Sans", sans-serif; color: #6b7280; }
  @bottom-center { content: counter(page); font: 9pt "Liberation Sans", sans-serif; color: #374151; }
}
@page cover {
  margin: 0;
  @top-left { content: none; } @top-right { content: none; } @bottom-center { content: none; }
}
html { font: 10pt/1.5 "Liberation Sans", "DejaVu Sans", sans-serif; color: #1f2933; }
body { margin: 0; }

.cover { page: cover; height: 297mm; box-sizing: border-box; padding: 70mm 22mm 0 22mm;
         background: #12304f; color: #ffffff; }
.cover .kicker { font-size: 12pt; letter-spacing: 2pt; text-transform: uppercase; color: #9cc3e6; }
.cover .title { font-size: 31pt; font-weight: bold; line-height: 1.2; margin: 8mm 0 6mm 0; }
.cover .module { font-size: 17pt; color: #ffd27a; margin-bottom: 4mm; }
.cover .sub { font-size: 12pt; color: #d6e4f0; }
.cover .foot { margin-top: 85mm; font-size: 9.5pt; color: #9cc3e6; line-height: 1.6; }

.toc { break-after: page; }
.toc h1 { break-before: auto; string-set: chapter "Contents"; }
.toc ul { list-style: none; padding: 0; margin: 0; }
.toc li { margin: 0; }
.toc li.l1 { margin-top: 3.2mm; font-weight: bold; color: #12304f; }
.toc li.l2 { padding-left: 6mm; font-size: 9.3pt; }
.toc a { color: inherit; text-decoration: none; }
.toc a::after { content: leader(".") target-counter(attr(href), page); color: #6b7280; font-weight: normal; }

h1 { font-size: 21pt; color: #12304f; border-bottom: 2.2pt solid #12304f; padding-bottom: 2mm;
     margin: 0 0 6mm 0; break-before: page; string-set: chapter content(); line-height: 1.25; }
h2 { font-size: 15pt; color: #12304f; margin: 9mm 0 3mm 0; padding: 1.6mm 3mm;
     background: #e6eef6; border-left: 3.5pt solid #12304f; break-after: avoid; line-height: 1.3; }
h3 { font-size: 11.8pt; color: #9a3412; margin: 6mm 0 2mm 0; break-after: avoid; }
h4 { font-size: 10.4pt; color: #1f2933; margin: 4.5mm 0 1.5mm 0; break-after: avoid; }
p { margin: 0 0 2.6mm 0; text-align: left; orphans: 2; widows: 2; }
ul, ol { margin: 0 0 2.6mm 0; padding-left: 6mm; }
li { margin-bottom: 0.9mm; }
li > p { margin-bottom: 1mm; }
strong { color: #111827; }
a { color: #1d4ed8; }
hr { border: 0; border-top: 0.6pt solid #cbd5e1; margin: 5mm 0; }

code { font-family: "DejaVu Sans Mono", monospace; font-size: 8.4pt; background: #eef1f4;
       padding: 0.2pt 2.2pt; border-radius: 2pt; color: #7c2d12; }
pre { font-family: "DejaVu Sans Mono", monospace; font-size: 7.9pt; line-height: 1.38;
      white-space: pre-wrap; overflow-wrap: anywhere; margin: 1mm 0 3.6mm 0; padding: 2.6mm 3mm;
      border-radius: 2.5pt; border: 0.6pt solid #d5dbe1; background: #f7f9fb; }
pre code { background: none; padding: 0; color: inherit; font-size: inherit; }
pre.short { break-inside: avoid; }
pre.lang-systemverilog { border-left: 2.6pt solid #2563eb; }
pre.lang-output { background: #14212e; color: #dbe7f3; border-color: #14212e; }
pre.lang-text { background: #fffdf5; border-color: #e7dfc3; line-height: 1.22; }
.fname { font: bold 7.6pt "DejaVu Sans Mono", monospace; color: #1d4ed8; margin: 2.5mm 0 0 0;
         break-after: avoid; }
.outlabel { font: bold 7.6pt "Liberation Sans", sans-serif; color: #475569; margin: 0;
            text-transform: uppercase; letter-spacing: 0.6pt; break-after: avoid; }

table { border-collapse: collapse; width: 100%; margin: 1.5mm 0 4mm 0; font-size: 8.9pt; line-height: 1.38; }
th { background: #12304f; color: #ffffff; text-align: left; padding: 1.5mm 2mm; border: 0.5pt solid #12304f; }
td { padding: 1.3mm 2mm; border: 0.5pt solid #c5ced8; vertical-align: top; }
tr { break-inside: avoid; }
tbody tr:nth-child(even) td { background: #f3f6f9; }
td code, th code { font-size: 7.9pt; }
th code { background: #2a4a6b; color: #ffffff; }

blockquote { margin: 2mm 0 4mm 0; padding: 2.2mm 3.5mm; border-left: 3.2pt solid #64748b;
             background: #f1f5f9; break-inside: avoid; }
blockquote p:last-child { margin-bottom: 0; }
blockquote.trap    { border-color: #dc2626; background: #fef2f2; }
blockquote.mistake { border-color: #ea580c; background: #fff7ed; }
blockquote.key     { border-color: #16a34a; background: #f0fdf4; }
blockquote.synth   { border-color: #7c3aed; background: #f5f3ff; }
blockquote.tb      { border-color: #0891b2; background: #ecfeff; }
"""
    + FORMATTER.get_style_defs("pre")
)

CALLOUT_CLASSES = [
    ("trap", "trap"),
    ("mistake", "mistake"),
    ("misconception", "mistake"),
    ("key point", "key"),
    ("remember", "key"),
    ("how to say", "key"),
    ("synthesis", "synth"),
    ("verification", "tb"),
    ("industry", "tb"),
]


def make_renderer(example_dir):
    """Return a MarkdownIt instance whose fenced-code handler highlights code
    and saves blocks tagged with file=<name> into example_dir."""

    def render_code(code, lang, attrs):
        lang = (lang or "text").lower()
        fname = None
        m = re.search(r"file=(\S+)", attrs or "")
        if m:
            fname = m.group(1)
            example_dir.mkdir(parents=True, exist_ok=True)
            (example_dir / fname).write_text(code, encoding="utf-8")
        if lang in ("systemverilog", "sv", "verilog"):
            body = highlight(code, get_lexer_by_name("systemverilog"), FORMATTER)
            cls = "lang-systemverilog"
        else:
            body = html.escape(code)
            cls = "lang-output" if lang == "output" else "lang-text"
        if code.count("\n") <= 45:
            cls += " short"
        out = ""
        if fname:
            out += f'<p class="fname">{html.escape(fname)}</p>'
        if lang == "output":
            out += '<p class="outlabel">Expected output</p>'
        return out + f'<pre class="{cls}"><code>{body}</code></pre>\n'

    def fence(renderer, tokens, idx, options, env):
        token = tokens[idx]
        lang, _, attrs = token.info.strip().partition(" ")
        return render_code(token.content, lang, attrs)

    md = MarkdownIt("commonmark").enable("table")
    md.add_render_rule("fence", fence)
    return md


def post_process(body):
    """Add heading ids, collect the table of contents, classify callouts."""
    toc = []
    counter = [0]

    def heading(m):
        level, inner = int(m.group(1)), m.group(2)
        counter[0] += 1
        hid = f"sec-{counter[0]}"
        if level <= 2:
            toc.append((level, hid, re.sub(r"<[^>]+>", "", inner)))
        return f'<h{level} id="{hid}">{inner}</h{level}>'

    # A paragraph that is entirely bold is a lead-in label: make it a heading
    # so that it is never left alone at the bottom of a page.
    body = re.sub(r"<p><strong>([^<]{1,80})</strong></p>", r"<h4>\1</h4>", body)
    body = re.sub(r"<h([1-4])>(.*?)</h\1>", heading, body, flags=re.S)

    def callout(m):
        label = m.group(1).lower()
        cls = next((c for key, c in CALLOUT_CLASSES if key in label), "note")
        return f'<blockquote class="{cls}">\n<p><strong>{m.group(1)}</strong>'

    body = re.sub(r"<blockquote>\s*<p><strong>(.*?)</strong>", callout, body, flags=re.S)
    return body, toc


def build(num):
    title, pdf_name = MODULES[num]
    src_dir = ROOT / "notes" / f"module-{num}"
    sources = sorted(src_dir.glob("*.md"))
    if not sources:
        sys.exit(f"no markdown files in {src_dir}")
    text = "\n\n".join(p.read_text(encoding="utf-8") for p in sources)

    md = make_renderer(ROOT / "examples" / f"module-{num}")
    body, toc = post_process(md.render(text))

    toc_html = "".join(
        f'<li class="l{lvl}"><a href="#{hid}">{name}</a></li>' for lvl, hid, name in toc
    )
    header = f"{COURSE_TITLE} — Module {int(num)}"
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<title>{COURSE_TITLE} - Module {int(num)}: {title}</title>
<style>{CSS.replace("__HEADER__", header)}</style></head>
<body>
<section class="cover">
  <div class="kicker">VLSI Design Verification</div>
  <div class="title">{COURSE_TITLE}</div>
  <div class="module">Module {int(num)}: {title}</div>
  <div class="sub">{COURSE_SUBTITLE}</div>
  <div class="foot">Concepts from first principles &middot; complete SystemVerilog examples &middot;
  line-by-line explanations<br>comparison tables &middot; common mistakes &middot; interview questions with answers
  &middot; coding exercises</div>
</section>
<section class="toc"><h1>Contents</h1><ul>{toc_html}</ul></section>
{body}
</body></html>"""

    out_dir = ROOT / "pdf"
    out_dir.mkdir(exist_ok=True)
    out = out_dir / pdf_name
    doc = HTML(string=page, base_url=str(ROOT)).render()
    doc.write_pdf(out)
    print(f"module {num}: {len(doc.pages)} pages -> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    wanted = sys.argv[1:] or sorted(MODULES)
    for n in wanted:
        if n not in MODULES:
            sys.exit(f"unknown module {n!r}; known: {', '.join(sorted(MODULES))}")
        build(n)
