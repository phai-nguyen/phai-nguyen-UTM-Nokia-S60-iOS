#!/usr/bin/env bash
# Research-only: ARM32/TCI compile against pinned UTM iOS sysroot; never build/modify baseline IPA.
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UTM_ROOT="$ROOT/upstream/UTM"
OUT="$ROOT/out/omap2420-d2e-ios-tci"
DIAG="$OUT/diagnostics"
PREFIX="$UTM_ROOT/sysroot-ios-tci-arm64"
SOURCE_URL='https://github.com/utmapp/qemu/releases/download/v10.0.12-utm/qemu-10.0.12-utm.tar.xz'
UTM_SHA='7eadb056ae0f91d979059544d0ddcd2d5a40be92'
KNOWN='aarch64 i386 x86_64 ppc ppc64 riscv64 m68k'
mkdir -p "$DIAG"
STATUS='FAIL'
STAGE='init'
on_exit() {
    rc=$?
    # Capture configure/Meson error details even if configure fails before ninja.
    if test -d "$OUT/work/build"; then
        cp -f "$OUT/work/build/config.log" "$DIAG/qemu-config.log" 2>/dev/null || true
        cp -f "$OUT/work/build/config-host.mak" "$DIAG/config-host.mak" 2>/dev/null || true
        cp -f "$OUT/work/build/meson-logs/meson-log.txt" "$DIAG/meson-log.txt" 2>/dev/null || true
    fi
    {
        echo "STATUS=$STATUS"
        echo "EXIT_CODE=$rc"
        echo "LAST_STAGE=$STAGE"
        echo "UTM_SHA=$UTM_SHA"
        echo "QEMU_RELEASE=v10.0.12-utm"
        echo "TARGET=arm-softmmu"
        echo "IOS_IPA=NOT_BUILT"
        echo "DEVICE_TEST=NOT_RUN"
        echo "NOKIA_N95=NOT_IMPLEMENTED"
        echo "OMAP2420_MACHINE=DIAGNOSTIC_SUBSET_ONLY"
        echo "IPHONE_OMAP2420=NOT_TESTED"
    } > "$DIAG/BUILD-STATUS.txt"
    echo "ARM32_DIAGNOSTIC_STATUS=$STATUS EXIT_CODE=$rc STAGE=$STAGE"
}
trap on_exit EXIT

STAGE='validate-pins'
test "$(uname -s)" = Darwin
test "$(git -C "$UTM_ROOT" rev-parse HEAD)" = "$UTM_SHA"
test -d "$PREFIX/Frameworks"
grep -Fx "QEMU_SRC=\"$SOURCE_URL\"" "$UTM_ROOT/patches/sources"
SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
{
    echo "UTM_SHA=$UTM_SHA"
    echo "SOURCE_URL=$SOURCE_URL"
    echo "SYSROOT_ACTION_RUN=36090554968"
    echo "SDKROOT=$SDKROOT"
    xcodebuild -version
    xcrun --sdk iphoneos --show-sdk-version
    meson --version
    ninja --version
} > "$DIAG/provenance.txt"

STAGE='seven-engine-preflight'
: > "$DIAG/seven-frameworks-before.sha256"
for cpu in $KNOWN; do
    bin="$PREFIX/Frameworks/qemu-$cpu-softmmu.framework/qemu-$cpu-softmmu"
    test -s "$bin" || { echo "Missing baseline engine: $bin" >&2; exit 21; }
    shasum -a 256 "$bin" >> "$DIAG/seven-frameworks-before.sha256"
done

STAGE='download-pinned-qemu'
WORK="$OUT/work"
mkdir -p "$WORK/src"
ARCHIVE="$WORK/qemu-10.0.12-utm.tar.xz"
curl --fail --location --retry 4 --retry-all-errors --connect-timeout 30 \
    --max-time 1200 --output "$ARCHIVE" "$SOURCE_URL"
test -s "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > "$DIAG/qemu-source-archive.sha256"
tar -tJf "$ARCHIVE" > "$DIAG/qemu-source-members.txt"
tar -xJf "$ARCHIVE" -C "$WORK/src"
QEMU_DIR="$WORK/src/qemu-10.0.12-utm"
test -f "$QEMU_DIR/configure"
test -f "$QEMU_DIR/meson.build"
test ! -e "$QEMU_DIR/hw/arm/omap2.c"
test ! -e "$QEMU_DIR/hw/arm/nseries.c"

