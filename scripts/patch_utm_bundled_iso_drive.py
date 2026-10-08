#!/usr/bin/env python3
"""UTM Lite v7: save iOS/Linux ISO as a bundled raw CD image.

v6 UIKit ISO picking & sandbox copy are device-PASS, but wizard Save reports
"Failed to access drive image path." That string comes from the EXTERNAL-drive
bookmark path UTMQemuVirtualMachine.changeMedium(...) -> UTMProcess.accessData.

Changing CD drive ownership from external to internal causes UTMConfigurationDrive
.saveData() to copy the already-imported ISO into the VM package Data folder.
isRawImage prevents ISO-to-qcow2 conversion; imageType remains .cd and read-only.

This is deliberately scoped to iOS + Linux + boot from ISO; all other drive
types/platforms and the UIKit document picker stay untouched.
"""
from pathlib import Path
import subprocess
import sys

PIN = "7eadb056ae0f91d979059544d0ddcd2d5a40be92"
if len(sys.argv) != 2:
    raise SystemExit("usage: patch_utm_bundled_iso_drive.py <upstream/UTM>")
root = Path(sys.argv[1]).resolve()
actual = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
if actual != PIN:
    raise SystemExit(f"Refusing unexpected UTM upstream SHA: {actual}")

path = root / "Platform/Shared/VMWizardState.swift"
original = path.read_text(encoding="utf-8")
old = """            bootDrive.imageURL = bootImageURL
            config.drives.append(bootDrive)
"""
new = """            #if os(iOS)
            // Nokia UTM Lite v7: UIKit has already imported the Linux ISO
            // into app Documents. Store it in the VM package (Data/) as an
            // internal read-only CD to avoid external-drive bookmark access,
            // which can fail when ESign-signed on iPhone.
            // Keep ISO bytes raw: do not convert bootable optical media
            // into a QCOW2 image.
            if operatingSystem == .Linux && bootDevice == .cd {
                bootDrive.isExternal = false
                bootDrive.isRawImage = true
                bootDrive.isReadOnly = true
                NSLog("[NokiaUTM][ISO] BUNDLED_CD: ISO will be copied into VM Data; no external bookmark")
            }
            #endif
            bootDrive.imageURL = bootImageURL
            config.drives.append(bootDrive)
"""
if original.count(old) != 1:
    raise SystemExit(f"Expected one boot drive location; found {original.count(old)}")
modified = original.replace(old, new, 1)
assert modified.count("bootDrive.isExternal = false") == 1
assert "bootDrive.isRawImage = true" in modified
assert "operatingSystem == .Linux && bootDevice == .cd" in modified
assert "bootDrive.isReadOnly = true" in modified
assert "config.drives.append(bootDrive)" in modified
path.write_text(modified, encoding="utf-8")
print("BUNDLED_CD_PATCH=PASS", path, flush=True)
