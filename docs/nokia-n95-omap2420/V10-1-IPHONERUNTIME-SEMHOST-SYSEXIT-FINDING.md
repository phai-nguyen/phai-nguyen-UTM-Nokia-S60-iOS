# iPhone v10.1 runtime investigation — VM starts, application disappears

Date: 2026-10-11 (ICT). Source: on-device screen recording and full QEMU command.

## Confirmed device configuration

QEMU: `qemu-system-arm`, `-cpu arm1136`, `-machine omap2420-timerdiag`,
`-m 128`, one core, `-accel tcg,tb-size=32`,
`-kernel .../arm1136_d2d_prcm_gpt1.elf`,
`-semihosting-config enable=on,target=native`,
`-nic none`, `-nographic`, serial chardev spiceport.
The unwanted v10 `virtio-serial` and `virtserialport` have been removed successfully in v10.1.

Observed: iOS UTM SE is at VM startup spinner, then disappears directly to iPhone Home. Unlike v10's `QEMU exited with code -1`, no QEMU error dialog was observed in v10.1 video. **Do not mark D2d iPhone device PASS.**

## Identified host process exit hazard

The guest in `tests/omap2420/arm1136_d2d_prcm_gpt1.S` ends on **both PASS and FAIL paths** with `mov r0,#0x18; svc #0x123456` (ARM semihosting SYS_EXIT).
The pinned QEMU fork `utmapp/qemu@v10.0.12-utm`,
`semihosting/arm-compat-semi.c` (TARGET_SYS_EXIT case), executes
`gdb_exit(ret); exit(ret);`.
On an embedded iOS QEMU runtime this C `exit()` may terminate the entire UTM host process. This explains the direct return to Home without proving if test passed or failed. The v10.1 new `-semihosting-config` enables this path; v10 did not have it.

## Next minimal device gate (no IPA rebuild required)

- A new **ARMv6 ELF** was assembled offline from
  `tests/omap2420/arm1136_ios_uart_noexit.S` + `arm1136_ios_uart_noexit.ld`.
  Toolchain used: LLVM clang/lld ARM EABI, ELF32 executable, entry `0x80010000`.
- The program accesses the same machine's real UART1 MMIO
  `0x4806A000`, polls 16550 LSR at `base+0x14`, writes message:
  `OMAP2420_ARM1136_UART_NOEXIT=PASS`.
- Instead of SYS_EXIT it runs an infinite guest branch after printing.
  This is deliberately **CPU/UART-only smoke**, NOT a D2d GPTimer/IRQ37 PASS.
- Generated local ELF SHA256:
  `d948165a18a94813c0db9cabf1cbc60df16fc27d36fbdae46cddabb8038dca38`.
- Test with existing v10.1 IPA, same VM settings; replace only kernel ELF with the no-exit ELF. Display serial terminal. Stop VM manually once message is observed. On iPhone this ELF is **not yet device-tested**.
- If app still exits before marker, request iOS .ips crash report from Settings > Privacy & Security > Analytics & Improvements > Analytics Data, filtering for `UTM SE` / app or JetsamEvent around the crash timestamp.
- If UART smoke PASS, prepare a **full D2d** diagnostic ELF variant that preserves its UART PASS/FAIL reports but replaces both semihosting SYS_EXIT instructions with idle loops; then test full PRCM/GPT1/INTC. Keep v8/v9 and v10.1 IPA untouched.

Do not distribute proprietary Nokia firmware. All of this remains bare-metal emulator compatibility diagnosis, not Nokia N95 / Symbian boot.
