#!/usr/bin/env bash
# Research-only Linux armv7 QEMU virt smoke test. No UTM IPA / Nokia ROM / firmware modification.
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out/alpine-arm32-virt"
KIT="$OUT/kit"
LOG="$OUT/diagnostics"
WORK="$OUT/work"
BASE="https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/armv7"
RELEASE="3.24.2"
mkdir -p "$KIT" "$LOG" "$WORK/rootfs"
STATUS=FAIL
STAGE=init
on_exit() {
  rc=$?
  {
    echo "STATUS=$STATUS"
    echo "EXIT_CODE=$rc"
    echo "LAST_STAGE=$STAGE"
    echo "ALPINE_RELEASE=$RELEASE"
    echo "ARCH=armv7"
    echo "QEMU_MACHINE=virt"
    echo "HOST_TEST=ubuntu-qemu-system-arm"
    echo "IPHONE_DEVICE_TEST=NOT_RUN"
    echo "NOKIA_OMAP2420=NOT_IMPLEMENTED"
    echo "UTM_LITE_V8=UNMODIFIED"
  } > "$LOG/BUILD-STATUS.txt"
  echo "ALPINE_ARM32_KIT_STATUS=$STATUS STAGE=$STAGE EXIT=$rc"
}
trap on_exit EXIT

STAGE=download-and-verify
ROOTFS="alpine-minirootfs-$RELEASE-armv7.tar.gz"
curl -fLsS --retry 4 --retry-delay 2 -o "$WORK/$ROOTFS" "$BASE/$ROOTFS"
curl -fLsS --retry 4 --retry-delay 2 -o "$WORK/$ROOTFS.sha256" "$BASE/$ROOTFS.sha256"
(cd "$WORK" && sha256sum -c "$ROOTFS.sha256") | tee "$LOG/minirootfs-sha256-verify.txt"
curl -fLsS --retry 4 --retry-delay 2 -o "$KIT/vmlinuz-lts" "$BASE/netboot/vmlinuz-lts"
test -s "$KIT/vmlinuz-lts"
sha256sum "$KIT/vmlinuz-lts" "$WORK/$ROOTFS" > "$LOG/source-files.sha256"

STAGE=prepare-initramfs
tar -xzf "$WORK/$ROOTFS" -C "$WORK/rootfs"
test -x "$WORK/rootfs/bin/sh"
test -f "$WORK/rootfs/etc/alpine-release"
test "$(cat "$WORK/rootfs/etc/alpine-release")" = "$RELEASE"
mkdir -p "$WORK/rootfs"/{dev,proc,sys,run,tmp}
sudo mknod -m 600 "$WORK/rootfs/dev/console" c 5 1
sudo mknod -m 666 "$WORK/rootfs/dev/null" c 1 3
cat > "$WORK/rootfs/init" <<'INIT'
#!/bin/sh
# Alpine armv7 rootfs; executed as PID 1 by rdinit=/init.
/bin/mount -t devtmpfs devtmpfs /dev || :
/bin/mount -t proc proc /proc || :
/bin/mount -t sysfs sysfs /sys || :
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
echo "=== Alpine Linux ARM32 QEMU virt ==="
echo "ALPINE_ARM32_BOOT=PASS"
echo "ALPINE_ARCH=$(uname -m)"
echo "ALPINE_RELEASE=$(cat /etc/alpine-release)"
echo "ALPINE_ARM32_SMOKE_PASS"
if /bin/grep -q 'arm32_smoke=1' /proc/cmdline; then
  /sbin/poweroff -f || /bin/busybox poweroff -f || :
  /bin/sleep 2
  echo "ALPINE_POWEROFF_FALLBACK"
