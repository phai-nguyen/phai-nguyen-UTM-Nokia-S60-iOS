#!/usr/bin/env python3
"""Transfer only vetted Vietnamese resource files from device-PASS v8 to OMAP2420 v10.

Preserve every v10 executable, framework and existing VM resource byte-for-byte.
The v8 source IPA is read-only. The v10 bundle ID is independent of v8.
"""
import copy
import hashlib
import json
import plistlib
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = "Payload/UTM SE.app/"
MAIN = ROOT + "UTM SE"
INFO = ROOT + "Info.plist"
LOCALES = [
    ROOT + "vi.lproj/Localizable.strings",
    ROOT + "vi.lproj/Localizable.stringsdict",
    ROOT + "vi.lproj/InfoPlist.strings",
    ROOT + "Settings.bundle/vi.lproj/Root.strings",
]
FRAMEWORKS = ["arm", "aarch64", "i386", "x86_64", "ppc", "ppc64", "riscv64", "m68k"]

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for block in iter(lambda: fp.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()

def main(v8, v10, out, report):
    v8, v10, out, report = map(Path, (v8, v10, out, report))
    if any(a.resolve() == b.resolve() for a, b in ((v8, v10), (v8, out), (v10, out))):
        raise RuntimeError("Refusing in-place or same-source IPA modification")
    out.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(v8) as source, zipfile.ZipFile(v10) as build:
        if source.testzip() is not None or build.testzip() is not None:
            raise RuntimeError("Input IPA corrupt")
        if not all(p in source.namelist() for p in LOCALES):
            raise RuntimeError("Device-PASS v8 missing expected Vietnamese resources")
        if not all(p not in build.namelist() for p in LOCALES):
            raise RuntimeError("v10 unexpectedly already contains a Vietnamese resource")
        base8 = plistlib.loads(source.read(INFO))
        base10 = plistlib.loads(build.read(INFO))
        if base8["CFBundleIdentifier"] != "com.phai.nokias60.UTM-SE":
            raise RuntimeError("Unexpected v8 baseline identity")
        if base10["CFBundleIdentifier"] != "com.phai.nokias60.omapdiag.UTM-SE":
            raise RuntimeError("Expected isolated OMAP2420 v10 bundle ID")
        if base10["MinimumOSVersion"] != "15.0":
            raise RuntimeError("iOS minimum OS changed")
        if build.read(MAIN) == source.read(MAIN):
            raise RuntimeError("v10 app main executable unexpectedly identical to v8")
        arm_bin = ROOT + "Frameworks/qemu-arm-softmmu.framework/qemu-arm-softmmu"
        if arm_bin not in build.namelist():
            raise RuntimeError("OMAP2420 ARM32 QEMU framework not in v10 IPA")
        for cpu in FRAMEWORKS:
            member = ROOT + f"Frameworks/qemu-{cpu}-softmmu.framework/qemu-{cpu}-softmmu"
            if member not in build.namelist():
                raise RuntimeError(f"Missing QEMU engine in v10: {cpu}")
        # Independent diagnostic app label; Info.plist only is changed by this overlay.
        base10["CFBundleDisplayName"] = "UTM OMAP Diag v10"
        existing = base10.get("CFBundleLocalizations", [])
        if not isinstance(existing, list):
            raise RuntimeError("Bad CFBundleLocalizations")
        base10["CFBundleLocalizations"] = sorted(set(existing) | {"vi", "en"})
        new_info = plistlib.dumps(base10, fmt=plistlib.FMT_BINARY, sort_keys=False)
        with zipfile.ZipFile(out, "w", allowZip64=True) as result:
            for member in build.infolist():
                part = copy.copy(member)
                if member.filename == INFO:
                    result.writestr(part, new_info)
                elif member.is_dir():
                    result.writestr(part, b"")
                else:
                    with build.open(member) as inp, result.open(part, "w", force_zip64=True) as dest:
                        shutil.copyfileobj(inp, dest, 1 << 20)
            for locale in LOCALES:
                result.writestr(locale, source.read(locale), compress_type=zipfile.ZIP_DEFLATED)
    with zipfile.ZipFile(v10) as initial, zipfile.ZipFile(out) as final, zipfile.ZipFile(v8) as source:
        if final.testzip() is not None:
            raise RuntimeError("Output ZIP CRC failed")
        original_names = set(initial.namelist())
        result_names = set(final.namelist())
        if result_names - original_names != set(LOCALES) or original_names - result_names:
            raise RuntimeError("Unexpected ZIP structure change")
        for item in initial.infolist():
            name = item.filename
            if name != INFO and not item.is_dir() and initial.read(name) != final.read(name):
                raise RuntimeError(f"Changed original v10 member: {name}")
        for locale in LOCALES:
            if final.read(locale) != source.read(locale):
                raise RuntimeError(f"Vietnamese locale differs from device-PASS v8: {locale}")
        assert plistlib.loads(final.read(INFO))["CFBundleIdentifier"] == "com.phai.nokias60.omapdiag.UTM-SE"
        assert plistlib.loads(final.read(INFO))["CFBundleDisplayName"] == "UTM OMAP Diag v10"
    result = {
        "status": "PASS", "v8_baseline_sha256": sha256(v8),
        "v10_unlocalized_sha256": sha256(v10), "v10_arm32_vi_sha256": sha256(out),
        "v10_arm32_vi_bytes": out.stat().st_size, "framework_count": len(FRAMEWORKS),
        "v10_bundle_id": base10["CFBundleIdentifier"],
        "v8_baseline_untouched": True, "all_v10_code_and_framework_bytes_unchanged": True,
        "iphone_arm32_guest_test": "NOT_RUN", "omap2420_n95": "NOT_IMPLEMENTED",
    }
    report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise SystemExit("usage: overlay_omap2420_v10_vi_locale.py v8.ipa v10.ipa v10-vi.ipa report.json")
    main(*sys.argv[1:])
