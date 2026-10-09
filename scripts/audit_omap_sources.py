#!/usr/bin/env python3
"""Audit QEMU OMAP2420 old source versus UTM-pinned modern source (no ROMs)."""
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

LEGACY_REPO, LEGACY_REF = "qemu/qemu", "v9.1.0"
CURRENT_REPO, CURRENT_REF = "utmapp/qemu", "v10.0.12-utm"
OMAP_PATHS = [
    "hw/arm/nseries.c", "hw/arm/omap1.c", "hw/arm/omap2.c", "hw/arm/omap_sx1.c",
    "hw/char/omap_uart.c", "hw/display/omap_dss.c", "hw/display/omap_lcdc.c",
    "hw/dma/omap_dma.c", "hw/gpio/omap_gpio.c", "hw/i2c/omap_i2c.c",
    "hw/intc/omap_intc.c", "hw/misc/cbus.c", "hw/misc/omap_clk.c",
    "hw/misc/omap_gpmc.c", "hw/misc/omap_l4.c", "hw/misc/omap_sdrc.c",
    "hw/misc/omap_tap.c", "hw/sd/omap_mmc.c", "hw/ssi/omap_spi.c",
    "hw/timer/omap_gptimer.c", "hw/timer/omap_synctimer.c",
    "include/hw/arm/omap.h", "include/hw/misc/cbus.h",
]
EXPECTED_MISSING = {
    "hw/arm/nseries.c", "hw/arm/omap2.c", "hw/display/omap_dss.c",
    "hw/misc/cbus.c", "hw/misc/omap_gpmc.c", "hw/misc/omap_l4.c",
    "hw/misc/omap_sdrc.c", "hw/misc/omap_tap.c", "hw/ssi/omap_spi.c",
    "hw/timer/omap_gptimer.c", "hw/timer/omap_synctimer.c", "include/hw/misc/cbus.h",
}

def get_api(path):
    headers = {"Accept": "application/vnd.github+json",
               "User-Agent": "nokia-omap2420-source-audit",
               "X-GitHub-Api-Version": "2022-11-28"}
    if os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    req = urllib.request.Request("https://api.github.com/" + path, headers=headers)
    with urllib.request.urlopen(req, timeout=90) as res:
        return json.load(res)

def list_tree(repo, ref):
    result = get_api(f"repos/{repo}/git/trees/{ref}?recursive=1")
    if result.get("truncated"):
        raise RuntimeError("GitHub tree truncated: " + repo)
    return {entry["path"]: entry for entry in result["tree"]}

def read_remote(repo, ref, path):
    safe_ref = urllib.parse.quote(ref, safe="")
    obj = get_api(f"repos/{repo}/contents/{path}?ref={safe_ref}")
    if obj.get("encoding") != "base64":
        raise RuntimeError("Unexpected content encoding " + repo + ":" + path)
    return base64.b64decode(obj["content"]).decode("utf-8")

def require(ok, msg):
    if not ok:
        raise RuntimeError("AUDIT FAIL: " + msg)

def main(utm_dir, out_dir):
    sources = (utm_dir / "patches/sources").read_text()
    build = (utm_dir / "scripts/build_dependencies.sh").read_text()
    require("utmapp/qemu/releases/download/v10.0.12-utm" in sources,
            "UTM version pin no longer matches this audit")
    m = re.search(r"--target-list=([a-z0-9,-]+)", build)
    require(m is not None, "Missing iOS TCI --target-list")
    targets = m.group(1).split(",")
    require("aarch64-softmmu" in targets and "arm-softmmu" not in targets,
            "ARM target list changed; re-evaluate source audit")

    old, current = list_tree(LEGACY_REPO, LEGACY_REF), list_tree(CURRENT_REPO, CURRENT_REF)
    require(all(p in old for p in OMAP_PATHS), "9.1.0 reference file missing")
    missing = sorted(set(OMAP_PATHS) - current.keys())
    require(set(missing) == EXPECTED_MISSING, "Missing list differs from expected")

    old_kcfg = read_remote(LEGACY_REPO, LEGACY_REF, "hw/arm/Kconfig")
    new_kcfg = read_remote(CURRENT_REPO, CURRENT_REF, "hw/arm/Kconfig")
    old_meson = read_remote(LEGACY_REPO, LEGACY_REF, "hw/arm/meson.build")
    new_meson = read_remote(CURRENT_REPO, CURRENT_REF, "hw/arm/meson.build")
    cpu32 = read_remote(CURRENT_REPO, CURRENT_REF, "target/arm/tcg/cpu32.c")
    require("config NSERIES" in old_kcfg and "config NSERIES" not in new_kcfg,
            "Unexpected Nseries Kconfig status")
    require("files('omap2.c')" in old_meson and "files('omap2.c')" not in new_meson,
            "Unexpected OMAP2 meson status")
    require("config OMAP" in new_kcfg and "files('omap1.c')" in new_meson,
            "Existing OMAP1 compatibility not confirmed")
    require('"arm1136-r2"' in cpu32 and '"arm1136"' in cpu32,
            "Modern ARM1136 CPU definitions not found")

    entries = [{"path": p, "in_legacy": True, "in_current": p in current,
                "sha_legacy": old[p]["sha"],
                "sha_current": current[p]["sha"] if p in current else None}
               for p in OMAP_PATHS]
    report = {
        "status": "PASS", "read_only": True, "nokia_rom_included": False,
        "legacy": f"{LEGACY_REPO}@{LEGACY_REF}",
        "current": f"{CURRENT_REPO}@{CURRENT_REF}",
        "total_relevant": len(entries),
        "missing_count": len(missing), "missing": missing,
        "surviving_cpu": ["arm1136", "arm1136-r2"],
        "ios_tci_targets": targets, "ios_arm32_engine_present": False,
        "somac": "OMAP2420 source absent in UTM current QEMU; N95 board not implemented",
        "source_files": entries
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "omap2-source-audit.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    md = [
        "# OMAP2420 source inventory for Nokia N95",
        "", "Source audit: PASS; no QEMU binaries or IPA produced.",
        "- Historical upstream QEMU: " + report["legacy"],
        "- Current UTM QEMU: " + report["current"],
        "- OMAP/Nseries paths missing: " + str(len(missing)) + "/23",
        "- ARM1136 CPU model still exists in modern QEMU source.",
        "- Existing iOS TCI target list lacks ARM32 arm-softmmu.",
        "", "| File | QEMU 9.1 | UTM QEMU 10 |", "|---|---|---|"
    ]
    for row in entries:
        md.append("| " + row["path"] + " | Yes | " +
                  ("Yes |" if row["in_current"] else "**No** |"))
    md.extend(["", "## Next engineering gate",
               "Build an isolated ARM32 QEMU system engine via TCI; smoke-test",
               "open ARM32 guest before porting OMAP2420 SoC/MMIO; keep Lite v8 unchanged."])
    (out_dir / "omap2-source-audit.md").write_text("\n".join(md) + "\n")
    print("OMAP_SOURCE_AUDIT=PASS")
    print(f"MISSING={len(missing)}/{len(entries)}")
    print("CPU_ARM1136_SOURCE=PASS")
    print("ARM_SOFTMMU_IOS=ABSENT_IN_BASELINE")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: audit_omap_sources.py <pinned-utm-dir> <out-dir>")
    try:
        main(Path(sys.argv[1]), Path(sys.argv[2]))
    except Exception as e:
        print("OMAP_SOURCE_AUDIT=FAIL " + str(e), file=sys.stderr)
        raise SystemExit(2)
