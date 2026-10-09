#!/usr/bin/env bash
# Build pinned UTM SE as an unsigned, independently installable bundle-ID IPA.
# Requires macOS + Xcode + a matching sysroot-ios-tci-arm64 from UTM.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UTM_ROOT="${UTM_ROOT:-$ROOT/upstream/UTM}"
OUT_DIR="${OUT_DIR:-$ROOT/out}"
ARCHIVE="$OUT_DIR/UTMSE.xcarchive"
APP="$ARCHIVE/Products/Applications/UTM SE.app"
BUNDLE_PREFIX="${BUNDLE_PREFIX:-com.phai.nokias60}"

mkdir -p "$OUT_DIR" "$OUT_DIR/diagnostics"
exec > >(tee "$OUT_DIR/diagnostics/build-console.log") 2>&1

on_exit() {
  code=$?
  if [[ "$code" -eq 0 ]]; then status=PASS; else status=FAIL; fi
  printf 'STATUS=%s\nEXIT_CODE=%s\nUTM_COMMIT=%s\nBUNDLE_PREFIX=%s\n' "$status" "$code"     "${UTM_COMMIT:-unknown}" "$BUNDLE_PREFIX" > "$OUT_DIR/diagnostics/BUILD-STATUS.txt"
}
trap on_exit EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macOS runner required."; exit 2
fi
if [[ ! -d "$UTM_ROOT/.git" ]] || [[ ! -d "$UTM_ROOT/sysroot-ios-tci-arm64" ]]; then
  echo "ERROR: Expected checkout and matching sysroot at $UTM_ROOT"
  exit 3
fi
UTM_COMMIT="$(git -C "$UTM_ROOT" rev-parse HEAD)"
if [[ "$UTM_COMMIT" != "7eadb056ae0f91d979059544d0ddcd2d5a40be92" ]]; then
  echo "ERROR: UTM ref differs from pinned version: $UTM_COMMIT"
  exit 4
fi
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
mkdir -p "$OUT_DIR"
(
  cd "$UTM_ROOT"
  xcodebuild archive \
    -project UTM.xcodeproj \
    -scheme iOS-SE \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE" \
    -skipPackagePluginValidation \
    ARCHS=arm64 \
    PRODUCT_BUNDLE_PREFIX="$BUNDLE_PREFIX" \
    CODE_SIGNING_ALLOWED=NO
)
if [[ ! -d "$APP" ]]; then
  echo "ERROR: app missing from xcarchive: $APP"; exit 5
fi

# ARM32-v9 opt-in only: upstream's iOS-SE target doesn't embed arm-softmmu
# even when this QEMU framework is present in the temporary build sysroot.
# Stage the verified research dylib AFTER archive and BEFORE generating IPA.
# No effect unless ARM32_EXTRA_FRAMEWORK is provided by the v9-only workflow.
if [[ -n "${ARM32_EXTRA_FRAMEWORK:-}" ]]; then
  EXTRA_SRC="$ARM32_EXTRA_FRAMEWORK"
  EXTRA_BIN="$EXTRA_SRC/qemu-arm-softmmu"
  EXTRA_DST="$APP/Frameworks/qemu-arm-softmmu.framework"
  test -s "$EXTRA_BIN" || {
    echo "ERROR: ARM32_EXTRA_FRAMEWORK missing qemu-arm-softmmu: $EXTRA_SRC"; exit 6;
  }
  test ! -e "$EXTRA_DST" || {
    echo "ERROR: unexpected ARM32 framework already exists in Xcode archive"; exit 7;
  }
  mkdir -p "$APP/Frameworks"
  cp -R "$EXTRA_SRC" "$EXTRA_DST"
  test -s "$EXTRA_DST/qemu-arm-softmmu"
  cmp "$EXTRA_BIN" "$EXTRA_DST/qemu-arm-softmmu"
  shasum -a 256 "$EXTRA_BIN" "$EXTRA_DST/qemu-arm-softmmu" \
    | tee "$OUT_DIR/diagnostics/arm32-v9-injected-framework.sha256"
  otool -L "$EXTRA_DST/qemu-arm-softmmu" \
    > "$OUT_DIR/diagnostics/arm32-v9-injected-framework.otool"
  echo 'ARM32_FRAMEWORK_STAGED_BEFORE_IPA=PASS'
fi
IPA_STAGING="$OUT_DIR/ipa-staging"
rm -rf "$IPA_STAGING"
mkdir -p "$IPA_STAGING/Payload"
cp -R "$APP" "$IPA_STAGING/Payload/"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" |
  tee "$OUT_DIR/diagnostics/bundle-id.txt"
IPA="$OUT_DIR/NokiaUTM-SE-v1-unsigned.ipa"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$IPA_STAGING/Payload" "$IPA"
unzip -t "$IPA" >/dev/null
echo "STATUS=PASS IPA=$IPA"
echo "NOTE: Unsigned UTM SE base, NOT Nokia firmware support. Sign with ESign."
