#!/usr/bin/env python3
# Copyright (c) 2026 Peter Nicolai Alexis Kyaw
# SPDX-License-Identifier: BSD-3-Clause
"""The office routes' evaluation (office/PDF prototype, part-evaluation).

Standard library only. On mbp, with the screen unlocked:

    python3 run_evaluation.py              # references, three runs, comparison
    python3 run_evaluation.py --runs 1
    python3 run_evaluation.py --skip-drive # the comparison again from the
                                           # scratch folder

1. compiles pdfkit_tool.swift (PDFKit: renders and compares PDF pages);
2. makes the older formats (report.doc, sheet.xls, deck.ppt) with desktop
   LibreOffice, and the fidelity references: desktop LibreOffice's PDF
   export, Quick Look's rendering, Microsoft Word, Excel and PowerPoint's PDF
   export (AppleScript);
3. runs integration_test/office_routes_test.dart once per run in a profile
   build (`flutter drive --profile`): both routes;
4. compares the routes' PDF exports with the references page by page, and
   the saved files of the roundtrips with the originals (text, values,
   formulas, structure, package parts), adds the install sizes and the code
   size, and writes results/summary-office.yaml (the medians over the runs).
"""

import argparse
import difflib
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
FORGE = HERE.parents[2]                       # tom_forge/
WS = FORGE.parent                             # the workspace folder
IDEA = WS / "_ai/quests/tom_forge/ideas/office_and_pdf_integration_prototype"
SAMPLES = IDEA / "samples/files"
RESULTS = IDEA / "evaluation/results"
WORK = WS / "ztmp/office_evaluation_work"
SOFFICE = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
ROUTES = ["lok", "zetaoffice"]
CORE = ["letter.docx", "letter.odt", "report.docx", "report.odt",
        "sheet.xlsx", "sheet.ods", "deck.pptx", "deck.odp"]
OLDER = {"report.doc": "report.docx", "sheet.xls": "sheet.xlsx",
         "deck.ppt": "deck.pptx"}
FIDELITY_PAGES = 3
SCALE = 1.5          # pixels per point of the fidelity renders (108 dpi)
EDIT_WORD = "EVALEDIT"
KIND = {"docx": "text", "odt": "text", "doc": "text", "rtf": "text",
        "xlsx": "sheet", "ods": "sheet", "xls": "sheet",
        "pptx": "slides", "odp": "slides", "ppt": "slides"}
ODF = {"text": "odt", "sheet": "ods", "slides": "odp"}


def run(cmd, **kw):
    print("$", " ".join(str(c) for c in cmd), flush=True)
    return subprocess.run([str(c) for c in cmd], **kw)


# ------------------------------------------------------------------- YAML