# Reuse EXACT gate-D2d source patch that passed on Linux host. Do not
# patch any checked-in upstream revision or iOS app tree.
STAGE='inject-omap2420-d2a-d2d-machines'
SRC="$QEMU_DIR"
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
print("D2E_PINNED_QEMU10_SOURCE_PATCH=PASS")
PY

shasum -a 256 "$QEMU_DIR"/hw/arm/omap2420_diag_d2?.c \
  > "$DIAG/diagnostic-machine-sources.sha256"
echo 'D2E_FOUR_DIAGNOSTIC_MACHINES_PATCHED=PASS' | tee "$DIAG/patch-status.txt"

STAGE='setup-ios-compiler'
export PATH="$PREFIX/host/bin:$PATH"
export CC="$(xcrun --sdk iphoneos --find clang) -target arm64-apple-ios15.0"
export CPP="$(xcrun --sdk iphoneos --find clang) -E"
export CXX="$(xcrun --sdk iphoneos --find clang++) -target arm64-apple-ios15.0"
export OBJCC="$(xcrun --sdk iphoneos --find clang) -target arm64-apple-ios15.0"
export AR="$(xcrun --sdk iphoneos --find ar)"
export NM="$(xcrun --sdk iphoneos --find nm)"
export RANLIB="$(xcrun --sdk iphoneos --find ranlib)"
export STRIP="$(xcrun --sdk iphoneos --find strip)"
# The downloaded UTM sysroot's host/bin/pkg-config may be an unavailable/stale
# host tool on this runner. Explicitly select the freshly installed macOS
# Homebrew pkgconf while resolving .pc metadata strictly from the iOS sysroot.
HOST_PKGCONF="$(brew --prefix pkgconf)/bin/pkgconf"
test -x "$HOST_PKGCONF" || { echo "Host pkgconf missing: $HOST_PKGCONF" >&2; exit 24; }
export PKG_CONFIG="$HOST_PKGCONF"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
unset PKG_CONFIG_SYSROOT_DIR
# Upstream's exported sysroot bundles .pc files that embed absolute paths from
# its ORIGINAL GitHub runner (for example /Users/runner/actions/runner-2/...).
# Such references prevent Meson from including glibconfig.h and incorrectly
# trigger "sizeof(size_t) doesn't match GLIB_SIZEOF_SIZE_T". Rebase metadata
# only in the ephemeral downloaded CI sysroot; never alter any framework files.
STAGE='rebase-pkgconfig-metadata'
python3 - "$PREFIX" > "$DIAG/pkgconfig-rebase.txt" <<'PY'
from pathlib import Path
import re
import sys

sysroot = Path(sys.argv[1]).resolve()
glib_pc = sysroot / "lib/pkgconfig/glib-2.0.pc"
if not glib_pc.is_file():
    sys.exit(f"Cannot find original iOS GLib metadata: {glib_pc}")
data = glib_pc.read_text()
match = re.search(r"(?m)^prefix=(.+)$", data)
if not match:
    sys.exit("GLib .pc has no literal prefix; cannot safely rebase")
old_prefix = match.group(1).strip()
new_prefix = str(sysroot)
print(f"GLIB_OLD_PREFIX={old_prefix}")
print(f"GLIB_NEW_PREFIX={new_prefix}")
if not old_prefix.startswith("/") or not new_prefix.startswith("/"):
    sys.exit("Refusing to rewrite a non-absolute prefix")
updated = 0
for pc in sorted(sysroot.rglob("*.pc")):
    text = pc.read_text()
    if old_prefix in text and old_prefix != new_prefix:
        pc.write_text(text.replace(old_prefix, new_prefix))
        updated += 1
print(f"PKGCONFIG_FILES_REBASED={updated}")
if old_prefix != new_prefix and updated == 0:
    sys.exit("Expected original runner paths, but no pkg-config files were updated")
