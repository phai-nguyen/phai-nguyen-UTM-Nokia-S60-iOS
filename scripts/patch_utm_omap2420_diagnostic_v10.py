#!/usr/bin/env python3
"""Add a strictly diagnostic ARM1136/OMAP2 machine to the pinned UTM iOS wizard.

Run AFTER patch_utm_arm32_linux_wizard_v9.py, BEFORE Xcode archive.
Build is restricted to UTM pin; v8/v9 sources and firmware remain untouched.

The selected "Linux" wizard accepts the project's diagnostic *bare-metal ELF*
in its kernel picker. This does NOT imply OMAP2420 Linux or Nokia ROM support.
"""
from pathlib import Path
import subprocess
import sys

PIN = "7eadb056ae0f91d979059544d0ddcd2d5a40be92"
if len(sys.argv) != 2:
    sys.exit("usage: patch_utm_omap2420_diagnostic_v10.py upstream/UTM")
root = Path(sys.argv[1]).resolve()
actual = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"],
                                 text=True).strip()
if actual != PIN:
    sys.exit(f"Refusing unpinned UTM version {actual}")

def change(path: str, needle: str, replacement: str, marker: str):
    p = root / path
    data = p.read_text(encoding="utf-8")
    if data.count(needle) != 1:
        sys.exit(f"{marker}: expected one anchor, saw {data.count(needle)}")
    patched = data.replace(needle, replacement, 1)
    assert patched != data
    p.write_text(patched, encoding="utf-8")
    print(f"V10_{marker}=PASS {path}", flush=True)

# UTM's QEMUTarget_arm is a closed enum from original QEMU -M help.
# New machine names must be valid Codable rawValue cases for VM persistence.
enum_file = "Configuration/QEMUConstantGenerated.swift"
change(enum_file,
       "enum QEMUTarget_arm: String, CaseIterable, QEMUTarget {\n    case integratorcp",
       'enum QEMUTarget_arm: String, CaseIterable, QEMUTarget {\n'
       '    case omap2420_earlydiag = "omap2420-earlydiag"\n'
       '    case omap2420_uartdiag = "omap2420-uartdiag"\n'
       '    case omap2420_intcdiag = "omap2420-intcdiag"\n'
       '    case omap2420_timerdiag = "omap2420-timerdiag"\n'
       "    case integratorcp",
       "ARM32_TARGET_ENUM")
change(enum_file,
       '        case .integratorcp: return "ARM Integrator/CP (ARM926EJ-S) (integratorcp)"',
       '        case .omap2420_earlydiag: return "OMAP2420 CPU/SRAM diagnostic (no Nokia firmware)"\n'
       '        case .omap2420_uartdiag: return "OMAP2420 UART1 diagnostic (no Nokia firmware)"\n'
       '        case .omap2420_intcdiag: return "OMAP2420 UART+INTC diagnostic (no Nokia firmware)"\n'
       '        case .omap2420_timerdiag: return "OMAP2420 GPTimer1 diagnostic (no Nokia firmware)"\n'
       '        case .integratorcp: return "ARM Integrator/CP (ARM926EJ-S) (integratorcp)"',
       "ARM32_TARGET_LABELS")

wizard_file = "Platform/Shared/VMWizardHardwareView.swift"
change(wizard_file,
       "        case arm32Virt\n        case riscv64Virt",
       "        case arm32Virt\n        case omap2420Diagnostic\n        case riscv64Virt",
       "WIZARD_PRESET_CASE")
change(wizard_file,
       '            case .arm32Virt: "Linux ARM32 (ARMv7) — QEMU virt [thu nghiem]"',
       '            case .arm32Virt: "Linux ARM32 (ARMv7) — QEMU virt [thu nghiem]"\n'
       '            case .omap2420Diagnostic: "OMAP2420 Diagnostic – ARM1136 (chưa phải Nokia N95)"',
       "WIZARD_VIETNAMESE_LABEL")
change(wizard_file,
       "            case .arm32Virt: return .arm",
       "            case .arm32Virt, .omap2420Diagnostic: return .arm",
       "WIZARD_CPU_ARCH")
change(wizard_file,
       "            case .arm32Virt: return QEMUTarget_arm.virt",
       "            case .arm32Virt: return QEMUTarget_arm.virt\n"
       "            case .omap2420Diagnostic: return QEMUTarget_arm.omap2420_timerdiag",
       "WIZARD_QEMU_MACHINE")
change(wizard_file,
       "            case .arm32Virt: return 256",
       "            case .arm32Virt: return 256\n"
       "            case .omap2420Diagnostic: return 128",
       "WIZARD_RAM")
