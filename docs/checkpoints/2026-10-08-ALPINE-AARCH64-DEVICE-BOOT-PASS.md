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


## Network DHCP lease PASS — iPhone device screenshot (2026-10-08)

The user executed the following commands inside Alpine 3.24.2 on UTM SE Lite v8:

```text
localhost:~# ip link set eth0 up
localhost:~# udhcpc -i eth0 -n -q
udhcpc: started, v1.37.0
udhcpc: broadcasting discover
udhcpc: broadcasting select for 10.0.2.15, server 10.0.2.2
udhcpc: lease of 10.0.2.15 obtained from 10.0.2.2, lease time 86400
```

**DEVICE PASS:** virtual Ethernet interface `eth0` can be activated, the guest's DHCP client communicates with QEMU NAT/SLIRP-style DHCP and receives IPv4 `10.0.2.15` with server `10.0.2.2`; 86,400-second lease.

**NOT YET VERIFIED:** default route, DNS, outbound Internet or HTTPS connectivity. Request a further `ip route` and `wget -O /dev/null http://example.com` test. ICMP ping alone can be misleading with userspace NAT.

Do not modify verified UTM Lite v8 source/IPA for network fix; no network defect has been established.


## NAT default route PASS; HTTP test not yet valid (2026-10-08)

User-provided screenshot following a successful DHCP lease shows:

```text
localhost:~# ip route
default via 10.0.2.2 dev eth0 metric 202
10.0.2.0/24 dev eth0 scope link src 10.0.2.15
```

**DEVICE PASS:** QEMU guest receives an IPv4 address from DHCP and installs a default NAT route via `10.0.2.2`.

The subsequent attempted HTTP test failed as a **command syntax typo**, not a connectivity test: `wget -0 /dev/null http://example.com` uses numeric digit zero instead of uppercase letter `O`; BusyBox reported `wget: unrecognized option: 0` and printed usage. **Do not label Internet connectivity PASS or FAIL based on this attempt.**

Next requested read-only test:

```sh
wget --spider http://example.com
```

BusyBox help shown in the screenshot supports `--spider`, which checks a URL without saving a file. If this succeeds, it supports HTTP and DNS access; if it fails, review the exact error. Optional later: test graceful `poweroff` and restart the VM to verify normal lifecycle. All already-passed boot, disk enumeration, UIKit picker, and Vietnamese UI should remain unchanged.


## DNS + outbound HTTP Internet connectivity PASS — iPhone device screenshot (2026-10-08)

After DHCP and default route (10.0.2.15 / gateway 10.0.2.2), user executed:

```text
localhost:~# wget --spider http://example.com
Connecting to example.com (104.20.23.154:80)
remote file exists
localhost:~#
```

**DEVICE PASS:** DNS resolved `example.com` to an IPv4 address and BusyBox wget successfully contacted an HTTP service on TCP port 80 using the UTM QEMU user-mode NAT network. This verifies outbound DNS and HTTP in the Alpine aarch64 guest. Do not infer HTTPS/TLS, inbound port forwarding, other sites, or persistence from this one test.

Suggested remaining minimal lifecycle test: `poweroff`, then relaunch the *same* virtual machine to ensure clean shutdown/reboot to live Alpine serial login. Full disk write/persistence is a separate test; do not install Alpine until user requests it.

**Milestone:** UTM SE Lite v8 has user-device PASS for ESign-installed launch, UIKit ISO picker and sandbox import, VM creation with bundled raw CD, serial guest boot/login, aarch64 identification, virtual storage device discovery, DHCP/NAT, DNS and outbound HTTP. Nokia N95 OMAP2420/ARM32 remains entirely separate and not implemented.


## Shutdown + reboot lifecycle — DEVICE PASS (2026-10-09)

The user explicitly confirmed the UTM Lite v8 Alpine Linux aarch64 VM **shut down normally and started again normally** on their iPhone. This completes the basic interactive live-ISO VM lifecycle regression suite on device.

**Verified on device:** ESign-signed app launch; Vietnamese UI (partially localized); iOS/UIKit ISO selection and sandbox copy; VM save with ISO bundled internally; UEFI and serial-console boot to Alpine Linux 3.24.2; root login and shell execution; `uname -m` reports `aarch64`; 4 GiB VirtIO `vda` and ISO `sr0` enumerated; guest NIC `eth0`, DHCP lease `10.0.2.15`, default route via `10.0.2.2`, DNS and outbound HTTP; graceful poweroff and successful relaunch.

**Still outside tested scope:** disk writes/persistence through reboots, installed-OS boot from disk, package download/HTTPS, performance/battery testing, unrelated architectures, and Nokia OMAP2420/ARM32 firmware boot.

**Freeze baseline:** the exact unsigned IPA artifact from [GitHub Actions run #37788063413](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37788063413/artifacts/11554159956) (SHA256 `671535ffec7f866688537ee86db8c5eb53aeccbd78f3fc517dcb9dcf871e6caa`) is the v8 tested baseline. Changes after this artifact on `feat/vi-localization-lite-v8` are documentation/checkpoints, not a changed tested app. Do not casually merge OMAP/ARM32 into this working v8 baseline.

**Next:** create a separate research/design branch to assess historical QEMU OMAP2420 sources and the ARM32 system-emulation engine, while retaining all working v8 artifact links and tests. Do not claim N95 compatibility until a board model and target firmware boot are actually verified.
