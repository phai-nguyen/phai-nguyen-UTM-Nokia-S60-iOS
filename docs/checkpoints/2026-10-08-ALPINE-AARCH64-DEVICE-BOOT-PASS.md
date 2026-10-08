# Device checkpoint — Alpine Linux ARM64 boots in UTM Lite v8 (2026-10-08)

## Evidence
The iPhone device tester provided a screenshot of the terminal after configuring a Linux VM with display output disabled and using a serial console.

The screenshot clearly shows:

```
Booting `Linux virt'
OpenRC 0.63.2 is starting up Linux 6.18.52-0-virt (aarch64)
Welcome to Alpine Linux 3.24
Kernel 6.18.52-0-virt on aarch64 (/dev/ttyAMA0)
localhost login:
```

**DEVICE PASS:** UIKit file picker/import of Alpine aarch64 ISO; save VM without the earlier external-CD bookmark error; launch QEMU ARM64/UEFI; boot Alpine Linux into live serial login prompt. User clarified earlier they manually left the app when graphical display read `Display output is not active` (not an app crash). New VM with console output disabled exposed the functioning serial ttyAMA0 console.

**Still untested:** logging in as root, `uname -m`, `lsblk`/disk visibility, network connectivity, writing/installation to a virtual disk, orderly shutdown, persistence across app restarts. Do not conflate the successful live ISO boot with installation onto a virtual disk. No Nokia firmware has booted.

## Immediate tester steps (safe, no disk changes)

At `localhost login:`, use the UTM keyboard button, log in as `root` (Alpine install live ISO normally does not set a root password), then run:

```sh
uname -m
cat /etc/alpine-release
lsblk
```

Expect `aarch64`, Alpine `3.24.x`, and a list of available block devices. Save a screenshot. Do not run `setup-alpine`, repartition drives, or install packages until base device inspection is complete.

## Preserve working UTM baseline

- Repository: `phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS`.
- User-tested build: **NokiaUTM-SE-Lite-v8-TiengViet** based on v7 internal raw/read-only CD plus v6 EKA2L1-style UIKit file picker.
- [GitHub Actions Lite v8 build PASS #37788063413](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37788063413).
- [Localized v8 unsigned IPA artifact](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37788063413/artifacts/11554159956).
- Branch `feat/vi-localization-lite-v8` and [PR #10](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/pull/10) remain separate until user confirms the remaining UI language labels.
- Several UI labels remain untranslated; preserve working boot/file importer while extending localization.
- Minimum iOS 15+, no JIT, original bundle ID `com.phai.nokias60.UTM-SE`.

## Planned Nokia N95 / OMAP2420 phase (not implemented)

**The fact that QEMU aarch64 boots Alpine is not proof of Nokia N95 support.**

Nokia N95 is an **ARM32 ARM1136 / OMAP2420-family** target, different from this ARM64 virtual machine. Before attempting Nokia firmware boot:

1. Identify a reproducible historical QEMU source revision with `hw/arm/omap2.c` and `hw/arm/nseries.c` (Nokia N800/N810 are hardware references; they do *not* represent the N95 board exactly). Review compatibility with the pinned UTM/QEMU sysroot version and licensing.
2. Add a **qemu-system-arm / qemu-arm-softmmu iOS TCI engine**, with all dyld dependencies correctly packaged and signed (do not remove known-good QEMU frameworks).
3. Create a separate feature branch for Nokia board/memory map/interrupt-controller/boot-ROM loading and UART/serial diagnostics. N95-specific peripherals and SoC initialization require further reverse engineering; avoid claiming Nokia firmware should boot from generic `virt-10.0`.
4. Do not bundle copyrighted Nokia firmware; use user-provided firmware locally for compatibility testing.
5. Keep v8 bootable Alpine ARM64 untouched as the regression baseline.

Scope: emulator compatibility and legitimate Nokia/Symbian firmware research, not exploitation or unrelated security activity.


## Device follow-up: login and commands PASS (2026-10-08 21:48 ICT)

The user supplied a second screenshot of the UTM Lite v8 serial terminal confirming successful root shell login (the first attempt with password was rejected, then `root` logged in at the second prompt). Shell and on-screen keyboard work.

Verified outputs:

```text
localhost:~# uname -m
aarch64
localhost:~# cat /etc/alpine-release
3.24.2
localhost:~# lsblk
-sh: lsblk: not found
localhost:~#
```

**Device PASS additionally:** guest interactive console input, user login, execution of Linux shell commands, confirmed `aarch64`, Alpine 3.24.2.

**NOT a disk failure:** `lsblk` is absent from the minimal live environment; no block-device status can be concluded. Next user test: `cat /proc/partitions`, which reads kernel's block-device inventory without installing packages or modifying partitions. Need verify a `vda` or `sda` entry corresponding to the configured 4 GiB virtual disk (actual name may vary).

Avoid installing Alpine or modifying disk partitions before checking the live system's available devices.

## Block device discovery — DEVICE PASS (2026-10-08)

The user supplied a third iPhone screenshot from Alpine's serial console:

```text
localhost:~# cat /proc/partitions
major minor  #blocks  name
   7     0    17328  loop0
 253     0  4194304  vda
  11     0    91118  sr0
localhost:~#
```

**Confirmed:** the 4 GiB VirtIO guest block device `/dev/vda` is visible (4,194,304 KiB blocks), and a ~89 MiB CD-ROM ISO device `/dev/sr0` is visible. `loop0` is expected kernel loop support. The earlier missing `lsblk` utility was only a missing user-space command, not a missing disk.

**Not yet tested:** partition creation, disk writes, persistence, network/DHCP/internet, normal shutdown and restarting the same VM. Do not claim full VM storage/internet PASS yet.

**Suggested next read-only device test:** `ip addr show`, `ip route`, `ping -c 3 1.1.1.1` (if a network is enabled); capture screenshot. `poweroff` when finished.


## Network discovery — guest NIC present, network not configured (2026-10-08)

The user supplied a screenshot of UTM Lite v8's live Alpine Linux terminal showing:

```text
localhost:~# ip addr show
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN ...
2: eth0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN ...
    link/ether 62:1f:4a:e5:4b:e1 ...
localhost:~# ip route
localhost:~# ping -c 3 1.1.1.1
PING 1.1.1.1 (1.1.1.1): 56 data bytes
ping: sendto: Network unreachable
```

**DEVICE PASS (partial):** Alpine AArch64 kernel enumerates `eth0`, indicating a virtual NIC is detected. **NOT PASS:** network connectivity; interface is DOWN, with no IPv4 address or default route. This is compatible with an unconfigured Alpine live environment and not yet evidence of a broken QEMU network adapter.

Next user test (not yet performed):

```sh
ip link set eth0 up
udhcpc -i eth0 -n -q
ip addr show eth0
ip route
ping -c 3 1.1.1.1
```

If DHCP cannot obtain a lease, inspect UTM VM's network toggle and NAT/shared-network mode, network-device attachment, and guest interface link status. Do not yet declare Internet/networking PASS. This checkpoint does not change build or firmware baseline.
