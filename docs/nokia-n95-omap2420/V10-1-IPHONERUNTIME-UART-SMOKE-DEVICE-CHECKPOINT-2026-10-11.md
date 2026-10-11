# DEVICE CHECKPOINT — UART direct smoke observed on iPhone; next D2d no-exit ELF

**Date:** 2026-10-11 (ICT). **Host:** iPhone, UTM OMAP Diagnostic v10.1 installed. **No Nokia firmware.**

## Device evidence

iPhone video/screenshot of serial terminal with kernel `arm1136_omap2420_uart_direct_noexit.elf`, QEMU:
`-machine omap2420-timerdiag -cpu arm1136 -smp cpus=1,sockets=1,cores=1,threads=1 -m 128 -accel tcg,tb-size=32 -nographic -serial chardev:term0 -kernel .../arm1136_omap2420_uart_direct_noexit.elf -semihosting-config enable=on,target=native`.
Screenshot displayed visible suffix **`T=PASS`** in terminal. UTM stayed running; no Home exit. The expected full guest string is `OMAP2420_ARM1136_UART_DIRECT_NOEXIT=PASS`.

**Qualification:** This is convincing evidence of ARMv6 guest execution + UART1 MMIO and SPICE terminal output on iOS, but only *suffix* is visible. Do NOT claim full line-reliable UART output. Do NOT mark PRCM/GPT1/INTC D2d DEVICE PASS yet.

Older `arm1136_omap2420_uart_noexit.elf` LSR-wait test remained blank for three minutes. Direct serial THR output without LSR waiting gave visible suffix. The former may be blocked waiting on LSR; latter may overflow UART THR/FIFO when letters are written too quickly. This is a **hypothesis**, not proven from tracing.

## New guest full D2d iPhone diagnostic

- `tests/omap2420/arm1136_d2d_ios_uart_paced_noexit.S` copies host CI D2d PRCM/GPTimer1/INTC/ARM1136 real IRQ37 guest coverage. Adds an early UART START marker, delay between transmitted bytes to reduce truncation, and **removes SYS_EXIT** from both PASS and FAIL branches to prevent `semihosting/arm-compat-semi.c` calling `exit()` on the iOS host process.
- `.github/workflows/24-omap2420-d2d-ios-noexit-elf.yml` builds ELF32 ARMv6 from source with linker entry `0x80010000`, checks embedded PASS markers and absence of guest `svc`, uploads ELF and diagnostics, **does not rebuild IPA**.
- **GitHub Actions #38149785933: COMPLETED / SUCCESS**, build-only PASS.
- [Download full D2d no-exit ELF artifact #11705688509](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/38149785933/artifacts/11705688509)
- [Build diagnostics #11706562178](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/38149785933/artifacts/11706562178)

## Next on-device steps

Use **existing v10.1 IPA** unchanged, set only Linux kernel to the extracted `arm1136_d2d_ios_uart_paced_noexit.elf`. Keep `omap2420-timerdiag`, ARM1136, 128 MB, one core, TCG, serial terminal and no ISO/initramfs. Run for ~1–2 minutes, inspect marker `D2D_IOS_ARM1136_UART_START=PASS` and detailed `D2D_...=PASS` or `...=FAIL`. Send screenshot/video. Do not interpret guest loop after printing as a hang: this test intentionally idles to keep host UTM process alive.

Only after `D2D_GPT1_...`, `D2D_ARM1136_GPT1_IRQ_EXCEPTION=PASS` markers are visible on-device mark IRQ37/GPT1 DEVICE PASS. v8/v9 and v10/v10.1 original device app releases remain untouched.

**Scope:** emulator compatibility only; not a full Nokia N95, not Symbian startup, no proprietary firmware.