print("PKGCONFIG_METADATA_REBASE=PASS")
PY
STAGE='pkg-config-preflight'
{
    echo "HOST_PKG_CONFIG=$PKG_CONFIG"
    "$PKG_CONFIG" --version
    "$PKG_CONFIG" --variable=prefix glib-2.0
    "$PKG_CONFIG" --modversion glib-2.0
    "$PKG_CONFIG" --cflags glib-2.0
    "$PKG_CONFIG" --libs glib-2.0
} > "$DIAG/pkg-config-preflight.txt" 2>&1 || {
    cat "$DIAG/pkg-config-preflight.txt"
    echo 'ERROR: macOS pkgconf cannot resolve iOS sysroot GLib; inspect pkg-config-preflight.txt' >&2
    exit 25
}
export CFLAGS="-arch arm64 -isysroot $SDKROOT -I$PREFIX/include -F$PREFIX/Frameworks -Wno-unused-command-line-argument"
export CPPFLAGS="$CFLAGS"
export CXXFLAGS="$CFLAGS"
export OBJCFLAGS="$CFLAGS"
export LDFLAGS="-arch arm64 -isysroot $SDKROOT -L$PREFIX/lib -F$PREFIX/Frameworks -target arm64-apple-ios15.0 -Wl,-no_deduplicate -Wl,-random_uuid -Wl,-no_compact_unwind"
export ac_cv_func_pipe2=no
export ac_cv_func_dup3=no
mkdir -p "$WORK/build"
{
    echo "CC=$CC"
    echo "CFLAGS=$CFLAGS"
    echo "LDFLAGS=$LDFLAGS"
    echo "PKG_CONFIG=$PKG_CONFIG"
    echo "PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR"
} > "$DIAG/toolchain.txt"

STAGE='configure-arm-softmmu'
cd "$WORK/build"
"$QEMU_DIR/configure" \
    --prefix="$PREFIX" --host=aarch64-apple-darwin --cross-prefix="" \
    --enable-shared-lib --disable-cocoa --disable-sdl --disable-coreaudio \
    --disable-slirp-smbd --enable-ucontext --with-coroutine=libucontext \
    --enable-hvf-private --enable-tcg-threaded-interpreter \
    --target-list=arm-softmmu --disable-debug-info --disable-docs --disable-rust \
    --extra-cflags="-Wno-unused-command-line-argument" \
    --extra-ldflags="-Wl,-no_deduplicate" \
    --extra-ldflags="-Wl,-random_uuid" \
    --extra-ldflags="-Wl,-no_compact_unwind" \
    2>&1 | tee "$DIAG/configure-console.log"
cp config.log "$DIAG/qemu-config.log" 2>/dev/null || true
cp config-host.mak "$DIAG/config-host.mak" 2>/dev/null || true
cp meson-logs/meson-log.txt "$DIAG/meson-log.txt" 2>/dev/null || true
test -f build.ninja
grep -F 'arm-softmmu' config-host.mak > "$DIAG/target-confirmation.txt"

STAGE='compile-arm-softmmu'
ninja -j 4 2>&1 | tee "$DIAG/compile-console.log"
cp meson-logs/meson-log.txt "$DIAG/meson-log.txt" 2>/dev/null || true

STAGE='inspect-library'
find "$WORK/build" -type f \( -name '*arm-softmmu*.dylib' -o -name '*arm-softmmu*.so' \) \
    > "$DIAG/library-candidates.txt"
DYLIB="$(grep -E '/libqemu-arm-softmmu\.dylib$' "$DIAG/library-candidates.txt" | head -n 1 || true)"
test -n "$DYLIB" && test -s "$DYLIB" || {
    echo "ARM32 dylib missing: inspect library-candidates.txt" >&2; exit 31;
}
file "$DYLIB" > "$DIAG/arm32-file.txt"
xcrun lipo -info "$DYLIB" > "$DIAG/arm32-lipo.txt"
otool -L "$DYLIB" > "$DIAG/arm32-otool-before.txt"
vtool -show-build-version "$DYLIB" > "$DIAG/arm32-build-version.txt"
grep -q arm64 "$DIAG/arm32-file.txt"

STAGE='stage-research-framework'
# Changes only the ephemeral sysroot copy in this CI run. This is NOT an iPhone IPA.
bash "$UTM_ROOT/scripts/fixup.sh" -p ios-tci -s "$PREFIX" -m 15.0 "$DYLIB" \
    2>&1 | tee "$DIAG/fixup-framework.log"
