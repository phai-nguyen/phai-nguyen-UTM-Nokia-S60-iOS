#!/usr/bin/env python3
"""Fix the iOS document picker filtering out ISO files in the UTM wizard.

Pinned UTM sources choose .data in the Linux/Other/Windows/Classic Mac wizard.
On iOS, downloaded ISO files can have UTType 'public.iso-image' / another UTI
that doesn't conform to public.data, so the Files picker shows them disabled
or ignores taps. UTM's drive settings elsewhere already uses .item.

Use [.item] (UTType.item) so iOS offers the file to the existing processImage
handler. This does not bypass iOS security scoped file access or modify QEMU.
"""
from pathlib import Path
import subprocess
import sys

PIN = "7eadb056ae0f91d979059544d0ddcd2d5a40be92"
if len(sys.argv) != 2:
    raise SystemExit("usage: patch_utm_iso_picker.py <pinned upstream/UTM>")
root = Path(sys.argv[1]).resolve()
actual = subprocess.check_output(
    ["git", "-C", str(root), "rev-parse", "HEAD"], text=True
).strip()
if actual != PIN:
    raise SystemExit(f"Refusing UTM SHA mismatch: {actual}")

patches = {
    "Platform/Shared/VMWizardOSLinuxView.swift":
        ".fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)",
    "Platform/Shared/VMWizardOSOtherView.swift":
        ".fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)",
    "Platform/Shared/VMWizardOSWindowsView.swift":
        ".fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)",
    "Platform/Shared/VMWizardOSClassicMacView.swift":
        ".fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data])",
}
for relative, needle in patches.items():
    path = root / relative
    source = path.read_text()
    if source.count(needle) != 1:
        raise SystemExit(f"Patch site missing/duplicated: {relative}; not modifying")
    updated = source.replace(needle, needle.replace("[.data]", "[.item]"), 1)
    path.write_text(updated)
    assert ".fileImporter" in updated and "allowedContentTypes: [.item]" in updated
    print(f"ISO_PICKER_PATCH=PASS {relative}", flush=True)

print("ISO_PICKER_PATCH_COMPLETE=PASS", flush=True)
