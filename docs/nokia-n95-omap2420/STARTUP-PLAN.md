# Nokia N95 / OMAP2420 — Research start (2026-10-09)

## Scope and baselines

**Do not modify or regress** the device-tested UTM SE Lite v8 Alpine Linux ARM64 baseline:
- [v8 unsigned IPA, Actions run #37788063413](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37788063413/artifacts/11554159956).
- SHA256: `671535ffec7f866688537ee86db8c5eb53aeccbd78f3fc517dcb9dcf871e6caa`.
- [Device test checkpoint](../checkpoints/2026-10-08-ALPINE-AARCH64-DEVICE-BOOT-PASS.md): UIKit ISO import, VM creation, Alpine 3.24.2 aarch64 boot and root login, VirtIO 4 GiB disk / optical ISO, NAT DHCP, DNS, HTTP, clean shutdown and reboot all PASS.
- Some Vietnamese strings remain untranslated; iPhone localization device-PASS for completed portions.
- No JIT on iPhone; keep iOS minimum 15.0 and ESign compatibility.

**Critical boundary:** Alpine succeeded with `qemu-aarch64-softmmu` and generic `virt` machine. Nokia N95 firmware requires **32-bit ARM (ARM1136-family) OMAP2420-class hardware** with Nokia-specific board behavior; it cannot be loaded into the existing generic Alpine `virt` config and expected to boot.

Keep this research isolated in `research/n95-omap2420-arm32`; no Nokia hardware has yet been integrated into the IPA. The user's other repo `phai-nguyen/EKA2L1-S60-OMAP2420-iOS` is an independent project—do not merge its state or branches into this repo.

## Implementation gates

1. **QEMU source inventory, no application changes.** Identify a verifiable historical QEMU implementation of `hw/arm/omap2.c`, `hw/arm/nseries.c` or equivalent. Document exact source commit, licenses and the actual machines implemented (often Nokia N800/N810, **not** N95). Inspect compatibility with pinned UTM source `7eadb056ae0f91d979059544d0ddcd2d5a40be92` and chosen QEMU sysroot.
2. **ARM32 engine.** Add a separately named QEMU ARM system emulator framework with TCI/no-JIT and correct iOS signing/dyld closure. Test `qemu-system-arm` on a minimal, openly redistributable ARM32 guest first. Existing 7 QEMU frameworks remain unchanged.
3. **OMAP2 boot/model proof of concept.** Implement or adapt OMAP2420 core components and register/physical-memory map, serial UART diagnostics, interrupt controller, clocks/timers and boot image loading. Unit tests/logs and Actions artifacts required.
4. **Nokia N95-specific board.** Investigate firmware image format, boot chain and Nokia peripheral configuration; avoid treating the N800/N810 reference implementation as a complete N95 board.
5. **iPhone regression gate.** After every integration, verify ESign installed app still imports Alpine ISO, saves/boots ARM64 Linux, configures network and shuts down. Do not modify firmware or bake copyrighted Nokia images into the project.
6. **First N95 diagnostic boot.** Only after the board model exists, use legally provided user firmware, capture UART/MMIO logs and measure boot progress. Expect missing-device work; do not promise a working Symbian UI.

## Suggested next action

Perform a source-level comparison between the pinned modern QEMU/UTM tree and historical OMAP2/N-series code. Produce an inventory of removed APIs and expected porting changes **before writing hardware emulation code or scheduling an IPA build**. Retain a clean handoff and separate branch for subsequent steps.

## Safety

This is benign emulator compatibility research. Not related to exploitation, credential collection, malware, persistence, or intrusion.
