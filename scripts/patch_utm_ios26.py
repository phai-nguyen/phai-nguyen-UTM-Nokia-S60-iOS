#!/usr/bin/env python3
"""Apply a narrow, fail-closed compatibility patch for UTM pinned at 7eadb056.

UTM currently contains iOS 27-only SwiftUI symbols under runtime #available
guards. The iOS 26.5 SDK still typechecks those branches and fails compilation.
For the iOS 15..26 bootstrap IPA, preserve the existing fallback code.
"""
from pathlib import Path
import subprocess
import sys

PIN = "7eadb056ae0f91d979059544d0ddcd2d5a40be92"

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_utm_ios26.py <upstream/UTM>")

root = Path(sys.argv[1]).resolve()
actual = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
if actual != PIN:
    raise SystemExit(f"UTM SHA mismatch: expected {PIN}, got {actual}")

patches = [
    (
        "Platform/iOS/VMWindowView.swift",
        '''        if #available(iOS 27, *) {
            content.dismissalConfirmationDialog("This virtual machine is still running.", shouldPresent: isLastWindowOfRunningVM) {
                Button("Stop", role: .destructive) {
                    session.powerDown()
                }
            } message: {
                Text("Closing the window stops the virtual machine. Any unsaved changes will be lost.")
            }
        } else {
            content
        }
''',
        '''        // iOS 27-only API removed for bootstrap build with iOS 26 SDK.
        content
''',
    ),
    (
        "Platform/iOS/UTMExternalSceneDelegate.swift",
        '''        if #available(iOS 27, *) {
            sceneAccessory {
                ExternalNonInteractiveAccessory {
                    UTMSingleWindowView()
                }
            }
        } else {
            self
        }
''',
        '''        // iOS 27-only scene accessory; iOS <= 26 uses scene delegate.
        self
''',
    ),
]

for relative, before, after in patches:
    path = root / relative
    source = path.read_text()
    count = source.count(before)
    if count != 1:
        raise SystemExit(f"Expected exactly one patch site in {relative}, found {count}. Refuse unsafe patch.")
    path.write_text(source.replace(before, after, 1))
    print(f"PATCH PASS: {relative}", flush=True)

print("UTM IOS26 API PATCH COMPLETE", flush=True)
