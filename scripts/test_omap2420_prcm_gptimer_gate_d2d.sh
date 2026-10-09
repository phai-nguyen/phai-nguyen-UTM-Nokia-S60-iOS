#!/usr/bin/env bash
# Gate D2d: QEMU10 OMAP2420 EARLY UART1 (real 16550 MMIO + OMAP registers).
# No Nokia firmware, no full OMAP2 clock/INTC, no iOS IPA.
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out/omap2420-d2d"
DIAG="$OUT/diagnostics"
WORK="$OUT/work"
PAYLOAD="$OUT/payload"
URL="https://github.com/utmapp/qemu/releases/download/v10.0.12-utm/qemu-10.0.12-utm.tar.xz"
mkdir -p "$DIAG" "$WORK" "$PAYLOAD"
STATUS=FAIL
STAGE=init
on_exit() {
  rc=$?
  {
    echo "GATE_D2D_STATUS=$STATUS"
    echo "EXIT_CODE=$rc"
    echo "LAST_STAGE=$STAGE"
    echo "QEMU_SOURCE=utmapp/qemu@v10.0.12-utm"
    echo "MACHINE=omap2420-timerdiag"
    echo "CPU=arm1136_ARMv6"
    echo "UART1_MMIO=0x4806A000"
    echo "UART1_BACKEND=QEMU10_SERIAL_MM_16550_WITH_OMAP_INTC"
    echo "UART1_OMAP_VENDOR_REGS=IMPLEMENTED_DIAGNOSTIC_SUBSET"
    echo "UART1_IRQ_CPU_ROUTE=OMAP2_INTC_IRQ72_TO_ARM1136"
    echo "GPTIMER1_IRQ_CPU_ROUTE=OMAP2_INTC_IRQ37_TO_ARM1136"
    echo "PRCM_GPT1_CLOCK=DIAGNOSTIC_GATE_SUBSET_ONLY"
    echo "UART1_RX_DEVICE=16550_LOCAL_LOOPBACK_GUEST_TEST"
    echo "DIAGNOSTIC_OUTPUT=REAL_UART1_MMIO_NOT_SEMIHOSTING"
    echo "NOKIA_N95_SYMBIAN=NOT_IMPLEMENTED"
    echo "IOS_IPA=NOT_BUILT"
    echo "IPHONE_OMAP2420_TEST=NOT_RUN"
    echo "UTM_V8_V9_BASELINES=UNMODIFIED"
  } > "$DIAG/BUILD-STATUS.txt"
  echo "GATE_D2D_STATUS=$STATUS STAGE=$STAGE EXIT_CODE=$rc"
}
trap on_exit EXIT

STAGE=toolchain
for t in curl tar grep gcc meson ninja pkg-config arm-linux-gnueabi-as arm-linux-gnueabi-ld arm-linux-gnueabi-objcopy arm-linux-gnueabi-objdump readelf timeout; do
  command -v "$t" >/dev/null || { echo "Missing tool $t" >&2; exit 21; }
done
{ gcc --version | head -n1; meson --version; ninja --version;
  arm-linux-gnueabi-as --version | head -n1; } > "$DIAG/toolchain.txt"

STAGE=fetch-qemu10
ARCHIVE="$WORK/qemu-10.0.12-utm.tar.xz"
curl -fLsS --retry 4 --retry-delay 3 --connect-timeout 30 --max-time 900 "$URL" -o "$ARCHIVE"
test -s "$ARCHIVE"
sha256sum "$ARCHIVE" > "$DIAG/qemu-source-sha256.txt"
tar -xJf "$ARCHIVE" -C "$WORK"
SRC="$WORK/qemu-10.0.12-utm"
test -f "$SRC/configure"
test ! -e "$SRC/hw/arm/omap2.c"
test ! -e "$SRC/hw/arm/nseries.c"
grep -F 'serial_mm_init(' "$SRC/hw/char/serial-mm.c" > "$DIAG/uart-backend-source-proof.txt"
grep -F 'qemu_chr_fe_write(' "$SRC/hw/char/serial.c" >> "$DIAG/uart-backend-source-proof.txt"
grep -F '"arm1136",' "$SRC/target/arm/tcg/cpu32.c" >> "$DIAG/uart-backend-source-proof.txt"

