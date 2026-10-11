#!/usr/bin/env python3
"""Device-log-derived v10.1 runtime fix for OMAP2420 diagnostic QEMU on iPhone.

Applies to the pinned UTM checkout only, AFTER v9.1 ARM32 append fix and v10 wizard.
QEMU's OMAP2420 diagnostic machines have no VirtIO/PCI bus. Vanilla UTM
mistakenly enables an implicit VirtIO guest agent for virtually all ARM targets.
The iPhone v10 generated -device virtio-serial + virtserialport despite the board
not providing a matching bus. Keep normal v8/v9 ARM machines unchanged.

The diagnostic ELF uses ARM semihosting SYS_EXIT. Linux-host gate D2d enabled
-semihosting-config, while v10 iPhone command lacked it. Enable only on the
four diagnostic targets to match host-tested conditions.
"""
from pathlib import Path
import subprocess
import sys

PIN = "7eadb056ae0f91d979059544d0ddcd2d5a40be92"
if len(sys.argv) != 2:
    sys.exit("usage: patch_utm_omap2420_v10_1_runtime.py upstream/UTM")
root = Path(sys.argv[1]).resolve()
actual = subprocess.check_output(
    ["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
if actual != PIN:
    sys.exit(f"Unexpected UTM source revision: {actual}")

machines = (
    "omap2420-earlydiag",
    "omap2420-uartdiag",
    "omap2420-intcdiag",
    "omap2420-timerdiag",
)

def replace_exact(path, old, new, label):
    p = root / path
    original = p.read_text(encoding="utf-8")
    n = original.count(old)
    if n != 1:
        sys.exit(f"{label}: expected 1 unambiguous anchor, found {n}")
    p.write_text(original.replace(old, new, 1), encoding="utf-8")
    print(f"V10_1_{label}=PASS {path}", flush=True)

# Both the implicit guest-agent channel and optional SPICE vdagent are behind
# QEMUTarget.hasAgentSupport. Switching this feature off avoids creating
# unsupported virtio-serial-pci on our no-PCI custom board.
target = "Configuration/QEMUConstant.swift"
replace_exact(
    target,
    '    var hasAgentSupport: Bool {\n        switch self.rawValue {\n        case "isapc": return false',
    '    var hasAgentSupport: Bool {\n        switch self.rawValue {\n'
    '        // NokiaUTM_V10_1_NO_VIRTIO_AGENT: these bare-metal boards have NO VirtIO/PCI bus.\n'
    '        case "omap2420-earlydiag", "omap2420-uartdiag",\n'
    '             "omap2420-intcdiag", "omap2420-timerdiag": return false\n'
    '        case "isapc": return false',
    "DISABLE_UNSUPPORTED_VIRTIO_AGENT",
)

# Keep diagnostic guest's semihosted SYS_EXIT available so expected guest exit
# can be distinguished from a host QEMU crash. Do not alter other machines.
args = "Configuration/UTMQemuConfiguration+Arguments.swift"
replace_exact(
    args,
    '    @QEMUArgumentBuilder private var miscArguments: [QEMUArgument] {\n        f("-name")',
    '    @QEMUArgumentBuilder private var miscArguments: [QEMUArgument] {\n'
    '        // NokiaUTM_V10_1_ARM1136_SEMIHOSTING: match Linux-host D2d ELF test.\n'
    '        if system.architecture == .arm && [\n'
    '            "omap2420-earlydiag", "omap2420-uartdiag",\n'
    '            "omap2420-intcdiag", "omap2420-timerdiag"\n'
    '        ].contains(system.target.rawValue) {\n'
    '            f("-semihosting-config")\n'
    '            f("enable=on,target=native")\n'
    '        }\n'
    '        f("-name")',
    "ENABLE_ARM1136_TEST_SEMIHOSTING",
)

t = (root / target).read_text()
a = (root / args).read_text()
for machine in machines:
    if f'"{machine}"' not in t or f'"{machine}"' not in a:
        sys.exit(f"Diagnostic machine missing in runtime patch: {machine}")
assert t.count("NokiaUTM_V10_1_NO_VIRTIO_AGENT") == 1
assert a.count("NokiaUTM_V10_1_ARM1136_SEMIHOSTING") == 1
assert 'f("-semihosting-config")' in a
assert 'f("enable=on,target=native")' in a
print("V10_1_OMAP2420_RUNTIME_PATCH=PASS", flush=True)