fi
echo "Goi lenh: uname -m ; cat /etc/alpine-release ; poweroff -f"
/bin/sh </dev/console >/dev/console 2>&1
# PID1 should not exit if user quits shell
while true; do /bin/sleep 3600; done
INIT
chmod 755 "$WORK/rootfs/init"
(
  cd "$WORK/rootfs"
  find . -print0 | cpio --null --quiet -o --format=newc --owner=0:0 | gzip -9 > "$KIT/initramfs-armv7.cpio.gz"
)
test -s "$KIT/initramfs-armv7.cpio.gz"
file "$KIT/vmlinuz-lts" "$KIT/initramfs-armv7.cpio.gz" | tee "$LOG/image-file-info.txt"

cat > "$KIT/README-VI.txt" <<'README'
ALPINE LINUX 3.24.2 ARMv7 — QEMU ARM32 VIRT SMOKE KIT
=====================================================
Muc dich: kiem thu thuc thi guest ARM32 trong QEMU -M virt,
khong phai ROM Nokia N95 va khong phai file IPA.

Bo file:
  vmlinuz-lts                    Kernel Linux ARMv7 cua Alpine
  initramfs-armv7.cpio.gz        Alpine mini rootfs va /init tu dong in marker
  SHA256SUMS                     Checksum kernel + initramfs

LENH CHAY BANG QEMU-SYSTEM-ARM TREN PC/LINUX:
qemu-system-arm -M virt -cpu cortex-a15 -m 256M -nographic -no-reboot \
  -kernel vmlinuz-lts -initrd initramfs-armv7.cpio.gz \
  -append "console=ttyAMA0,115200 rdinit=/init loglevel=5" -net none

Khi hien:
  ALPINE_ARM32_BOOT=PASS
  ALPINE_ARCH=armv7l
  ALPINE_ARM32_SMOKE_PASS
hay thu:
  uname -m
  cat /etc/alpine-release
  poweroff -f

CHU Y: UTM SE Lite v8 hien KHONG chua qemu-arm-softmmu.framework.
KHONG the chon ISO/ZIP nay trong v8 va mong doi may ao ARM32 khoi dong.
Can ban IPA nghien cuu ARM32 rieng va launch/config phu hop.
CI smoke test tren Linux host KHONG thay the device test tren iPhone.
Nguon Alpine chinh thuc: https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/armv7/
README
(cd "$KIT" && sha256sum vmlinuz-lts initramfs-armv7.cpio.gz > SHA256SUMS)

STAGE=linux-host-smoke
# Fail when QEMU cannot execute ARMv7 in the Linux guest; never mark build PASS on compilation alone.
set +e
timeout 180 qemu-system-arm \
  -M virt -cpu cortex-a15 -m 256M -nographic -no-reboot \
  -kernel "$KIT/vmlinuz-lts" -initrd "$KIT/initramfs-armv7.cpio.gz" \
  -append 'console=ttyAMA0,115200 rdinit=/init loglevel=5 arm32_smoke=1' \
  -net none > "$LOG/qemu-arm32-boot.log" 2>&1
QEMU_RC=$?
set -e
echo "QEMU_EXIT_CODE=$QEMU_RC" > "$LOG/host-smoke-status.txt"
tail -n 100 "$LOG/qemu-arm32-boot.log"
grep -Fq "ALPINE_ARM32_BOOT=PASS" "$LOG/qemu-arm32-boot.log"
grep -Fq "ALPINE_ARCH=armv7l" "$LOG/qemu-arm32-boot.log"
grep -Fq "ALPINE_ARM32_SMOKE_PASS" "$LOG/qemu-arm32-boot.log"
if [ "$QEMU_RC" -ne 0 ]; then
  echo "QEMU did not power off cleanly: exit=$QEMU_RC" >&2
  exit 44
fi
echo "HOST_ARM32_GUEST_SMOKE=PASS" >> "$LOG/host-smoke-status.txt"
STATUS=PASS
STAGE=complete
echo "ALPINE_ARM32_QEMU_VIRT_SMOKE=PASS; IPHONE_DEVICE_TEST=NOT_RUN"
