#!/bin/bash
# Strip local/debug symbols from QEMU frameworks while retaining ALL linked dylibs.
# Safe intent: change symbol-table size only, never delete linked frameworks.
# All artifacts remain unsigned and must be signed with ESign after packaging.
set -Eeuo pipefail
export LC_ALL=C
INPUT="${1:?original IPA}"
OUTPUT="${2:?destination IPA}"
REPORT="${3:?report directory}"
mkdir -p "$REPORT" "$(dirname "$OUTPUT")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unzip -q "$INPUT" -d "$WORK"
APP="$WORK/Payload/UTM SE.app"
BIN="$APP/UTM SE"
FRAMEWORKS="$APP/Frameworks"
test -f "$BIN"
test -d "$FRAMEWORKS"

# The original full IPA is our GOOD device-tested baseline.
# Every linked qemu framework must exist at launch (dyld strong link).
otool -L "$BIN" | tee "$REPORT/otool-main-before.txt"
python3 - "$BIN" "$FRAMEWORKS" <<'PY' | tee "$REPORT/linked-framework-verification.txt"
import pathlib, subprocess, sys
binary, directory = sys.argv[1:]
libs = subprocess.check_output(["otool", "-L", binary], text=True).splitlines()[1:]
refs = []
for line in libs:
    dep = line.strip().split(" (compatibility",1)[0].strip()
    if dep.startswith("@rpath/qemu-"):
        ref = pathlib.Path(directory) / dep.removeprefix("@rpath/")
        refs.append((dep, ref.exists()))
if not refs:
    raise SystemExit("FAIL: no strong qemu dependencies found; source format changed")
for name,exists in refs:
    print(("PASS " if exists else "MISSING ") + name)
if not all(ok for _,ok in refs):
    raise SystemExit("FAIL: missing strong-linked QEMU dylib. Refuse to package.")
print("DYLD_PRECHECK=PASS")
PY

# Strip ONLY local and debug symbols. Do not remove any strong-linked framework.
# Dynamic exports necessary for dyld/dlsym must survive.
python3 - "$FRAMEWORKS" "$REPORT" <<'PY'
from pathlib import Path
import subprocess
import sys
fw, report = Path(sys.argv[1]), Path(sys.argv[2])
names = ("aarch64", "i386", "x86_64", "ppc", "ppc64", "riscv64", "m68k")
results = []
for cpu in names:
    file = fw / f"qemu-{cpu}-softmmu.framework" / f"qemu-{cpu}-softmmu"
    if not file.is_file():
        raise SystemExit(f"Required QEMU framework missing: {file}")
    before = file.stat().st_size
    # Some original IPA frameworks are ad-hoc signed; signatures become invalid
    # after strip, so remove them for the user's re-signing step.
    has_sig = subprocess.run(["codesign", "-d", str(file)], stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL).returncode == 0
    if has_sig:
        subprocess.run(["codesign", "--remove-signature", str(file)], check=True)
    subprocess.run(["xcrun", "strip", "-S", "-x", str(file)], check=True)
    after = file.stat().st_size
    subprocess.run(["otool", "-L", str(file)], check=True, stdout=subprocess.DEVNULL)
    results.append((cpu,before,after))
    print(f"{cpu}: {before:,} -> {after:,} ({100*(before-after)/before:.1f}% stripped)",flush=True)
assert len(results) == 7
print("STRIP=PASS")
(report / "strip-report.tsv").write_text("cpu\tbefore\tafter\n" + "".join(f"{n}\t{b}\t{a}\n" for n,b,a in results))
PY

# Recheck dependency graph and compare to pre-strip strong-linked names.
otool -L "$BIN" > "$REPORT/otool-main-after.txt"
diff -u "$REPORT/otool-main-before.txt" "$REPORT/otool-main-after.txt"
python3 - "$FRAMEWORKS" <<'PY'
from pathlib import Path
import subprocess
import sys
fw = Path(sys.argv[1])
for item in fw.glob("qemu-*-softmmu.framework/qemu-*-softmmu"):
    deps = subprocess.check_output(["otool","-L",str(item)],text=True).splitlines()[1:]
    for line in deps:
        dep=line.strip().split(" (compatibility",1)[0].strip()
        if dep.startswith("@rpath/qemu-"):
            path=fw / dep.removeprefix("@rpath/")
            if not path.exists():
                raise SystemExit(f"DYLD POSTCHECK FAIL: {item.name} requires {dep}")
print("DYLD_POSTCHECK=PASS")
PY

# App is unsigned; all nested altered binaries must be signed again by ESign.
# Recursively include all original framework and QEMU data files in the IPA.
rm -f "$OUTPUT"
(
  cd "$WORK"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "Payload" "$OUTPUT"
)
unzip -t "$OUTPUT" > "$REPORT/zip-integrity.txt"
python3 - "$INPUT" "$OUTPUT" "$REPORT" <<'PY'
import json, hashlib, pathlib, sys, zipfile
src, dst, report = (pathlib.Path(x) for x in sys.argv[1:])
with zipfile.ZipFile(src) as z1, zipfile.ZipFile(dst) as z2:
    names1={x.filename for x in z1.infolist() if not x.is_dir()}
    names2={x.filename for x in z2.infolist() if not x.is_dir()}
    if names1 != names2:
        raise SystemExit(f"Refuse artifact: lost files={names1-names2}, unexpected={names2-names1}")
    for name in names1:
        if name.endswith("/Info.plist") or name=="Payload/UTM SE.app/Info.plist":
            if z1.read(name) != z2.read(name):
                raise SystemExit(f"Unexpected Info.plist mutation: {name}")
def digest(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(2**20),b""): h.update(b)
    return h.hexdigest()
result={
"source_bytes":src.stat().st_size,"lite_bytes":dst.stat().st_size,
"source_sha256":digest(src),"lite_sha256":digest(dst),
"reduction_percent":round(100*(1-dst.stat().st_size/src.stat().st_size),2),
"all_source_files_preserved":True,"all_seven_qemu_engines_preserved":True,
"dyld_dependency_check":"PASS","zip_integrity":"PASS",
"iphone_device_test":"PENDING","nokia_machine":"NOT IMPLEMENTED"}
(report/"size-result.json").write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
PY
