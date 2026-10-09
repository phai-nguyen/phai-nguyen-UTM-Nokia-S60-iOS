#!/usr/bin/env python3
"""Expose the newly built ARM32 virt engine through a normal Linux VM wizard preset.

Run only on the pinned UTM checkout. No OMAP/N95 hardware is implemented.
"""
from pathlib import Path
import subprocess
import sys

PIN = "7eadb056ae0f91d979059544d0ddcd2d5a40be92"
if len(sys.argv) != 2:
    raise SystemExit("usage: patch_utm_arm32_linux_wizard_v9.py upstream/UTM")
root = Path(sys.argv[1]).resolve()
sha = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
if sha != PIN:
    raise SystemExit(f"Unexpected UTM commit {sha}; expected {PIN}")
p = root / "Platform/Shared/VMWizardHardwareView.swift"
source = p.read_text(encoding="utf-8")

def replace_once(before, after, description):
    global source
    count = source.count(before)
    if count != 1:
        raise RuntimeError(f"{description}: expected one anchor, found {count}")
    source = source.replace(before, after, 1)

replace_once(
    "        case arm64Virt\n        case riscv64Virt",
    "        case arm64Virt\n        case arm32Virt\n        case riscv64Virt",
    "machine case",
)
replace_once(
    '            case .arm64Virt: "ARM64 virtual machine (2014, ARM64)"',
    '            case .arm64Virt: "ARM64 virtual machine (2014, ARM64)"\n'
    '            case .arm32Virt: "Linux ARM32 (ARMv7) — QEMU virt [thu nghiem]"',
    "Vietnamese quick-select title",
)
replace_once(
    "            case .arm64Virt: return .aarch64",
    "            case .arm64Virt: return .aarch64\n"
    "            case .arm32Virt: return .arm",
    "ARM32 architecture binding",
)
replace_once(
    "            case .arm64Virt: return QEMUTarget_aarch64.virt",
    "            case .arm64Virt: return QEMUTarget_aarch64.virt\n"
    "            case .arm32Virt: return QEMUTarget_arm.virt",
    "ARM32 QEMU virt machine",
)
replace_once(
    "            case .quadra800: return 128\n"
    "            //case .powerMacG3Beige: return 512",
    "            case .quadra800: return 128\n"
    "            case .arm32Virt: return 256\n"
    "            //case .powerMacG3Beige: return 512",
    "ARM32 256MiB default",
)
replace_once(
    "            case .quadra800, .powerMacG4: return 1\n"
    "            default: return 0",
    "            case .quadra800, .powerMacG4, .arm32Virt: return 1\n"
    "            default: return 0",
    "ARM32 CPU core default",
)
replace_once(
    "            case .i440FX: return 2\n"
    "            #if os(macOS)\n"
    "            default: return 64",
    "            case .i440FX, .arm32Virt: return 2\n"
    "            #if os(macOS)\n"
    "            default: return 64",
    "ARM32 default storage",
)
# Linux is already permitted by the upstream wizard's isSupported method.
if not all(x in source for x in ("case arm32Virt", "QEMUTarget_arm.virt",
                                 "return .arm", "case .arm32Virt: return 256",
                                 "case .quadra800, .powerMacG4, .arm32Virt")):
    raise RuntimeError("ARM32 quick-select post-check failed")
p.write_text(source, encoding="utf-8")
print("ARM32_LINUX_WIZARD_PATCH=PASS", p, flush=True)
