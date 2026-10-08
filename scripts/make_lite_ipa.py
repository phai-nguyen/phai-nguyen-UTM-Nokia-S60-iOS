#!/usr/bin/env python3
"""Make an experimental ARM-only UTM SE IPA without recompiling or touching v1.

Only removes six standalone *guest CPU* QEMU framework bundles. Other app
binaries, shared dependencies, QEMU data, firmware, UIKit/Metal resources are kept.

This is not a Nokia hardware emulator yet. All other VM architectures in UTM's
unmodified UI will be unsupported by this Lite binary.
"""
import copy
import hashlib
import json
import plistlib
import shutil
import sys
import zipfile
from collections import defaultdict
from pathlib import Path

APP_ROOT = "Payload/UTM SE.app/"
DROP_TARGETS = (
    "i386",
    "x86_64",
    "ppc",
    "ppc64",
    "riscv64",
    "m68k",
)
DROP_PREFIXES = tuple(
    APP_ROOT + f"Frameworks/qemu-{t}-softmmu.framework/" for t in DROP_TARGETS
)
KEEP_PREFIX = APP_ROOT + "Frameworks/qemu-aarch64-softmmu.framework/"
EXPECTED_BUNDLE = "com.phai.nokias60.UTM-SE"

def digest(path):
    sha = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(2 * 1024 * 1024), b""):
            sha.update(block)
    return sha.hexdigest()

def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: make_lite_ipa.py source.ipa target.ipa report.json")
    original, target, report = (Path(x) for x in sys.argv[1:])
    target.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    drops = defaultdict(lambda: {"files": 0, "original_bytes": 0, "compressed_bytes": 0})
    keep_arm_found = False
    members_kept = 0
    with zipfile.ZipFile(original, "r") as src:
        plist = plistlib.loads(src.read(APP_ROOT + "Info.plist"))
        if plist.get("CFBundleIdentifier") != EXPECTED_BUNDLE:
            raise SystemExit(f"Unexpected bundle: {plist.get('CFBundleIdentifier')}")
        if plist.get("MinimumOSVersion") != "15.0":
            raise SystemExit("Unexpected minimum iOS; stop rather than mutate unknown artifact")
        for info in src.infolist():
            if info.filename.startswith(KEEP_PREFIX):
                keep_arm_found = True
        if not keep_arm_found:
            raise SystemExit("Missing ARM64 QEMU framework; refusing to create Lite IPA")
        with zipfile.ZipFile(target, "w", allowZip64=True) as dst:
            for info in src.infolist():
                matches = [target_name for target_name, prefix in zip(DROP_TARGETS, DROP_PREFIXES) if info.filename.startswith(prefix)]
                if matches:
                    name = matches[0]
                    drops[name]["files"] += 1
                    drops[name]["original_bytes"] += info.file_size
                    drops[name]["compressed_bytes"] += info.compress_size
                    continue
                # A clone preserves POSIX executable bits and symlinks, and avoids
                # corrupting the original ZipFile's central-directory metadata.
                clone = copy.copy(info)
                with src.open(info, "r") as reader:
                    if info.is_dir():
                        dst.writestr(clone, b"")
                    else:
                        with dst.open(clone, "w", force_zip64=True) as writer:
                            shutil.copyfileobj(reader, writer, 2 * 1024 * 1024)
                members_kept += 1
    if set(drops) != set(DROP_TARGETS):
        target.unlink(missing_ok=True)
        raise SystemExit(f"Expected exactly six removable QEMU frameworks; saw {list(drops)}")
    with zipfile.ZipFile(target) as z:
        err = z.testzip()
        if err is not None:
            raise SystemExit(f"Lite IPA archive corrupt at {err}")
        assert z.read(APP_ROOT + "Info.plist")
        assert any(i.filename.startswith(KEEP_PREFIX) for i in z.infolist())
        assert not any(i.filename.startswith(DROP_PREFIXES) for i in z.infolist())
    summary = {
        "source_ipa": original.name,
        "source_bytes": original.stat().st_size,
        "source_sha256": digest(original),
        "lite_ipa": target.name,
        "lite_bytes": target.stat().st_size,
        "lite_sha256": digest(target),
        "reduction_percent": round(100 * (1 - target.stat().st_size / original.stat().st_size), 2),
        "removed_guest_targets": dict(drops),
        "members_kept": members_kept,
        "preserved_arm_framework": True,
        "minimum_ios": "15.0",
        "bundle_id": EXPECTED_BUNDLE,
        "unsupported_architectures_not_hidden_from_ui": list(DROP_TARGETS),
        "device_test": "NOT YET TESTED",
        "nokia_machine": "NOT IMPLEMENTED",
    }
    report.write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    print("LITE_IPA=PASS; zip integrity PASS; needs ESign and real-device test")

if __name__ == "__main__":
    main()
