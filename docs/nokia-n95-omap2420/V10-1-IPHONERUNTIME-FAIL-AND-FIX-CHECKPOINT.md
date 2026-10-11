# Checkpoint — UTM OMAP Diagnostic v10 device FAIL, v10.1 runtime fix

**Date:** 2026-10-11 (Vietnam time). **Scope:** emulator compatibility, not Nokia firmware boot.

## v10 iPhone evidence

- Previously compiled v10 GitHub Actions #37931130662 PASS; unsigned IPA installed and UI/VM wizard ran on iPhone.
- On-device machine: ARM (aarch32), `omap2420-timerdiag`, `-cpu arm1136`, `-m 128`, `-accel tcg,tb-size=32`, `-kernel .../arm1136_d2d_prcm_gpt1.elf`, `-nic none`, `-nographic`, `-serial chardev:term0`. Kernel/initrd/root image unused except diagnostic ELF.
- Device error on 2026-10-11 08:27:22: `QEMU exited with code -1: (no message)`; **OMAP guest runtime FAIL**, no D2d marker observed. Debug Logging switch was enabled, but Export Debug Log button greyed out. Full QEMU command exported from Settings > QEMU > Arguments > Command Line.
- Unexpected QEMU arguments: `-device virtio-serial` and `-device virtserialport,chardev=org.qemu.guest_agent,name=org.qemu.guest_agent.0` with corresponding guest-agent chardev. Machine implementation `tests/omap2420/omap2420_diag_d2d.c` creates ARM1136/SRAM/SDRAM/UART/INTC/PRCM/GPT but **no PCI/VirtIO bus**. UTM `Configuration/QEMUConstant.swift` has `hasAgentSupport` true by default for generic ARM and custom target; `Configuration/UTMQemuConfiguration+Arguments.swift` auto-injects this guest agent when enabled. Thus unsupported VirtIO bus is the leading root-cause hypothesis, but **QEMU stderr is not available**; root cause is not yet runtime-proven.
- Host CI bare-metal ELF test used `-semihosting-config enable=on,target=native` for `SYS_EXIT`, absent from v10 exported iOS command. That absence does not by itself prove why QEMU exited before boot, but it must be aligned for a successful end-to-end test.

## v10.1 fix (independent branch)

- Branch `fix/utm-se-lite-v10-1-omap2420-virtio-boot`. Base: last v10 docs checkpoint; v8/v9/v10 original branch untouched.
- `scripts/patch_utm_omap2420_v10_1_runtime.py`: pinned UTM source, disable `QEMUTarget.hasAgentSupport` for four OMAP diagnostic machines, suppressing auto-created QEMU/Spice guest agents only for unsupported boards. Add `-semihosting-config enable=on,target=native` only for four ARM OMAP diagnostic machines.
- Workflow `.github/workflows/23-lite-v10-1-omap2420-runtime-fix-ipa.yml`: reuses v10 source, Gate D2e ARM32 TCI framework and Gate D2d guest ELF, retains 8 QEMU engines, iOS >= 15, diagnostic logs and SHA checks.
- v10.1 bundle `com.phai.nokias60.omapdiag101.UTM-SE`, display `UTM OMAP Diag v10.1`, Vietnamese UI overlay read-only baseline from v8; installs alongside v10.
- Initial GitHub Actions run: [#38102421273](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/38102421273). **Status at time of creation: IN PROGRESS, do not mark build PASS until verified.**
- Still **not Nokia N95/Symbian boot**. Do not mark any OMAP device PASS until serial D2d markers are observed on iPhone.

## Next

1. Check run #38102421273: compile/archive, source guard `V10_1_OMAP2420_RUNTIME_PATCH=PASS`, output unsigned IPA, ELF and logs. Repair CI errors in isolated branch if needed.
2. On iPhone ESign-sign **v10.1** IPA, create fresh OMAP2420-timerdiag machine with same ELF, 128MiB, serial-only, 1 CPU, no disk/ISO/bootargs. Confirm exported command has neither auto guest-agent VirtIO devices, but does have `-semihosting-config enable=on,target=native`.
3. Boot and capture UART serial markers (GPT1 clock-gating, IRQ37 pending/ack, ARM1136 IRQ exception, softreset, ARMv6 memory). If failure, capture displayed QEMU command, error dialog and any available export logs.
4. Update checkpoint with device evidence. Keep iPhone v8 ARM64 and v9 ARM32 device-pass baselines unchanged.