def scalar(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return f"{v:.3f}" if v == v else ".nan"
    s = str(v)
    if (re.fullmatch(r"[A-Za-z0-9_./ ()%+-]*", s) and s and s.strip() == s
            and not re.fullmatch(r"(true|false|null|yes|no|on|off|[0-9.+-]+)",
                                 s, re.I)):
        return s
    return json.dumps(s, ensure_ascii=False)


def yaml(v, indent=0):
    pad = " " * indent
    out = []
    if isinstance(v, dict):
        for k, child in v.items():
            if isinstance(child, (dict, list)) and child:
                out.append(f"{pad}{scalar(k)}:")
                out.append(yaml(child, indent + 2))
            elif isinstance(child, dict):
                out.append(f"{pad}{scalar(k)}: {{}}")
            elif isinstance(child, list):
                out.append(f"{pad}{scalar(k)}: []")
            else:
                out.append(f"{pad}{scalar(k)}: {scalar(child)}")
    elif isinstance(v, list):
        for item in v:
            if isinstance(item, dict) and item:
                lines = yaml(item, 0).split("\n")
                out.append(f"{pad}- {lines[0]}")
                out.extend(f"{pad}  {line}" for line in lines[1:])
            else:
                out.append(f"{pad}- {scalar(item)}")
    else:
        out.append(f"{pad}{scalar(v)}")
    return "\n".join(out)


def append_section(route, n, name, value):
    """Adds `name:` to results/<route>/run-<n>.yaml (replacing an older one)."""
    path = RESULTS / route / f"run-{n}.yaml"
    if not path.exists():
        return
    text = path.read_text()
    text = re.sub(rf"\n{re.escape(name)}:.*?(?=\n[A-Za-z_][\w ]*:|\Z)", "",
                  text, flags=re.S)
    path.write_text(text.rstrip("\n") + "\n" + yaml({name: value}) + "\n")


# --------------------------------------------------------------- the tools

def pdfkit(*args):
    r = subprocess.run([str(WORK / "pdfkit_tool"), *map(str, args)],
                       capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f"pdfkit_tool {args[0]}: {r.stderr.strip()}")
    return [l for l in r.stdout.splitlines()
            if l.strip() and not l.startswith("CoreGraphics")]


def soffice(args, timeout=300):
    profile = (WORK / "lo-profile").as_uri()
    return run([SOFFICE, f"-env:UserInstallation={profile}", "--headless",
                *args], capture_output=True, text=True, timeout=timeout)


def convert(src, fmt, outdir):
    """Desktop LibreOffice's conversion of src into outdir; the new file."""
    outdir.mkdir(parents=True, exist_ok=True)
    try:
        soffice(["--convert-to", fmt, "--outdir", outdir, src])
    except subprocess.TimeoutExpired:
        return None
    ext = fmt.split(":")[0]
    found = sorted(outdir.glob(f"{Path(src).stem}*.{ext}"))
    return found[0] if found else None


def screen_locked():
    r = subprocess.run(
        ["swift", "-e", "import CoreGraphics; let d = "
         "CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]; "
         "print((d[\"CGSSessionScreenIsLocked\"] as? Int ?? 0) == 1)"],
        capture_output=True, text=True)
    return r.stdout.strip() == "true"


# -------------------------------------------------------------- preparing

def prepare_older():
    out = WORK / "older"
    for name, src in OLDER.items():
        if (out / name).exists():
            continue
        made = convert(SAMPLES / src, name.split(".")[1], out)
        print(f"older format {name}: {'made' if made else 'FAILED'}")


MS_APPS = {
    "text": ("Microsoft Word", "com.microsoft.Word", """
tell application "Microsoft Word"
  open POSIX file "{src}"
  delay 3
  save as active document file name "{out}" file format format PDF
  close window 1 saving no
end tell"""),
    "sheet": ("Microsoft Excel", "com.microsoft.Excel", """
tell application "Microsoft Excel"
  open POSIX file "{src}"
  delay 3
  save workbook as active workbook filename "{out}" file format PDF file format
  close active workbook saving no
end tell"""),
    "slides": ("Microsoft PowerPoint", "com.microsoft.Powerpoint", """
tell application "Microsoft PowerPoint"
  open POSIX file "{src}"
  delay 4
  save active presentation in POSIX file "{out}" as save as PDF
  close active presentation saving no
end tell"""),
}


def references():
    """The fidelity references of every core file: desktop LibreOffice's
    PDF export, Quick Look's rendering, Microsoft Office's PDF export."""
    status = {}
    ref = WORK / "references"
    for name in CORE:
        kind = KIND[name.split(".")[1]]
        entry = {}
        lo = convert(SAMPLES / name, "pdf", ref / "libreoffice" / name)
        entry["libreoffice"] = "ok" if lo else "failed"
        ql = ref / "quicklook"
        ql.mkdir(parents=True, exist_ok=True)
        try:
            run(["qlmanage", "-t", "-s", "1400", "-o", ql, SAMPLES / name],
                capture_output=True, timeout=60)
        except subprocess.TimeoutExpired:
            subprocess.run(["pkill", "-f", "qlmanage"])
        entry["quicklook"] = "ok" if (ql / f"{name}.png").exists() else "failed"
        app, bundle, script = MS_APPS[kind]
        if name.endswith(".ods"):
            # Excel opens an ODS file behind a modal dialog, which blocks the
            # automation (and Excel) until a person answers it.
            entry["msoffice"] = ("not exported: Excel shows a modal dialog for "
                                 "ODS files")
            status[name] = entry
            continue
        box = Path.home() / f"Library/Containers/{bundle}/Data/tom_eval"
        box.mkdir(parents=True, exist_ok=True)
        src = box / name
        shutil.copy(SAMPLES / name, src)
        out = box / f"{name}.pdf"
        out.unlink(missing_ok=True)
        try:
            r = run(["osascript", "-e", script.format(src=src, out=out)],
                    capture_output=True, text=True, timeout=180)
            err = r.stderr.strip()
        except subprocess.TimeoutExpired:
            err = "timed out"
        target = ref / "msoffice" / f"{name}.pdf"
        target.parent.mkdir(parents=True, exist_ok=True)
        if out.exists():
            shutil.copy(out, target)
            entry["msoffice"] = f"ok ({app})"
        else:
            entry["msoffice"] = f"failed ({app}: {err})"
        status[name] = entry
    for app, _, _ in MS_APPS.values():
        try:
            run(["osascript", "-e",
                 f'tell application "{app}" to quit saving no'],
                capture_output=True, timeout=60)
        except subprocess.TimeoutExpired:
            pass
    for _, bundle, _ in MS_APPS.values():
        shutil.rmtree(Path.home() / f"Library/Containers/{bundle}/Data/tom_eval",
                      ignore_errors=True)
    (WORK / "references.json").write_text(json.dumps(status, indent=1))
    return status


# ------------------------------------------------------------------- runs

def drive(n, flutter, commit, minutes, only=""):
    work = WORK / f"run-{n}"
    work.mkdir(parents=True, exist_ok=True)
    defines = {
        "EVAL_SAMPLES": SAMPLES, "EVAL_RESULTS": RESULTS, "EVAL_WORK": work,
        "EVAL_PDFKIT": WORK / "pdfkit_tool", "EVAL_RUN": n,
        "EVAL_FORGE_COMMIT": commit, "EVAL_FLUTTER": flutter,
        "EVAL_EDIT_MINUTES": minutes, "EVAL_ONLY": only,
    }
    cmd = ["flutter", "drive", "--profile", "-d", "macos",
           "--driver", "test_driver/integration_test.dart",
           "--target", "integration_test/office_routes_test.dart",
           ] + [f"--dart-define={k}={v}" for k, v in defines.items()]
    log = WORK / f"drive-run-{n}.log"
    with open(log, "w") as f:
        r = run(cmd, cwd=HERE, stdout=f, stderr=subprocess.STDOUT,
                timeout=4 * 3600)
    print(f"run {n}: exit {r.returncode}, log {log}", flush=True)
    return r.returncode


def flutter_version():
    r = subprocess.run(["flutter", "--version", "--machine"],
                       capture_output=True, text=True)
    try:
        v = json.loads(r.stdout[r.stdout.index("{"):])
        return f"{v['frameworkVersion']} (Dart {v['dartSdkVersion']})"
    except Exception:
        return "?"


def forge_commit():
    r = subprocess.run(["git", "-C", FORGE, "rev-parse", "--short", "HEAD"],
                       capture_output=True, text=True)
    return r.stdout.strip()


# ---------------------------------------------------------------- fidelity

def verdict(ratio):
    return ("identical" if ratio < 0.005 else "minor" if ratio < 0.05
            else "major")


def worse(a, b):
    order = ["identical", "minor", "major", "fails to open"]
    return a if order.index(a) >= order.index(b) else b


def pages_of(pdf):
    out = pdfkit("opens", pdf)[0].split()
    return int(out[1]) if out[0] == "ok" else 0


def diff(a, b, marked=None):
    out = pdfkit("diff", a, b, *([marked] if marked else []))[0].split()
    return float(out[0])


def fidelity(route):
    """The route's PDF export against the references, page by page."""
    images = WORK / "fidelity-images" / route
    images.mkdir(parents=True, exist_ok=True)
    shots = RESULTS / route / "screenshots" / "fidelity"
    shots.mkdir(parents=True, exist_ok=True)
    ref = WORK / "references"
    result = {}
    for name in CORE:
        pdf = WORK / "fidelity" / route / f"{name}.pdf"
        if not pdf.exists():
            result[name] = {"verdict": "fails to open",
                            "reason": "the route exported no PDF"}
            continue
        lo = next((ref / "libreoffice" / name).glob("*.pdf"), None)
        ms = ref / "msoffice" / f"{name}.pdf"
        ql = ref / "quicklook" / f"{name}.png"
        n = pages_of(pdf)
        entry = {"route_pages": n,
                 "libreoffice_pages": pages_of(lo) if lo else None,
                 "msoffice_pages": pages_of(ms) if ms.exists() else None}
        pages = []
        v_lo, v_ms = "identical", "identical"
        for k in range(min(FIDELITY_PAGES, n)):
            w, h = (int(x) for x in pdfkit("size", pdf, k)[0].split())
            w, h = round(w * SCALE), round(h * SCALE)
            mine = images / f"{name}-{k}.png"
            pdfkit("render", pdf, k, w, h, mine)
            page = {"page": k + 1}
            for label, other in (("libreoffice", lo), ("msoffice", ms)):
                if not other or not Path(other).exists() or pages_of(other) <= k:
                    page[label] = "no page"
                    continue
                theirs = images / f"{name}-{k}-{label}.png"
                pdfkit("render", other, k, w, h, theirs)
                marked = images / f"{name}-{k}-{label}-diff.png"
                ratio = diff(mine, theirs, marked)
                page[label] = {"differing": round(ratio, 4),
                               "verdict": verdict(ratio)}
                if verdict(ratio) == "major":
                    shutil.copy(marked, shots / f"{name}-p{k + 1}-vs-{label}.png")
                    shutil.copy(mine, shots / f"{name}-p{k + 1}-route.png")
                if label == "libreoffice":
                    v_lo = worse(v_lo, verdict(ratio))
                else:
                    v_ms = worse(v_ms, verdict(ratio))
            if k == 0 and ql.exists():
                ratio = diff(mine, ql)
                page["quicklook"] = {"differing": round(ratio, 4),
                                     "verdict": verdict(ratio)}
            pages.append(page)
        entry["pages"] = pages
        entry["verdict_against_libreoffice"] = v_lo
        entry["verdict_against_msoffice"] = (
            v_ms if ms.exists() else "no reference")
        # Do the references agree (page 1)?
        if lo and ms.exists() and n:
            a = images / f"{name}-0-libreoffice.png"
            b = images / f"{name}-0-msoffice.png"
            if a.exists() and b.exists():
                agree = verdict(diff(a, b))
                entry["references_agree"] = agree != "major"
                if agree == "major":
                    entry["note"] = ("desktop LibreOffice and Microsoft Office "
                                     "disagree on page 1: no single reference, "
                                     "the verdict is the person's")
        result[name] = entry
    result["method"] = (
        f"the route's own PDF export (its layout engine), the first "
        f"{FIDELITY_PAGES} pages rendered by PDFKit at {SCALE} px/pt, against "
        "desktop LibreOffice's and Microsoft Office's PDF exports rendered "
        "the same way and against Quick Look's page 1; differing = the share "
        "of pixels differing by over 40 of 255 with no match within one "
        "pixel; identical < 0.5 %, minor < 5 %, major above (the human "
        "verdict per file is the report's)")
    return result


# --------------------------------------------------------------- roundtrip

def odf_counts(path, kind, tmp):
    """Counts and text of path read through its ODF form (desktop
    LibreOffice converts the other formats)."""
    ext = path.suffix[1:]
    odf = path if ext == ODF[kind] else convert(path, ODF[kind], tmp)
    if odf is None:
        return None
    with zipfile.ZipFile(odf) as z:
        content = z.read("content.xml").decode("utf-8", "replace")
        styles = (z.read("styles.xml").decode("utf-8", "replace")
                  if "styles.xml" in z.namelist() else "")
    count = lambda tag: len(re.findall(rf"<{tag}[\s>/]", content))
    c = {"images": count("draw:image"), "comments": count("office:annotation")}
    if kind == "text":
        c.update(paragraphs=count("text:p") + count("text:h"),
                 tables=count("table:table"),
                 tracked_changes=count("text:changed-region"))
    elif kind == "sheet":
        c.update(sheets=count("table:table"),
                 formulas=len(re.findall(r'table:formula="', content)))
    else:
        c.update(slides=count("draw:page"),
                 notes=len(re.findall(r"<presentation:notes", content)),
                 masters=len(re.findall(r"<style:master-page", styles)))
    formulas = re.findall(r'table:formula="([^"]*)"', content)
    words = re.sub(r"<[^>]+>", " ", content)
    return c, formulas, words


def text_lines(path, kind, tmp):
    """The text (documents, slides) or values of every sheet (CSV)."""
    if kind == "sheet":
        out = tmp / f"csv-{path.name}"
        convert(path, "csv:Text - txt - csv (StarCalc):44,34,76,1,,0,false,"
                "true,false,false,false,-1", out)
        lines = []
        for f in sorted(out.glob("*.csv")):
            lines += [f"[{f.stem.split('-', 1)[-1]}] {l}"
                      for l in f.read_text(errors="replace").splitlines()]
        return lines
    if kind == "text":
        txt = convert(path, "txt:Text (encoded):UTF8", tmp / f"txt-{path.name}")
        return txt.read_text(errors="replace").splitlines() if txt else []
    counts = odf_counts(path, kind, tmp / f"odp-{path.name}")
    return [] if counts is None else [w for w in counts[2].split() if w]


def parts(path):
    try:
        with zipfile.ZipFile(path) as z:
            return sorted(n for n in z.namelist()
                          if not n.startswith("Thumbnails/"))
    except zipfile.BadZipFile:
        return None


def compare(original, saved, kind, edited, tmp):
    entry = {}
    a, b = text_lines(original, kind, tmp), text_lines(saved, kind, tmp)
    if kind == "slides":
        lost = sorted(set(a) - set(b))
        added = sorted(set(b) - set(a))
    else:
        d = list(difflib.ndiff(a, b))
        lost = [l[2:] for l in d if l.startswith("- ")]
        added = [l[2:] for l in d if l.startswith("+ ")]
    if edited:
        has_edit = any(EDIT_WORD in l for l in added) or any(
            EDIT_WORD in l for l in b)
        entry["the_edit_is_there"] = has_edit
        changed_by_edit = [l for l in added if EDIT_WORD in l]
        # The line the word went into: its old form counts as edited.
        stripped = {l.replace(f"{EDIT_WORD} ", "").replace(EDIT_WORD, "")
                    for l in changed_by_edit}
        lost = [l for l in lost if l not in stripped]
        added = [l for l in added if EDIT_WORD not in l]
    entry["text_lost"] = len(lost)
    entry["text_added"] = len(added)
    if lost:
        entry["text_lost_examples"] = [l[:120] for l in lost[:5]]
    if added:
        entry["text_added_examples"] = [l[:120] for l in added[:5]]
    ca, cb = odf_counts(original, kind, tmp / "a"), odf_counts(saved, kind,
                                                                tmp / "b")
    if ca and cb:
        changed = {k: {"original": ca[0][k], "saved": cb[0].get(k)}
                   for k in ca[0] if ca[0][k] != cb[0].get(k)}
        entry["structure"] = changed or "unchanged"
        if kind == "sheet":
            fa, fb = ca[1], cb[1]
            entry["formulas"] = ("unchanged" if fa == fb else
                                 {"original": len(fa), "saved": len(fb),
                                  "lost_examples": [f for f in fa
                                                    if f not in fb][:5]})
    pa, pb = parts(original), parts(saved)
    if pa is not None and pb is not None:
        gone = [p for p in pa if p not in pb]
        new = [p for p in pb if p not in pa]
        entry["package_parts"] = ("unchanged" if not gone and not new else
                                  {"lost": gone[:10], "added": new[:10],
                                   "lost_count": len(gone),
                                   "added_count": len(new)})
    return entry


def roundtrips(route, n):
    folder = WORK / f"run-{n}" / "roundtrip" / route
    if not folder.exists():
        return None
    out = {}
    with tempfile.TemporaryDirectory(dir=WORK) as t:
        tmp = Path(t)
        for name in CORE + list(OLDER):
            stem, ext = name.rsplit(".", 1)
            original = (WORK / "older" / name if name in OLDER
                        else SAMPLES / name)
            entry = {}
            for variant in ("unchanged", "edited"):
                saved = folder / f"{stem}.{variant}.{ext}"
                if not saved.exists():
                    entry[variant] = "not saved (see save_roundtrip)"
                    continue
                try:
                    entry[variant] = compare(original, saved, KIND[ext],
                                             variant == "edited",
                                             tmp / f"{stem}-{ext}-{variant}")
                except Exception as e:
                    entry[variant] = f"not compared: {e}"
            out[name] = entry
    out["method"] = (
        "both saved files reopened by desktop LibreOffice: the text "
        "(documents: txt export; slides: the words of every slide), every "
        "sheet's values (CSV) and formulas, the counts of paragraphs, tables, "
        "images, comments, tracked changes, sheets, slides, notes and "
        "masters (through the ODF form), and the package's parts; the "
        "scripted edit's word is not counted as a change")
    return out


# -------------------------------------------------------- sizes and code

def du(path):
    p = Path(path)
    if not p.exists():
        return None
    if p.is_file():
        return p.stat().st_size
    return sum(f.stat().st_size for f in p.rglob("*") if f.is_file()
               and not f.is_symlink())


def code_lines(paths):
    total = 0
    for root in paths:
        for f in Path(root).rglob("*"):
            if f.suffix in (".dart", ".js") and f.is_file():
                for line in f.read_text(errors="replace").splitlines():
                    s = line.strip()
                    if s and not s.startswith("//"):
                        total += 1
    return total


def sizes_and_code():
    binaries = Path(os.environ.get("TOM_BINARY_PATH",
                                   str(Path.home() / "tac/tom_binaries/tom")))
    modules = WS / "tom_ai/modules"
    editor = modules / "tom_office_editor"
    app = FORGE / "tom_forge_app/build/macos/Build/Products"
    bundle = {}
    for mode in ("Release", "Profile"):
        a = app / mode / "tom_forge_app.app"
        if a.exists():
            bundle[mode.lower()] = du(a)
    zeta_cache = Path.home() / "Library/Caches/tom_office_editor/zetaoffice"
    lok = {
        "LibreOffice.app_bytes": du("/Applications/LibreOffice.app"),
        "tom_office_host_bytes": du(binaries / "darwin-arm64/tom_office_host"),
        "helper_library_bytes": du(binaries /
                                   "darwin-arm64/libtom_office_host_lok.dylib"),
        "installed_by": "the user (LibreOffice), the binaries layer (helper)",
    }
    zeta = {
        "cache_bytes": du(zeta_cache),
        "page_assets_bytes": du(editor / "assets/zetaoffice"),
        "download": "see run-1's download (bytes and time)",
    }
    forge = {
        "tom_forge_app_bundle_bytes": bundle or None,
        "office_packages_assets_bytes": du(editor / "assets"),
        "before_and_after": (
            "not measured: it needs a second release build of tom_forge_app "
            "without the office packages; the bundle with them is above"),
    }
    lok_code = {
        "tom_office_editor (without zetaoffice)": code_lines(
            [editor / "lib"]) - code_lines([editor / "lib/src/zetaoffice"]),
        "tom_office_protocol": code_lines([modules / "tom_office_protocol/lib"]),
        "tom_office_host (Dart)": code_lines([modules / "tom_office_host/lib",
                                              modules / "tom_office_host/bin"]),
        "tom_forge_office_editors (LibreOfficeKit editor)": code_lines(
            [FORGE / "tom_forge_office_editors/lib"]) - code_lines(
            [FORGE / "tom_forge_office_editors/lib/src/forge_zetaoffice_editor.dart"]),
    }
    zeta_code = {
        "tom_office_editor/lib/src/zetaoffice (Dart)": code_lines(
            [editor / "lib/src/zetaoffice"]),
        "the page (host.js, office_thread.js)": code_lines(
            [editor / "assets/zetaoffice/host.js",
             editor / "assets/zetaoffice/office_thread.js"]),
        "tom_forge_office_editors (ZetaOffice editor)": code_lines(
            [FORGE / "tom_forge_office_editors/lib/src/forge_zetaoffice_editor.dart"]),
    }
    for c in (lok_code, zeta_code):
        c["total"] = sum(v for v in c.values() if isinstance(v, int))
        c["counted"] = "non-blank lines not starting with // (no cloc on mbp)"
    return ({"route": lok, "forge": forge}, lok_code,
            {"route": zeta, "forge": forge}, zeta_code)


# ---------------------------------------------------------------- summary

def summary(n_runs):
    def med(xs):
        xs = [x for x in xs if isinstance(x, (int, float))]
        return round(statistics.median(xs), 1) if xs else None

    out = {}
    for route in ROUTES:
        runs = []
        for n in range(1, n_runs + 1):
            p = WORK / f"run-{n}" / f"{route}-run-{n}.json"
            if p.exists():
                runs.append(json.loads(p.read_text()))
        if not runs:
            continue
        s = {"runs": len(runs)}
        opens = {}
        for name in runs[0].get("open_ms", {}) or {}:
            if not isinstance(runs[0]["open_ms"].get(name), dict):
                continue
            opens[name] = {k: med([r["open_ms"][name].get(k) for r in runs
                                   if isinstance(r.get("open_ms", {}).get(name),
                                                 dict)])
                           for k in ("open", "first_tile")}
        s["open_ms"] = opens
        lat = {}
        for name, v in (runs[0].get("editing_latency") or {}).items():
            if not isinstance(v, dict):
                continue
            key = ("key_to_frame_ms" if "key_to_frame_ms" in v
                   else "keydown_to_next_frames_ms")
            if key in v:
                lat[name] = {
                    "median": med([r["editing_latency"][name][key]["median"]
                                   for r in runs]),
                    "p95": med([r["editing_latency"][name][key]["p95"]
                                for r in runs]),
                }
        s["editing_latency_ms"] = lat
        s["jank_share"] = {
            name: med([r["scrolling"][name].get("jank_share") for r in runs
                       if isinstance(r.get("scrolling", {}).get(name), dict)])
            for name, v in (runs[0].get("scrolling") or {}).items()
            if isinstance(v, dict) and "jank_share" in v}
        s["memory_total_mb_after_open"] = {
            name: med([r["memory"][name]["after_open_mb"]["total_mb"]
                       for r in runs
                       if isinstance(r.get("memory", {}).get(name), dict)])
            for name, v in (runs[0].get("memory") or {}).items()
            if isinstance(v, dict)}
        out[route] = s
    RESULTS.mkdir(parents=True, exist_ok=True)
    (RESULTS / "summary-office.yaml").write_text(
        "# Medians over the runs of the office routes' timed measures\n"
        "# (officeproto31g); the raw results are <route>/run-<n>.yaml.\n"
        + yaml(out) + "\n")


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--first-run", type=int, default=1,
                    help="drive the runs from this one to --runs (a run "
                         "repeated); the comparison covers all of them")
    ap.add_argument("--skip-drive", action="store_true")
    ap.add_argument("--skip-references", action="store_true")
    ap.add_argument("--edit-minutes", type=int, default=10)
    ap.add_argument("--allow-locked-screen", action="store_true")
    ap.add_argument("--only", default="",
                    help="the routes to drive (lok, zetaoffice), comma-separated")
    a = ap.parse_args()
    if not a.skip_drive and not a.allow_locked_screen and screen_locked():
        sys.exit("the screen is locked: the runs would take no frame timings")
    if not SAMPLES.is_dir():
        sys.exit(f"no samples at {SAMPLES}: run samples/fetch_samples.py first")
    if not a.skip_drive and not a.skip_references and WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True, exist_ok=True)
    if run(["swiftc", "-O", HERE / "pdfkit_tool.swift", "-o",
            WORK / "pdfkit_tool"], capture_output=True).returncode:
        sys.exit("pdfkit_tool did not compile")
    prepare_older()
    if not a.skip_references:
        print(json.dumps(references(), indent=1))
    run(["flutter", "pub", "get"], cwd=HERE, check=True)
    failed = 0
    if not a.skip_drive:
        flutter, commit = flutter_version(), forge_commit()
        for n in range(a.first_run, a.runs + 1):
            failed += drive(n, flutter, commit, a.edit_minutes, a.only) != 0
    refs = json.loads((WORK / "references.json").read_text()) if (
        WORK / "references.json").exists() else {}
    lok_size, lok_code, zeta_size, zeta_code = sizes_and_code()
    for route in ROUTES:
        fid = fidelity(route)
        fid["references"] = refs
        append_section(route, 1, "fidelity", fid)
        append_section(route, 1, "install_size",
                       lok_size if route == "lok" else zeta_size)
        append_section(route, 1, "ui_code_lines",
                       lok_code if route == "lok" else zeta_code)
        for n in range(1, a.runs + 1):
            rt = roundtrips(route, n)
            if rt is not None:
                append_section(route, n, "save_roundtrip_comparison", rt)
    summary(a.runs)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