STAGE=register-d2a-d2b-d2c-d2d-machines
python3 - "$SRC" "$ROOT/tests/omap2420" "$DIAG" <<'PY'
from pathlib import Path
import sys

src, tests, diag = map(Path, sys.argv[1:])
meson = src / "hw/arm/meson.build"
kconfig = src / "hw/arm/Kconfig"
base = meson.read_text()
anchor = "arm_ss.add(when: 'CONFIG_FSL_IMX31', if_true: files('fsl-imx31.c', 'kzm.c'))"
assert base.count(anchor) == 1 and "OMAP2420_DIAG_D2" not in base
meson.write_text(base.replace(anchor, anchor + """
arm_ss.add(when: 'CONFIG_OMAP2420_DIAG_D2A', if_true: files('omap2420_diag_d2a.c'))
arm_ss.add(when: 'CONFIG_OMAP2420_DIAG_D2B', if_true: files('omap2420_diag_d2b.c'))
arm_ss.add(when: 'CONFIG_OMAP2420_DIAG_D2C', if_true: files('omap2420_diag_d2c.c'))
arm_ss.add(when: 'CONFIG_OMAP2420_DIAG_D2D', if_true: files('omap2420_diag_d2d.c'))""", 1))
kc = kconfig.read_text()
assert 'OMAP2420_DIAG_D2A' not in kc and 'OMAP2420_DIAG_D2B' not in kc
kconfig.write_text(kc + """
# Independent OMAP2420 memory and UART diagnostic, no Nokia N95 firmware.
config OMAP2420_DIAG_D2A
    bool
    default y

config OMAP2420_DIAG_D2B
    bool
    default y
    select SERIAL_MM

config OMAP2420_DIAG_D2C
    bool
    default y
    select SERIAL_MM

config OMAP2420_DIAG_D2D
    bool
    default y
    select SERIAL_MM
""")
for name in ("omap2420_diag_d2a.c", "omap2420_diag_d2b.c", "omap2420_diag_d2c.c", "omap2420_diag_d2d.c"):
    path = src / "hw/arm" / name
    assert not path.exists()
    path.write_bytes((tests / name).read_bytes())
(diag / "patch-manifest.txt").write_text(
    "CONFIG_OMAP2420_DIAG_D2A=enabled\n"
    "CONFIG_OMAP2420_DIAG_D2B=enabled\n"
    "CONFIG_OMAP2420_DIAG_D2C=enabled\n"
    "CONFIG_OMAP2420_DIAG_D2D=enabled\n"
    "SELECT_SERIAL_MM=true\n"
    "UART1_BACKEND=QEMU_16550_serial_mm_init\n"
    "UART1_VENDOR_REGS=MemoryRegion_IO\n"
    "UART1_IRQ_CPU_ROUTE=OMAP2_INTC_IRQ72_TO_ARM1136\n"
    "GPTIMER1_IRQ_CPU_ROUTE=OMAP2_INTC_IRQ37_TO_ARM1136\n"
    "NOKIA_N95=NOT_IMPLEMENTED\n"
)
print("D2D_PINNED_QEMU10_SOURCE_PATCH=PASS")
PY

STAGE=build-qemu10-arm-softmmu
mkdir -p "$WORK/build"
(
  cd "$WORK/build"
  "$SRC/configure" --target-list=arm-softmmu \
    --disable-docs --disable-debug-info --disable-werror --disable-rust \
    > "$DIAG/configure.log" 2>&1
  ninja -j 4 > "$DIAG/compile.log" 2>&1
)
QEMU="$WORK/build/qemu-system-arm"
test -x "$QEMU"
"$QEMU" --version | tee "$DIAG/qemu-version.txt"
grep -F '10.0.12' "$DIAG/qemu-version.txt"
"$QEMU" -machine help > "$DIAG/machine-list.txt"
"$QEMU" -cpu help > "$DIAG/cpu-list.txt"
grep -E '^omap2420-earlydiag[[:space:]]' "$DIAG/machine-list.txt"
grep -E '^omap2420-uartdiag[[:space:]]' "$DIAG/machine-list.txt"
grep -E '^omap2420-intcdiag[[:space:]]' "$DIAG/machine-list.txt"
grep -E '^omap2420-timerdiag[[:space:]]' "$DIAG/machine-list.txt"
grep -E '(^|[[:space:]])arm1136([[:space:]]|$)' "$DIAG/cpu-list.txt"
echo 'D2D_MACHINE_ARM1136_GPTIMER1_PRCM_BUILD=PASS' | tee "$DIAG/machine-gate.txt"

