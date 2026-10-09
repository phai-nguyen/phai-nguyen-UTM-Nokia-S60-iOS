#!/usr/bin/env bash
# Gate D2a: QEMU 10 minimal OMAP2420-style map ARM1136 + SRAM/SDRAM.
# This is NOT full OMAP2420, not Nokia N95 and not Symbian.
# We use semihosting, NOT a UART device (OMAP UART belongs to D2b).
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out/omap2420-d2a"
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
    echo "GATE_D2A_STATUS=$STATUS"
    echo "EXIT_CODE=$rc"
    echo "LAST_STAGE=$STAGE"
    echo "QEMU_SOURCE=utmapp/qemu@v10.0.12-utm"
    echo "MACHINE=omap2420-earlydiag"
    echo "CPU=arm1136_ARMv6"
    echo "SRAM=0x40200000:0xA0000"
    echo "SDRAM=0x80000000:128MiB"
    echo "DIAGNOSTIC_OUTPUT=ARM_SEMIHOSTING_NOT_UART"
    echo "OMAP2420_UART_INTC_CLOCKS=NOT_IMPLEMENTED"
    echo "NOKIA_N95_SYMBIAN=NOT_IMPLEMENTED"
    echo "IOS_IPA=NOT_BUILT"
    echo "IPHONE_D2A_TEST=NOT_RUN"
    echo "UTM_V8_V9_BASELINES=UNMODIFIED"
  } > "$DIAG/BUILD-STATUS.txt"
  echo "GATE_D2A_STATUS=$STATUS STAGE=$STAGE EXIT_CODE=$rc"
}
trap on_exit EXIT

