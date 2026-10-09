#!/usr/bin/env bash
# Gate D1: compile and execute ARM1136/ARMv6 bare metal on pinned UTM QEMU v10.
# Linux GitHub CI ONLY. KZM = Freescale i.MX31, NOT Nokia N95 / OMAP2420.
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out/arm1136-gate-d1"
DIAG="$OUT/diagnostics"
PAYLOAD="$OUT/payload"
WORK="$OUT/work"
URL="https://github.com/utmapp/qemu/releases/download/v10.0.12-utm/qemu-10.0.12-utm.tar.xz"
mkdir -p "$DIAG" "$PAYLOAD" "$WORK"
STATUS=FAIL
STAGE=init

on_exit() {
  local rc=$?
  {
    echo "ARM1136_GATE_D1_STATUS=$STATUS"
    echo "EXIT_CODE=$rc"
    echo "LAST_STAGE=$STAGE"
    echo "QEMU_SOURCE=utmapp/qemu@v10.0.12-utm"
    echo "MACHINE=kzm"
    echo "SOC=Freescale_i.MX31_NOT_OMAP2420"
    echo "CPU=arm1136_ARMv6"
    echo "NOKIA_N95=NOT_IMPLEMENTED"
    echo "IOS_IPA=NOT_BUILT"
    echo "IPHONE_ARM1136_TEST=NOT_RUN"
    echo "UTM_V8_V9=UNMODIFIED"
  } > "$DIAG/BUILD-STATUS.txt"
  echo "ARM1136_GATE_D1_STATUS=$STATUS STAGE=$STAGE EXIT_CODE=$rc"
}
trap on_exit EXIT

STAGE=toolchain
for tool in curl tar gcc make ninja meson pkg-config arm-linux-gnueabi-as arm-linux-gnueabi-ld arm-linux-gnueabi-objdump readelf timeout; do
  command -v "$tool" >/dev/null || { echo "Required tool missing: $tool" >&2; exit 21; }
done
{
  uname -a
  gcc --version | head -n 1
  meson --version
  ninja --version
  arm-linux-gnueabi-as --version | head -n 1
  arm-linux-gnueabi-ld --version | head -n 1
} > "$DIAG/toolchain.txt"

STAGE=fetch-pinned-qemu
ARCHIVE="$WORK/qemu-10.0.12-utm.tar.xz"
curl -fLsS --retry 4 --retry-delay 3 --connect-timeout 30 \
  --max-time 900 "$URL" -o "$ARCHIVE"
test -s "$ARCHIVE"
sha256sum "$ARCHIVE" > "$DIAG/pinned-qemu-source.sha256"
tar -xJf "$ARCHIVE" -C "$WORK"
SRC="$WORK/qemu-10.0.12-utm"
test -f "$SRC/configure"
test -f "$SRC/hw/arm/kzm.c"
test -f "$SRC/hw/arm/fsl-imx31.c"
test -f "$SRC/target/arm/tcg/cpu32.c"
test ! -e "$SRC/hw/arm/omap2.c"
test ! -e "$SRC/hw/arm/nseries.c"

STAGE=verify-pinned-arm1136-source
grep -F 'DEFINE_MACHINE("kzm"' "$SRC/hw/arm/kzm.c" > "$DIAG/kzm-source-proof.txt"
grep -F 'ARM_CPU_TYPE_NAME("arm1136")' "$SRC/hw/arm/fsl-imx31.c" >> "$DIAG/kzm-source-proof.txt"
grep -F '"arm1136",' "$SRC/target/arm/tcg/cpu32.c" >> "$DIAG/kzm-source-proof.txt"
grep -F '#define FSL_IMX31_UART1_ADDR' "$SRC/include/hw/arm/fsl-imx31.h" >> "$DIAG/kzm-source-proof.txt"
grep -F 'case 0x10: /* UTXD */' "$SRC/hw/char/imx_serial.c" >> "$DIAG/kzm-source-proof.txt"
echo 'SOURCE_KZM_ARM1136_UART=PASS' | tee "$DIAG/source-gate.txt"

