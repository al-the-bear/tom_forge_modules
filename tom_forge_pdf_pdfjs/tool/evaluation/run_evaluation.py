#!/usr/bin/env python3
# Copyright (c) 2026 Peter Nicolai Alexis Kyaw
# SPDX-License-Identifier: BSD-3-Clause
"""The PDF routes' evaluation (office/PDF prototype, part-evaluation), run by
hand on mbp from this folder:

    python3 run_evaluation.py            # crash probes, then three runs
    python3 run_evaluation.py --runs 1   # one run
    python3 run_evaluation.py --skip-probes

1. Compiles pdfkit_tool.swift (macOS Preview's renderer, PDFKit).
2. The PDFium route's crash isolation: every damaged-* PDF of the sample set,
   pdf-encrypted, and seeded corruptions of pdf-text, each opened in a
   `flutter test` process of its own (test/crash_probe_test.dart), since
   PDFium runs inside Forge's process.
3. `flutter drive --profile` of integration_test/pdf_routes_test.dart once
   per run: the PDFium route, then pdf.js in each mode.
4. results/summary.yaml: the medians over the runs of every timed measure,
   and results/<route>/screenshots/: one page per sample from run 1 (the
   route's rendering, Preview's and the marked difference) as small JPEGs.
   `--skip-drive` makes these two again from the scratch folder.

Results go to evaluation/results/ in the idea's folder; the scratch folder is
ztmp/pdf_evaluation_work/ of the workspace (deleted at the start of a full
run).
Standard library only.
"""

import argparse
import json
import os
import random
import re
import shutil
import statistics
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WORKSPACE = HERE.parents[3]  # tool/evaluation -> tom_forge_pdf_pdfjs -> tom_forge -> workspace
IDEA = WORKSPACE / "_ai/quests/tom_forge/ideas/office_and_pdf_integration_prototype"
SAMPLES = IDEA / "samples/files"
RESULTS = IDEA / "evaluation/results"
WORK = WORKSPACE / "ztmp/pdf_evaluation_work"
ROUTES = ["pdfium", "pdfjs-integrated", "pdfjs-full", "pdfjs-components"]


def run(cmd, **kw):
    print("$ " + " ".join(str(c) for c in cmd), flush=True)
    return subprocess.run(cmd, **kw)


