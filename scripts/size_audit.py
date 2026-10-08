#!/usr/bin/env python3
"""Read-only audit of a UTM IPA archive.

Reports ZIP-compressed size, uncompressed size, file categories and largest files.
Does not extract, delete or modify app resources.
"""
import collections
import json
import sys
import zipfile
from pathlib import Path

MiB = 1024 * 1024

def mib(x):
    return f"{x / MiB:.2f} MiB"

def analyse(path: Path):
    by_category = collections.defaultdict(lambda: {"compressed": 0, "uncompressed": 0, "files": 0})
    entries = []
    with zipfile.ZipFile(path) as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
            full = info.filename
            normalized = full.split(".app/", 1)
            if len(normalized) == 2:
                rel = normalized[1]
            else:
                rel = full
            category = rel.split("/", 1)[0] if "/" in rel else "(App root)"
            if rel.startswith("Frameworks/"):
                category = "Frameworks/" + rel.split("/")[1]
            if rel.startswith("PlugIns/") or rel.startswith("Extensions/"):
                category = rel.split("/")[0] + "/" + rel.split("/")[1]
            by_category[category]["compressed"] += info.compress_size
            by_category[category]["uncompressed"] += info.file_size
            by_category[category]["files"] += 1
            entries.append({"name": rel, "original": full, "compressed": info.compress_size, "uncompressed": info.file_size})
    entries.sort(key=lambda x: x["uncompressed"], reverse=True)
    categories = sorted(([{"name": k, **v} for k, v in by_category.items()]), key=lambda d: d["uncompressed"], reverse=True)
    return {
        "filename": path.name,
        "ipa_size_bytes": path.stat().st_size,
        "uncompressed_bytes": sum(x["uncompressed"] for x in entries),
        "compressed_member_bytes": sum(x["compressed"] for x in entries),
        "total_files": len(entries),
        "largest_files": entries[:45],
        "categories": categories,
    }

def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: size_audit.py input.ipa output-dir")
    path, outdir = Path(sys.argv[1]), Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)
    data = analyse(path)
    (outdir / "size-report.json").write_text(json.dumps(data, indent=2, ensure_ascii=False))
    md = [
        "# Nokia UTM SE v1 — size audit",
        "",
        "> Read-only inventory of the unsigned IPA. ZIP sizes can differ from installed app size.",
        "",
        f"- IPA file: `{data['filename']}`",
        f"- IPA bytes on disk: **{mib(data['ipa_size_bytes'])}**",
        f"- Uncompressed ZIP file content: **{mib(data['uncompressed_bytes'])}**",
        f"- Number of files: {data['total_files']}",
        "",
        "## Largest categories (uncompressed)",
        "",
        "| Component | Uncompressed | ZIP-compressed | Files |",
        "|:--|--:|--:|--:|",
    ]
    for x in data["categories"][:35]:
        md.append(f"| `{x['name']}` | {mib(x['uncompressed'])} | {mib(x['compressed'])} | {x['files']} |")
    md += ["", "## Largest files (uncompressed)", "", "| File | Uncompressed | ZIP-compressed |", "|:--|--:|--:|"]
    for x in data["largest_files"][:35]:
        md.append(f"| `{x['name']}` | {mib(x['uncompressed'])} | {mib(x['compressed'])} |")
    md += ["", "Do not delete dylibs/resources without dependency and runtime testing.", ""]
    (outdir / "size-report.md").write_text("\n".join(md))
    print("\n".join(md))

if __name__ == "__main__":
    main()
