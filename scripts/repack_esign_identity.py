#!/usr/bin/env python3
"""Repackage a known-good unsigned UTM Lite IPA with an exact ESign App ID suffix.

The provisioning profile embedded by ESign must contain an application-identifier
whose suffix is byte-for-byte the new CFBundleIdentifier, with a consistent Team ID.
No certificate, provisioning profile, signing key or entitlements are requested here.

NEVER use the EKA2L1 iOS app's Bundle ID: doing so would overwrite EKA2L1.
This tool only edits Info.plist, and *cannot* fix signing itself.
"""
import copy
import hashlib
import json
import plistlib
import re
import shutil
import sys
import zipfile
from pathlib import Path

INFO="Payload/UTM SE.app/Info.plist"
BASE="com.phai.nokias60.UTM-SE"
RESERVED={
    BASE,
    "com.eka2l1.emulator",
    "app.lavender1865.valley8348",  # Working EKA2L1 iOS identity; do not replace!
}
BUNDLE_RE=re.compile(r"^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}$")

def digest(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(2**20), b""):
            h.update(chunk)
    return h.hexdigest()

def run(inp, out, report, new_id):
    if not BUNDLE_RE.fullmatch(new_id):
        raise ValueError("Use exact provisioning App ID suffix (at least three dot-separated components)")
    if new_id in RESERVED:
        raise ValueError("REFUSED: identifier is reserved for EKA2L1 or the original UTM build. Never overwrite EKA2L1.")
    inp, out, report=Path(inp),Path(out),Path(report)
    out.parent.mkdir(parents=True,exist_ok=True)
    report.parent.mkdir(parents=True,exist_ok=True)
    before=None
    original_info=None
    with zipfile.ZipFile(inp,"r") as src:
        originals=src.namelist()
        if originals.count(INFO)!=1:
            raise RuntimeError(f"Expected exactly one {INFO}")
        original_info=src.read(INFO)
        before=plistlib.loads(original_info)
        if before.get("CFBundleIdentifier")!=BASE:
            raise RuntimeError(f"Unexpected input CFBundleIdentifier: {before.get('CFBundleIdentifier')}")
        if before.get("MinimumOSVersion")!="15.0":
            raise RuntimeError("Unexpected minimum iOS version; refuse unknown input")
        if before.get("UIFileSharingEnabled") is not True or before.get("LSSupportsOpeningDocumentsInPlace") is not True:
            raise RuntimeError("Expected Documents/Files support absent")
        # Keep AppGroupIdentifier unchanged; ESign must provide compatible
        # entitlements. Changing it blindly could break VM data/preferences.
        after=dict(before)
        after["CFBundleIdentifier"]=new_id
        fmt=plistlib.FMT_BINARY if original_info.startswith(b"bplist") else plistlib.FMT_XML
        patched=plistlib.dumps(after,fmt=fmt,sort_keys=False)
        with zipfile.ZipFile(out,"w",allowZip64=True) as dst:
            for zi in src.infolist():
                clone=copy.copy(zi)
                if zi.filename==INFO:
                    dst.writestr(clone,patched)
                elif zi.is_dir():
                    dst.writestr(clone,b"")
                else:
                    with src.open(zi) as reader,dst.open(clone,"w",force_zip64=True) as writer:
                        shutil.copyfileobj(reader,writer,2**20)
    with zipfile.ZipFile(inp,"r") as src,zipfile.ZipFile(out,"r") as dst:
        if src.namelist()!=dst.namelist():
            raise RuntimeError("IPA file list changed unexpectedly")
        if plistlib.loads(dst.read(INFO)).get("CFBundleIdentifier")!=new_id:
            raise RuntimeError("Bundle ID verification failed")
        if dst.testzip() is not None:
            raise RuntimeError("Output ZIP integrity failed")
        expected=next((x for x in src.namelist() if x.endswith("/Frameworks/qemu-aarch64-softmmu.framework/qemu-aarch64-softmmu")),None)
        if expected is None or expected not in dst.namelist():
            raise RuntimeError("QEMU ARM64 engine missing")
        if len([x for x in dst.namelist() if "/Frameworks/qemu-" in x and x.endswith("-softmmu")])!=7:
            raise RuntimeError("Expected all seven strongly linked QEMU frameworks")
    manifest={
        "status":"IPA_UNSIGNED_REPACKAGED_ONLY",
        "source_sha256":digest(inp),
        "output_sha256":digest(out),
        "new_cf_bundle_identifier":new_id,
        "minimum_ios":"15.0",
        "qemu_frameworks_preserved":7,
        "app_group_identifier_unchanged":before.get("AppGroupIdentifier"),
        "on_device_files_picker_test":"NOT TESTED",
        "esign_instructions":"Sign with separate provisioning profile whose application-identifier suffix exactly equals new_cf_bundle_identifier. Do NOT substitute EKA2L1's profile App ID. Verify resulting entitlements before installation.",
    }
    report.write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    print(json.dumps(manifest,ensure_ascii=False,indent=2))

if __name__=="__main__":
    if len(sys.argv)!=5:
        raise SystemExit("usage: repack_esign_identity.py source.ipa output.ipa manifest.json exact_app_id_suffix")
    try:
        run(*sys.argv[1:])
    except Exception as e:
        print(f"FAILED CLOSED: {e}",file=sys.stderr)
        raise SystemExit(2)
