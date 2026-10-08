#!/usr/bin/env bash
# Research-only: ARM32/TCI compile against pinned UTM iOS sysroot; never build/modify baseline IPA.
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UTM_ROOT="$ROOT/upstream/UTM"
OUT="$ROOT/out/arm32-diagnostic"
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
export PKG_CONFIG="$(command -v pkg-config)"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
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

STAGE='verify-original-seven-unchanged'
: > "$DIAG/seven-frameworks-after.sha256"
for cpu in $KNOWN; do
    shasum -a 256 "$PREFIX/Frameworks/qemu-$cpu-softmmu.framework/qemu-$cpu-softmmu" \
      >> "$DIAG/seven-frameworks-after.sha256"
done
diff -u "$DIAG/seven-frameworks-before.sha256" "$DIAG/seven-frameworks-after.sha256" \
    > "$DIAG/baseline-hash-diff.txt"
echo 'SEVEN_FRAMEWORKS=UNCHANGED' > "$DIAG/baseline-integrity.txt"
echo 'NOKIA_HARDWARE=NOT_IMPLEMENTED' >> "$DIAG/baseline-integrity.txt"
STATUS='PASS'
STAGE='complete'
echo 'ARM32_FRAMEWORK_DIAG=PASS; NO IPA BUILT; NO IPHONE DEVICE TEST'