STAGE=compile-armv6-guest
arm-linux-gnueabi-as -march=armv6 \
  "$ROOT/tests/omap2420/arm1136_d2d_prcm_gpt1.S" -o "$PAYLOAD/arm1136_d2d_prcm_gpt1.o"
arm-linux-gnueabi-ld \
  -T "$ROOT/tests/omap2420/arm1136_d2a_memory.ld" \
  -z max-page-size=0x1000 \
  -o "$PAYLOAD/arm1136_d2d_prcm_gpt1.elf" "$PAYLOAD/arm1136_d2d_prcm_gpt1.o"
arm-linux-gnueabi-objcopy -O binary \
  "$PAYLOAD/arm1136_d2d_prcm_gpt1.elf" "$PAYLOAD/arm1136_d2d_prcm_gpt1.bin"
arm-linux-gnueabi-objdump -d "$PAYLOAD/arm1136_d2d_prcm_gpt1.elf" \
  > "$DIAG/guest-uart-mmio-disassembly.txt"
readelf -h -l "$PAYLOAD/arm1136_d2d_prcm_gpt1.elf" > "$DIAG/guest-elf.txt"
grep -F '0x80010000' "$DIAG/guest-elf.txt"
grep -E '\bstrb\b' "$DIAG/guest-uart-mmio-disassembly.txt" | head -n 6
sha256sum "$PAYLOAD/arm1136_d2d_prcm_gpt1.elf" > "$DIAG/guest-sha256.txt"

STAGE=run-d2b-uart1-real-serial
# No stdout from semihosting: all marker output originates in UART1 MMIO.
set +e
timeout 60 "$QEMU" \
  -M omap2420-timerdiag -cpu arm1136 -m 128M \
  -display none -monitor none -serial stdio -nic none -no-reboot \
  -kernel "$PAYLOAD/arm1136_d2d_prcm_gpt1.elf" \
  -semihosting-config enable=on,target=native \
  > "$DIAG/arm1136-omap2420-prcm-gpt1-serial.log" 2>&1
RC=$?
set -e
echo "QEMU_EXIT_CODE=$RC" | tee "$DIAG/runtime-status.txt"
tail -n 75 "$DIAG/arm1136-omap2420-prcm-gpt1-serial.log"
for marker in \
  "D2D_PRCM_GPT1_CLOCK_GATING=PASS" \
  "D2D_GPT1_OVERFLOW_TISR_TIER=PASS" \
  "D2D_GPT1_INTC_IRQ37_PENDING_MASK_ACK=PASS" \
  "D2D_ARM1136_GPT1_IRQ_EXCEPTION=PASS" \
  "D2D_GPT1_SOFTRESET=PASS" \
  "D2D_D2A_ARMV6_MEMORY=PASS" \
  "D2D_FULL_OMAP_CLOCK_TREE=NOT_IMPLEMENTED"; do
  grep -Fx "$marker" "$DIAG/arm1136-omap2420-prcm-gpt1-serial.log"
done
test "$RC" -eq 0 || { echo "QEMU did not exit 0: $RC" >&2; exit 41; }
echo 'D2D_PRCM_GPT1_IRQ37_ARM1136_RUNTIME=PASS' >> "$DIAG/runtime-status.txt"


STAGE=d2c-uart-rx-irq72-baseline-regression
arm-linux-gnueabi-as -march=armv6 "$ROOT/tests/omap2420/arm1136_d2c_intc_uart.S" \
  -o "$PAYLOAD/arm1136_d2c_regression.o"
arm-linux-gnueabi-ld \
  -T "$ROOT/tests/omap2420/arm1136_d2a_memory.ld" -z max-page-size=0x1000 \
  -o "$PAYLOAD/arm1136_d2c_regression.elf" "$PAYLOAD/arm1136_d2c_regression.o"
set +e
timeout 30 "$QEMU" -M omap2420-intcdiag -cpu arm1136 -m 128M \
  -display none -monitor none -serial stdio -nic none -no-reboot \
  -kernel "$PAYLOAD/arm1136_d2c_regression.elf" \
  -semihosting-config enable=on,target=native \
  > "$DIAG/gate-d2c-rx-irq72-regression.log" 2>&1