STAGE=build-native-qemu10-arm-softmmu
mkdir -p "$WORK/build"
(
  cd "$WORK/build"
  "$SRC/configure" --target-list=arm-softmmu \
    --disable-docs --disable-debug-info --disable-werror --disable-rust \
    > "$DIAG/configure.log" 2>&1
  ninja -j 4 > "$DIAG/compile.log" 2>&1
)
QEMU="$WORK/build/qemu-system-arm"
if ! test -x "$QEMU"; then
  find "$WORK/build" -name qemu-system-arm -type f > "$DIAG/executable-candidates.txt"
  echo 'native qemu-system-arm missing; check build log' >&2
  exit 31
fi
"$QEMU" --version | tee "$DIAG/qemu-version.txt"
grep -F '10.0.12' "$DIAG/qemu-version.txt"
"$QEMU" -machine help > "$DIAG/qemu-machines.txt"
"$QEMU" -cpu help > "$DIAG/qemu-arm32-cpus.txt"
grep -E '(^|[[:space:]])kzm([[:space:]]|$)' "$DIAG/qemu-machines.txt"
grep -E '(^|[[:space:]])arm1136([[:space:]]|$)' "$DIAG/qemu-arm32-cpus.txt"
grep -F 'arm1136-r2' "$DIAG/qemu-arm32-cpus.txt"
echo 'PINNED_QEMU10_ARM1136_CPU_MACHINE=PASS' | tee "$DIAG/engine-gate.txt"

STAGE=compile-armv6-baremetal-elf
arm-linux-gnueabi-as -march=armv6 \
  "$ROOT/tests/arm1136/kzm_armv6_uart.S" -o "$PAYLOAD/kzm_armv6_uart.o"
arm-linux-gnueabi-ld \
  -T "$ROOT/tests/arm1136/kzm_armv6.ld" \
  -z max-page-size=0x1000 \
  -o "$PAYLOAD/kzm_armv6_uart.elf" "$PAYLOAD/kzm_armv6_uart.o"
arm-linux-gnueabi-objcopy -O binary \
  "$PAYLOAD/kzm_armv6_uart.elf" "$PAYLOAD/kzm_armv6_uart.bin"
arm-linux-gnueabi-objdump -d "$PAYLOAD/kzm_armv6_uart.elf" \
  > "$DIAG/guest-arm1136-disassembly.txt"
readelf -h -l "$PAYLOAD/kzm_armv6_uart.elf" > "$DIAG/guest-armv6-elf-info.txt"
grep -F 'Entry point address:               0x80010000' "$DIAG/guest-armv6-elf-info.txt"
grep -E '\brev\b' "$DIAG/guest-arm1136-disassembly.txt"
sha256sum "$PAYLOAD/kzm_armv6_uart.elf" "$PAYLOAD/kzm_armv6_uart.bin" \
  > "$DIAG/guest-payload-sha256.txt"

STAGE=run-arm1136-kzm-uart
# '-M kzm' is NOT the OMAP SoC. Its i.MX31 UART at 0x43f90000
# is used to verify ARMv6 instruction dispatch + live MMIO UART output.
set +e
timeout 60 "$QEMU" \
  -M kzm -cpu arm1136 -m 128M \
  -display none -monitor none -serial stdio \
  -nic none -no-reboot \
  -kernel "$PAYLOAD/kzm_armv6_uart.elf" \
  -semihosting-config enable=on,target=native \
  > "$DIAG/arm1136-kzm-serial.log" 2>&1
QEMU_RC=$?
set -e
echo "QEMU_EXIT_CODE=$QEMU_RC" | tee "$DIAG/guest-runtime.txt"
tail -n 80 "$DIAG/arm1136-kzm-serial.log"
grep -Fx 'ARM1136_KZM_UART_MMIO=PASS' "$DIAG/arm1136-kzm-serial.log"
grep -Fx 'ARM1136_ARMV6_REV_INSTRUCTION=PASS' "$DIAG/arm1136-kzm-serial.log"
grep -Fx 'ARM1136_BAREMETAL_BOOT=PASS' "$DIAG/arm1136-kzm-serial.log"
if test "$QEMU_RC" -ne 0; then
  echo "KZM ARM1136 emitted success markers but did not exit cleanly: code=$QEMU_RC" >&2
  exit 41
fi
echo 'HOST_ARM1136_KZM_ARMV6_EXECUTION=PASS' >> "$DIAG/guest-runtime.txt"
STATUS=PASS
STAGE=complete
echo 'GATE_D1=PASS; ARM1136 ARMv6 instructions and UART executed; NOT OMAP2420'