FW="$PREFIX/Frameworks/qemu-arm-softmmu.framework"
test -s "$FW/qemu-arm-softmmu"
otool -L "$FW/qemu-arm-softmmu" > "$DIAG/arm32-otool-after.txt"
vtool -show-build-version "$FW/qemu-arm-softmmu" >> "$DIAG/arm32-build-version.txt"
shasum -a 256 "$FW/qemu-arm-softmmu" > "$DIAG/arm32-framework.sha256"
mkdir -p "$OUT/framework"
cp -R "$FW" "$OUT/framework/"
python3 - "$FW/qemu-arm-softmmu" "$PREFIX/Frameworks" > "$DIAG/rpath-closure.txt" <<'PY'
import pathlib, subprocess, sys
binary, frameworks = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
missing = []
for line in subprocess.check_output(['otool','-L',str(binary)], text=True).splitlines()[1:]:
    dep = line.strip().split(' (compatibility')[0]
    if dep.startswith('@rpath/') and '.framework/' in dep:
        p = frameworks / dep[len('@rpath/'):]
        print(('PASS ' if p.exists() else 'MISSING ') + dep)
        if not p.exists():
            missing.append(dep)
if missing:
    raise SystemExit('Missing framework imports: ' + ', '.join(missing))
print('LINKED_FRAMEWORK_CLOSURE=PASS')
PY

STAGE='verify-embedded-machine-registrations'
# On macOS, /usr/bin/strings is Mach-O section-aware: its default scan can
# omit plain C literals from sections other than __TEXT,__cstring. Using its
# stdout as a pass/fail oracle produced a false-negative AFTER linking four
# ARM1136 source modules. Inspect exact NUL-terminated bytes directly in
# both the raw Mach-O dylib and the final staged iOS framework instead.
# This verifies linked literal presence; it does NOT prove runtime boot.
python3 - "$DYLIB" "$FW/qemu-arm-softmmu" \
           "$DIAG/machine-registration-byte-audit.txt" <<'PY'
from pathlib import Path
import sys
raw, staged, output = (Path(x) for x in sys.argv[1:])
names = (
    b"omap2420-earlydiag",
    b"omap2420-uartdiag",
    b"omap2420-intcdiag",
    b"omap2420-timerdiag",
)
results = []
missing = []
for label, p in (("raw_macho", raw), ("staged_framework", staged)):
    data = p.read_bytes()
    results.append(f"{label}: bytes={len(data)}")
    for name in names:
        # Requiring trailing NUL rules out an accidental substring match.
        offset = data.find(name + b"\0")
        outcome = "PASS" if offset >= 0 else "MISSING"
        results.append(f"{label}: {name.decode()}={outcome} offset={offset}")
        if offset < 0:
            missing.append((label, name.decode()))
output.write_text("\n".join(results) + "\n", encoding="utf-8")
print("\n".join(results), flush=True)
if missing:
    sys.exit("Missing linked machine names in framework: " + repr(missing))
print("D2E_FOUR_OMAP_MACHINE_BYTE_SCAN=PASS", flush=True)
PY
echo 'D2E_FOUR_OMAP_DIAGNOSTIC_MACHINE_NAMES_IN_IOS_FRAMEWORK=PASS' \
    > "$DIAG/machine-symbol-gate.txt"

STAGE='verify-original-seven-unchanged'
: > "$DIAG/seven-frameworks-after.sha256"
for cpu in $KNOWN; do
    shasum -a 256 "$PREFIX/Frameworks/qemu-$cpu-softmmu.framework/qemu-$cpu-softmmu" \
      >> "$DIAG/seven-frameworks-after.sha256"
done
diff -u "$DIAG/seven-frameworks-before.sha256" "$DIAG/seven-frameworks-after.sha256" \
    > "$DIAG/baseline-hash-diff.txt"
echo 'SEVEN_FRAMEWORKS=UNCHANGED' > "$DIAG/baseline-integrity.txt"
echo 'NOKIA_N95_FIRMWARE=NOT_IMPLEMENTED' >> "$DIAG/baseline-integrity.txt"
echo 'OMAP2420_SUBSET=CPU_MEMORY_UART_INTC_PRCM_GPTIMER1' >> "$DIAG/baseline-integrity.txt"
STATUS='PASS'
STAGE='complete'
echo 'D2E_IOS_TCI_FRAMEWORK=PASS; FOUR_DIAGNOSTIC_MACHINES=EMBEDDED; NO IPA BUILT; NO IPHONE DEVICE TEST'
