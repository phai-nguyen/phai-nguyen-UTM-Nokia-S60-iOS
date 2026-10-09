#!/usr/bin/env python3
"""ARM32 QEMU-virt only: preserve the Linux -append command line as ONE argv item.

v9 iPhone log: qemu-arm-softmmu: rdinit=/init: Could not open 'rdinit=/init'.
Upstream UTM's parsedUserArguments tokenizes an existing QEMUArgument containing
spaces. UTM wizard stored -append and the entire kernel command line as two
QEMUArgument values, but parsedUserArguments split the latter into 3 tokens.
Only intercept the value IMMEDIATELY after -append on ARM32 virt. Keep all other
architectures, options, and the base UTM source unchanged. Existing v9 VMs are
repaired at runtime without re-importing kernel/initramfs.
"""
from pathlib import Path
import subprocess
import sys

PIN = "7eadb056ae0f91d979059544d0ddcd2d5a40be92"
if len(sys.argv) != 2:
    sys.exit("usage: patch_arm32_qemu_append_v9_1.py <upstream/UTM>")
root = Path(sys.argv[1]).resolve()
actual = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
if actual != PIN:
    sys.exit(f"Refusing unexpected UTM checkout: {actual}")
p = root / "Configuration/UTMQemuConfiguration+Arguments.swift"
original = p.read_text(encoding="utf-8")
old = """        for arg in qemu.additionalArguments {
            let argString = arg.string
            if argString.count > 0 {
"""
new = """        for (index, arg) in qemu.additionalArguments.enumerated() {
            let argString = arg.string
            // NokiaUTM_ARM32_APPEND_FIX: the Linux kernel command line is a
            // single argv token to QEMU, even though its contents contain spaces.
            // Restrict to ARM32 QEMU virt so every v8/other-arch VM stays intact.
            if system.architecture == .arm &&
                system.target.rawValue == "virt" &&
                index > 0 &&
                qemu.additionalArguments[index - 1].string == "-append" {
                let cmdline = argString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cmdline.isEmpty {
                    // Respect users who previously wrapped the argument in
                    // double quotes as the manual v9 workaround.
                    if cmdline.count >= 2 && cmdline.first == "\\"" && cmdline.last == "\\"" {
                        list.append(String(cmdline.dropFirst().dropLast()))
                    } else {
                        list.append(cmdline)
                    }
                }
                continue
            }
            if argString.count > 0 {
"""
if original.count(old) != 1:
    sys.exit(f"Expected one parser anchor, found {original.count(old)}")
assert "NokiaUTM_ARM32_APPEND_FIX" not in original
assert "case" not in old
changed = original.replace(old, new, 1)
if changed.count("NokiaUTM_ARM32_APPEND_FIX") != 1:
    sys.exit("ARM32 append runtime fix missing")
p.write_text(changed, encoding="utf-8")
print(f"ARM32_APPEND_ARGV_FIX=PASS {p}")