def yaml_scalar(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return f"{v:.3f}"
    s = str(v)
    if re.fullmatch(r"[A-Za-z0-9_./ ()%+-]+", s) and not re.fullmatch(
        r"(true|false|null|yes|no|on|off|[0-9.+-]+)", s, re.I
    ) and s.strip() == s:
        return s
    return json.dumps(s)


def to_yaml(v, indent=0):
    pad = " " * indent
    out = []
    if isinstance(v, dict):
        for k, x in v.items():
            if isinstance(x, (dict, list)) and x:
                out.append(f"{pad}{yaml_scalar(k)}:")
                out.append(to_yaml(x, indent + 2))
            else:
                empty = "{}" if isinstance(x, dict) else "[]" if isinstance(x, list) else yaml_scalar(x)
                out.append(f"{pad}{yaml_scalar(k)}: {empty}")
    elif isinstance(v, list):
        for x in v:
            if isinstance(x, (dict, list)) and x:
                lines = to_yaml(x, 0).split("\n")
                out.append(f"{pad}- {lines[0]}")
                out.extend(f"{pad}  {line}" for line in lines[1:])
            else:
                out.append(f"{pad}- {yaml_scalar(x)}")
    else:
        out.append(pad + yaml_scalar(v))
    return "\n".join(out)


def write_yaml(path, header, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(header + to_yaml(value) + "\n")
    print(f"wrote {path}")


def flutter_version():
    r = subprocess.run(["flutter", "--version", "--machine"], capture_output=True, text=True)
    try:
        v = json.loads(r.stdout[r.stdout.index("{"):])
        return f"{v['frameworkVersion']} (Dart {v['dartSdkVersion']})"
    except (ValueError, KeyError):
        return "?"


def forge_commit():
    r = subprocess.run(
        ["git", "-C", str(WORKSPACE / "tom_forge"), "rev-parse", "--short", "HEAD"],
        capture_output=True, text=True,
    )
    return r.stdout.strip() or "?"


# --------------------------------------------------------------- probes


def corruptions(work):
    """Seeded corruptions of pdf-text: 10 truncations, 10 byte-flip runs."""
    source = (SAMPLES / "pdf-text.pdf").read_bytes()
    rng = random.Random(23)
    made = []
    for i in range(10):
        cut = int(len(source) * (0.05 + 0.09 * i))
        p = work / f"corrupt-truncated-{i + 1:02d}.pdf"
        p.write_bytes(source[:cut])
        made.append((p, f"pdf-text truncated to {cut} of {len(source)} bytes"))
    for i in range(10):
        data = bytearray(source)
        offsets = sorted(rng.randrange(1024, len(data)) for _ in range(64))
        for o in offsets:
            data[o] = rng.randrange(256)
        p = work / f"corrupt-flipped-{i + 1:02d}.pdf"
        p.write_bytes(bytes(data))
        made.append((p, "pdf-text with 64 bytes set to random values (seed 23)"))
    return made


def probe(path, password=None):
    env = dict(os.environ, EVAL_PROBE_FILE=str(path))
    if password:
        env["EVAL_PROBE_PASSWORD"] = password
    r = run(
        ["flutter", "test", "test/crash_probe_test.dart", "--no-pub"],
        cwd=HERE, env=env, capture_output=True, text=True, timeout=600,
    )
    out = r.stdout + r.stderr
    lines = [l.strip() for l in out.splitlines() if l.strip().startswith("PROBE")]
    done = "PROBE done" in lines
    opened = next((l for l in lines if l.startswith("PROBE open")), None)
    pages = sum(1 for l in lines if l.startswith("PROBE page"))
    if done:
        outcome = "opened" if opened and "open ok" in opened else "refused with a message"
    elif opened is None:
        outcome = "crashed while opening"
    else:
        outcome = "crashed after opening"
    return {
        "outcome": outcome,
        "forge_would_survive": done,
        "open": (opened or "").replace("PROBE ", ""),
        "pages_rendered": pages,
        "exit_code": r.returncode,
        **({} if done else {"tail": out.strip().splitlines()[-3:]}),
    }


def probes():
    work = WORK / "probes"
    work.mkdir(parents=True, exist_ok=True)
    files = {}
    for p in sorted(SAMPLES.glob("damaged-*.pdf")):
        files[p.name] = probe(p)
    files["pdf-encrypted.pdf (no password)"] = probe(SAMPLES / "pdf-encrypted.pdf")
    files["pdf-encrypted.pdf (its password)"] = probe(SAMPLES / "pdf-encrypted.pdf", "ELXRTQWS")
    derived = {}
    for p, how in corruptions(work):
        r = probe(p)
        r["made"] = how
        derived[p.name] = r
    def share(d):
        n = len(d)
        crashed = sum(1 for v in d.values() if not v["forge_would_survive"])
        return {"files": n, "crashed": crashed, "share": crashed / n if n else 0.0}
    damaged = {k: v for k, v in files.items() if k.startswith("damaged-")}
    write_yaml(
        RESULTS / "pdfium/crash-isolation.yaml",
        "# The PDFium route's crash isolation (officeproto23): each file opened,\n"
        "# rendered and read (up to 20 pages) in a flutter test process of its\n"
        "# own; a crash there is a crash of Forge, which runs PDFium in-process.\n",
        {
            "method": "test/crash_probe_test.dart per file; crashed = the process "
                      "ended before PROBE done",
            "manifest_damaged_share": share(damaged),
            "derived_corruptions_share": share(derived),
            "files": files,
            "derived_corruptions": derived,
        },
    )


# ----------------------------------------------------------------- runs


def drive(n, pdfkit, flutter, commit):
    work = WORK / f"run-{n}"
    work.mkdir(parents=True, exist_ok=True)
    defines = {
        "EVAL_SAMPLES": SAMPLES,
        "EVAL_RESULTS": RESULTS,
        "EVAL_WORK": work,
        "EVAL_PDFKIT": pdfkit,
        "EVAL_RUN": n,
        "EVAL_FORGE_COMMIT": commit,
        "EVAL_FLUTTER": flutter,
    }
    cmd = [
        "flutter", "drive", "--profile", "-d", "macos",
        "--driver", "test_driver/integration_test.dart",
        "--target", "integration_test/pdf_routes_test.dart",
    ] + [f"--dart-define={k}={v}" for k, v in defines.items()]
    log = WORK / f"drive-run-{n}.log"
    with open(log, "w") as f:
        r = run(cmd, cwd=HERE, stdout=f, stderr=subprocess.STDOUT, timeout=4 * 3600)
    print(f"run {n}: exit {r.returncode}, log {log}")
    return r.returncode


def collect(n_runs):
    """Medians over the runs of the timed measures, per route."""
    runs = {route: [] for route in ROUTES}
    for n in range(1, n_runs + 1):
        for route in ROUTES:
            p = WORK / f"run-{n}" / f"{route}-run-{n}.json"
            if p.exists():
                runs[route].append(json.loads(p.read_text()))
    summary = {}
    for route, results in runs.items():
        if not results:
            summary[route] = {"measured": False, "reason": "no run wrote results"}
            continue
        r = {"runs": len(results)}

        def med(path):
            vals = []
            for res in results:
                v = res
                for k in path:
                    v = v.get(k) if isinstance(v, dict) else None
                if isinstance(v, (int, float)):
                    vals.append(v)
            return statistics.median(vals) if vals else None

        r["open_ms"] = {
            s: {"open": med(["open", s, "open_ms"]), "first_page": med(["open", s, "first_page_ms"])}
            for s in results[0].get("open", {})
        }
        r["search_ms"] = {
            s: {"whole_document": med(["search", s, "whole_document_ms"]),
                "hits": med(["search", s, "hits"])}
            for s in results[0].get("search", {})
        }
        r["jank_share"] = {
            s: med(["scrolling", s, "jank_share"])
            for s in (results[0].get("scrolling") or {})
            if isinstance(results[0]["scrolling"].get(s), dict)
        }
        mem = results[0].get("memory", {})
        r["memory_mb"] = {
            s: {"app": med(["memory", s, "app_footprint_mb"]),
                "total": med(["memory", s, "total_footprint_mb"]) or med(["memory", s, "app_footprint_mb"])}
            for s in mem if isinstance(mem[s], dict) and "app_footprint_mb" in mem[s]
        }
        r["annotations_save_ms"] = med(["annotations", "saved", "save_ms"])
        summary[route] = r
    write_yaml(
        RESULTS / "summary.yaml",
        "# Medians over the runs of the PDF routes' timed measures\n"
        "# (officeproto23); the raw results are <route>/run-<n>.yaml.\n",
        summary,
    )


def screenshots():
    """One page per sample and route from run 1, as small JPEGs: the route's
    rendering, Preview's, and the marked difference (differences red,
    one-pixel shifts orange), in results/<route>/screenshots/."""
    work = WORK / "run-1"
    if not work.is_dir():
        print("no run 1 in the scratch folder: no screenshots")
        return
    keys = ["pdf-text-p1", "pdf-annot-p1", "pdf-form-p1", "pdf-scan-p1",
            "pdf-encrypted-p1", "pdf-long-p2001"]
    def jpeg(src, dst):
        dst.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "70",
                        "-Z", "700", str(src), "--out", str(dst)],
                       capture_output=True, check=True)
    for key in keys:
        previews = sorted(work.glob(f"preview-{key}-*.png"))
        if previews:
            jpeg(previews[0], RESULTS / "preview" / "screenshots" / f"{key}.jpg")
        for route in ROUTES:
            image = work / f"{route}-{key}.png"
            if not image.exists():
                continue
            out = RESULTS / route / "screenshots"
            jpeg(image, out / f"{key}.jpg")
            for other in ["preview", "pdfium"]:
                diff = work / f"{route}-{key}-vs-{other}.png"
                if diff.exists():
                    jpeg(diff, out / f"{key}-vs-{other}-diff.jpg")
    print(f"screenshots in {RESULTS}/*/screenshots")