D2C_RC=$?
set -e
test "$D2C_RC" -eq 0
grep -Fx 'D2C_UART1_RX_LOOPBACK=PASS' "$DIAG/gate-d2c-rx-irq72-regression.log"
grep -Fx 'D2C_ARM1136_CPU_IRQ_EXCEPTION=PASS' "$DIAG/gate-d2c-rx-irq72-regression.log"
echo 'D2C_UART_RX_IRQ72_BASELINE_REGRESSION=PASS' | tee "$DIAG/irq-regression-status.txt"

STAGE=d2b-uart-tx-baseline-regression
arm-linux-gnueabi-as -march=armv6 "$ROOT/tests/omap2420/arm1136_d2b_uart.S" \
  -o "$PAYLOAD/arm1136_d2b_regression.o"
arm-linux-gnueabi-ld \
  -T "$ROOT/tests/omap2420/arm1136_d2a_memory.ld" -z max-page-size=0x1000 \
  -o "$PAYLOAD/arm1136_d2b_regression.elf" "$PAYLOAD/arm1136_d2b_regression.o"
set +e
timeout 30 "$QEMU" -M omap2420-uartdiag -cpu arm1136 -m 128M \
  -display none -monitor none -serial stdio -nic none -no-reboot \
  -kernel "$PAYLOAD/arm1136_d2b_regression.elf" \
  -semihosting-config enable=on,target=native \
  > "$DIAG/gate-d2b-uart-tx-regression.log" 2>&1
D2B_RC=$?
set -e
test "$D2B_RC" -eq 0
grep -Fx 'D2B_UART1_16550_TX_MMIO=PASS' "$DIAG/gate-d2b-uart-tx-regression.log"
grep -Fx 'D2B_UART1_VENDOR_REGS=PASS' "$DIAG/gate-d2b-uart-tx-regression.log"
echo 'D2B_UART1_TX_BASELINE_REGRESSION=PASS' | tee "$DIAG/uart-regression-status.txt"

STAGE=d2a-baseline-regression
arm-linux-gnueabi-as -march=armv6 "$ROOT/tests/omap2420/arm1136_d2a_memory.S" \
  -o "$PAYLOAD/arm1136_d2a_regression.o"
arm-linux-gnueabi-ld \
  -T "$ROOT/tests/omap2420/arm1136_d2a_memory.ld" -z max-page-size=0x1000 \
  -o "$PAYLOAD/arm1136_d2a_regression.elf" "$PAYLOAD/arm1136_d2a_regression.o"
set +e
timeout 30 "$QEMU" -M omap2420-earlydiag -cpu arm1136 -m 128M \
  -display none -monitor none -serial none -nic none -no-reboot \
  -kernel "$PAYLOAD/arm1136_d2a_regression.elf" \
  -semihosting-config enable=on,target=native \
  > "$DIAG/gate-d2a-memory-regression.log" 2>&1
REG_RC=$?
set -e
test "$REG_RC" -eq 0
grep -Fx 'D2A_OMAP2420_SRAM=PASS' "$DIAG/gate-d2a-memory-regression.log"
grep -Fx 'D2A_OMAP2420_SDRAM=PASS' "$DIAG/gate-d2a-memory-regression.log"
grep -Fx 'D2A_BOOT_ELF=PASS' "$DIAG/gate-d2a-memory-regression.log"
echo "D2A_BASELINE_REGRESSION=PASS" | tee "$DIAG/regression-status.txt"

STAGE=negative-ram-size-guard
set +e
timeout 15 "$QEMU" -M omap2420-timerdiag -cpu arm1136 -m 256M \
  -display none -monitor none -serial none -nic none \
  > "$DIAG/ram-limit-negative.log" 2>&1
NEG_RC=$?
set -e
test "$NEG_RC" -ne 0 && test "$NEG_RC" -ne 124
grep -F 'RAM must be 16..128 MiB' "$DIAG/ram-limit-negative.log"
echo 'D2D_RAM_GUARD=PASS' >> "$DIAG/regression-status.txt"

STATUS=PASS
STAGE=complete
echo 'GATE_D2D=PASS; ARM1136 OMAP2 PRCM clock gate and GPTimer1 IRQ37 to CPU; full clock tree NOT IMPLEMENTED'