STAGE=toolchain
for t in curl tar grep diff gcc meson ninja pkg-config arm-linux-gnueabi-as arm-linux-gnueabi-ld arm-linux-gnueabi-objcopy arm-linux-gnueabi-objdump readelf timeout; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t" >&2; exit 21; }
done
{
  gcc --version | head -n1
  meson --version
  ninja --version
  arm-linux-gnueabi-as --version | head -n1
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
test ! -e "$SRC/hw/arm/omap2.c"
test ! -e "$SRC/hw/arm/nseries.c"
test ! -e "$SRC/hw/arm/omap2420_diag_d2a.c"
grep -F '"arm1136",' "$SRC/target/arm/tcg/cpu32.c" | tee "$DIAG/pinned-arm1136-confirmation.txt"

STAGE=patch-minimal-machine
python3 - "$SRC" "$ROOT/tests/omap2420/omap2420_diag_d2a.c" "$DIAG" <<'PY'
from pathlib import Path
import sys

src, newcode, diag = (Path(x) for x in sys.argv[1:])
meson = src / "hw/arm/meson.build"
kconfig = src / "hw/arm/Kconfig"
target = src / "hw/arm/omap2420_diag_d2a.c"
assert not target.exists()
assert "OMAP2420_DIAG_D2A" not in meson.read_text()
assert "OMAP2420_DIAG_D2A" not in kconfig.read_text()
meson_anchor = "arm_ss.add(when: 'CONFIG_FSL_IMX31', if_true: files('fsl-imx31.c', 'kzm.c'))"
assert meson.read_text().count(meson_anchor) == 1
meson.write_text(meson.read_text().replace(
    meson_anchor,
    meson_anchor + "\n" + "arm_ss.add(when: 'CONFIG_OMAP2420_DIAG_D2A', if_true: files('omap2420_diag_d2a.c'))",
    1
))
with kconfig.open("a") as f:
    f.write("\n# UTM-Nokia isolated early diagnostic: CPU/SRAM/SDRAM only, not Nokia N95.\n")
    f.write("config OMAP2420_DIAG_D2A\n    bool\n    default y\n\n")
target.write_bytes(newcode.read_bytes())
(diag / "patch-manifest.txt").write_text(
    "SOURCE_CODE=tests/omap2420/omap2420_diag_d2a.c\n"
    "INJECTED_FILE=hw/arm/omap2420_diag_d2a.c\n"
    "MESON_CONFIG=CONFIG_OMAP2420_DIAG_D2A\n"
    "OMAP_UART=NOT_ADDED\nNOKIA_FIRMWARE=NOT_ADDED\n"
)
print("D2A_MINIMAL_MACHINE_SOURCE_PATCH=PASS")
PY

STAGE=build-pinned-qemu10-arm32
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
grep -E '(^|[[:space:]])arm1136([[:space:]]|$)' "$DIAG/cpu-list.txt"
! grep -E '^nokia-n95[[:space:]]' "$DIAG/machine-list.txt"
echo "D2A_MINIMAL_QEMU_MACHINE_COMPILE=PASS" > "$DIAG/source-and-build-gate.txt"

STAGE=assemble-armv6-memory-test
arm-linux-gnueabi-as -march=armv6 \
  "$ROOT/tests/omap2420/arm1136_d2a_memory.S" \
  -o "$PAYLOAD/arm1136_d2a_memory.o"
arm-linux-gnueabi-ld \
  -T "$ROOT/tests/omap2420/arm1136_d2a_memory.ld" \
  -z max-page-size=0x1000 \
  -o "$PAYLOAD/arm1136_d2a_memory.elf" "$PAYLOAD/arm1136_d2a_memory.o"
arm-linux-gnueabi-objcopy -O binary \
  "$PAYLOAD/arm1136_d2a_memory.elf" "$PAYLOAD/arm1136_d2a_memory.bin"
arm-linux-gnueabi-objdump -d "$PAYLOAD/arm1136_d2a_memory.elf" \
  > "$DIAG/armv6-guest-disassembly.txt"
readelf -h -l "$PAYLOAD/arm1136_d2a_memory.elf" \
  > "$DIAG/armv6-guest-elf.txt"
grep -F '0x80010000' "$DIAG/armv6-guest-elf.txt"
grep -E '\brev\b' "$DIAG/armv6-guest-disassembly.txt"
sha256sum "$PAYLOAD/arm1136_d2a_memory.elf" > "$DIAG/guest-sha256.txt"

STAGE=run-earlydiag-arm1136-sram-sdram
# Log is ARM semihosting SYS_WRITE0, NO UART exists on Gate D2a.
set +e
timeout 60 "$QEMU" \
  -M omap2420-earlydiag -cpu arm1136 -m 128M \
  -display none -monitor none -serial none -nic none -no-reboot \
  -kernel "$PAYLOAD/arm1136_d2a_memory.elf" \
  -semihosting-config enable=on,target=native \
  > "$DIAG/arm1136-earlydiag-runtime.log" 2>&1
RC=$?
set -e
echo "QEMU_EXIT_CODE=$RC" | tee "$DIAG/runtime-status.txt"
tail -n 75 "$DIAG/arm1136-earlydiag-runtime.log"
for marker in \
  "D2A_OMAP2420_SRAM=PASS" \
  "D2A_OMAP2420_SDRAM=PASS" \
  "D2A_ARM1136_REV=PASS" \
  "D2A_BOOT_ELF=PASS" \
  "D2A_UART=NOT_IMPLEMENTED"; do
  grep -Fx "$marker" "$DIAG/arm1136-earlydiag-runtime.log"
done
test "$RC" -eq 0 || { echo "QEMU didn't exit cleanly: $RC" >&2; exit 41; }
echo 'D2A_ARM1136_SRAM_SDRAM_ELF_EXECUTION=PASS' >> "$DIAG/runtime-status.txt"

STAGE=negative-ram-size-boundary-test
set +e
timeout 15 "$QEMU" -M omap2420-earlydiag -cpu arm1136 -m 256M \
  -display none -monitor none -serial none -nic none \
  > "$DIAG/ram-boundary-negative.log" 2>&1
RC_BAD_RAM=$?
set -e
test "$RC_BAD_RAM" -ne 0 && test "$RC_BAD_RAM" -ne 124 || {
  echo "Unexpected missing/timeout RAM guard ($RC_BAD_RAM)" >&2; exit 42;
}
grep -F 'RAM must be 16..128 MiB' "$DIAG/ram-boundary-negative.log"
echo 'D2A_RAM_BOUNDARY_GUARD=PASS' > "$DIAG/negative-test.txt"

STATUS=PASS
STAGE=complete
echo 'GATE_D2A=PASS; ARM1136 SRAM/SDRAM/ELF; NOT FULL OMAP2420 OR NOKIA N95'