def screen_locked():
    """Whether the screen is locked: WebKit then draws nothing in a window
    and frame timings are not those of a person watching."""
    r = subprocess.run(
        ["swift", "-e", "import CoreGraphics; let d = CGSessionCopyCurrentDictionary() "
         "as? [String: Any] ?? [:]; print((d[\"CGSSessionScreenIsLocked\"] as? Int ?? 0) == 1)"],
        capture_output=True, text=True,
    )
    return r.stdout.strip() == "true"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--skip-probes", action="store_true")
    ap.add_argument("--skip-drive", action="store_true")
    ap.add_argument("--allow-locked-screen", action="store_true",
                    help="run the drives although the screen is locked (no "
                         "frame timings, pdf.js drawn by a stand-in)")
    a = ap.parse_args()
    if not a.skip_drive and not a.allow_locked_screen and screen_locked():
        sys.exit("the screen is locked: the runs would take no frame timings "
                 "and overwrite the results; unlock it, or pass "
                 "--allow-locked-screen")
    if not SAMPLES.is_dir():
        sys.exit(f"no samples at {SAMPLES}: run samples/fetch_samples.py first")
    if not a.skip_drive and not a.skip_probes and WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True, exist_ok=True)
    pdfkit = WORK / "pdfkit_tool"
    if run(["swiftc", "-O", str(HERE / "pdfkit_tool.swift"), "-o", str(pdfkit)]).returncode:
        sys.exit("pdfkit_tool did not compile")
    run(["flutter", "pub", "get"], cwd=HERE, check=True)
    if not a.skip_probes:
        probes()
    failed = 0
    if not a.skip_drive:
        flutter, commit = flutter_version(), forge_commit()
        for n in range(1, a.runs + 1):
            failed += drive(n, pdfkit, flutter, commit) != 0
    # Also from an earlier run's scratch folder with --skip-drive.
    collect(a.runs)
    screenshots()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