change(wizard_file,
       "            case .i440FX, .arm32Virt: return 2",
       "            case .i440FX, .arm32Virt: return 2\n"
       "            case .omap2420Diagnostic: return 0",
       "WIZARD_NO_DISK")
change(wizard_file,
       "            case .quadra800, .powerMacG4, .arm32Virt: return 1",
       "            case .quadra800, .powerMacG4, .arm32Virt, .omap2420Diagnostic: return 1",
       "WIZARD_ONE_CORE")
change(wizard_file,
       "            case .Linux: return true",
       "            case .Linux: return true",
       "NO_CHANGE_ALLOWED") if False else None
# The preset is intentionally *not* supported for OS types other than Linux.
# Diagnostic ELF can be loaded using Linux->Boot from Kernel even though
# this is NOT a Linux guest; the bare-metal payload is an ARM ELF.
change(wizard_file,
       "            case .Other: return true\n            case .macOS:",
       "            case .Other: return self != .omap2420Diagnostic\n            case .macOS:",
       "WIZARD_HIDE_OTHER")
change(wizard_file,
       "            case .Windows: return [.i440FX, .q35, .arm64Virt].contains(self)",
       "            case .Windows: return [.i440FX, .q35, .arm64Virt].contains(self)",
       "NO_CHANGE_ALLOWED") if False else None

state_file = "Platform/Shared/VMWizardState.swift"
change(state_file,
       "        config.system.cpuCount = systemCpuCount\n        config.qemu.hasHypervisor = useVirtualization",
       '        config.system.cpuCount = systemCpuCount\n'
       '        // NokiaUTM_V10_OMAP_DIAGNOSTIC: this is an ARM11 bare-metal test,\n'
       '        // NOT the ARMv7 virt preset and NOT firmware for Nokia N95.\n'
       '        let isOmapDiagnostic = systemArchitecture == .arm &&\n'
       '            systemTarget.rawValue == "omap2420-timerdiag"\n'
       '        if isOmapDiagnostic {\n'
       '            config.system.cpu = QEMUCPU_arm.arm1136\n'
       '            config.system.cpuCount = 1\n'
       '            config.system.memorySize = 128\n'
       '            config.displays = []\n'
       '            config.networks = []\n'
       '            config.sound = []\n'
       '            config.input.usbBusSupport = .disabled\n'
       '            config.qemu.hasUefiBoot = false\n'
       '            config.qemu.hasTPMDevice = false\n'
       '            config.serials = [UTMQemuConfigurationSerial()]\n'
       '        }\n'
       '        config.qemu.hasHypervisor = useVirtualization',
       "BAREMETAL_NO_UNSUPPORTED_IO")
# 'config.qemu.hasUefiBoot' may be overwritten by wizard OS branching;
# Linux mode doesn't set it (unless legacy hardware enabled), so no problem.
change(state_file,
       "        if bootDevice != .drive {\n            var diskImage = UTMQemuConfigurationDrive()",
       "        if bootDevice != .drive && !isOmapDiagnostic {\n"
       "            var diskImage = UTMQemuConfigurationDrive()",
       "BAREMETAL_NO_EMPTY_DISK")
# Correct serial even if display toggle is accidentally enabled by user.
change(state_file,
       "        let mainDriveInterface: QEMUDriveInterface",
       "        if isOmapDiagnostic {\n"
       "            config.displays = []\n"
       "            config.serials = [UTMQemuConfigurationSerial()]\n"
       "        }\n"
       "        let mainDriveInterface: QEMUDriveInterface",
       "BAREMETAL_SERIAL_ONLY")
# UTM's default ARM CPU is cortex-a15, but for target timerdiag it must be
# ARM1136 from the wizard; do not change the general ARMv7 virt behavior.
# The config.system.cpu above is non-default and UTM emits '-cpu arm1136'.

g = (root / enum_file).read_text()
w = (root / wizard_file).read_text()
st = (root / state_file).read_text()
assert all(x in g for x in (
    'omap2420_earlydiag = "omap2420-earlydiag"',
    'omap2420_timerdiag = "omap2420-timerdiag"'))
assert "OMAP2420 Diagnostic – ARM1136" in w
assert "NokiaUTM_V10_OMAP_DIAGNOSTIC" in st
assert "config.system.cpu = QEMUCPU_arm.arm1136" in st
assert "config.input.usbBusSupport = .disabled" in st
assert "bootDevice != .drive && !isOmapDiagnostic" in st
print("V10_OMAP2420_DIAGNOSTIC_WIZARD=PASS")
