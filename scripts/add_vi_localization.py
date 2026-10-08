#!/usr/bin/env python3
"""Add Vietnamese .lproj localization to an *unsigned* proven-good Lite v7 IPA.

UTM already localizes through *.lproj/Localizable.strings. This post-archive
resource overlay leaves UTM/QEMU binaries, VM configuration, ISO import, UIKit
picker, provisioning and code signing untouched. Tested structure only; an
actual iPhone device-language screenshot remains required for UI PASS.

Inputs: lite-v7.ipa, unsigned-v8.ipa, repo/localization, upstream/UTM, report.
"""
import copy
import hashlib
import json
import plistlib
import re
import sys
import zipfile
from pathlib import Path

APP = "Payload/UTM SE.app/"
INFO = APP + "Info.plist"
MAIN = APP + "UTM SE"
QEMU = ("aarch64", "i386", "x86_64", "ppc", "ppc64", "riscv64", "m68k")
KEY_RE = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=', re.M)

SETTINGS_VI = {
    "Group": "Nhóm",
    "Name": "Tên",
    "none given": "chưa có",
    "Enabled": "Đã bật",
    "Disabled": "Đã tắt",
    "Background": "Chạy nền",
    "Continue running VM in the background": "Tiếp tục chạy máy ảo trong nền",
    "Auto save on background": "Tự động lưu khi chuyển sang nền",
    "Auto save on low memory": "Tự động lưu khi thiếu bộ nhớ",
    "Gestures": "Cử chỉ",
    "Long Press": "Nhấn giữ",
    "Click & Hold": "Nhấp và giữ",
    "Right Click": "Nhấp chuột phải",
    "Two Finger Tap": "Chạm hai ngón",
    "Two Finger Pan": "Kéo hai ngón",
    "Move Screen": "Di chuyển màn hình",
    "Two Finger Scroll": "Cuộn hai ngón",
    "Mouse Wheel": "Con lăn chuột",
    "Three Finger Pan": "Kéo ba ngón",
    "Cursor": "Con trỏ",
    "Touch Input": "Điều khiển cảm ứng",
    "Drag cursor": "Kéo con trỏ",
    "Touch mode (always show cursor)": "Chế độ cảm ứng (luôn hiện con trỏ)",
    "Touch mode (try hiding cursor)": "Chế độ cảm ứng (ưu tiên ẩn con trỏ)",
    "Apple Pencil Input": "Điều khiển bằng Apple Pencil",
    "Tablet mode (always show cursor)": "Chế độ máy tính bảng (luôn hiện con trỏ)",
    "Tablet mode (try hiding cursor)": "Chế độ máy tính bảng (ưu tiên ẩn con trỏ)",
    "Touchpad/Mouse Input": "Điều khiển bằng bàn di chuột/chuột",
    "Follow cursor": "Theo con trỏ",
    "Two Finger Swipe": "Vuốt hai ngón",
    "Mouse Wheel (per swipe)": "Con lăn chuột (mỗi lần vuốt)",
    "Menu": "Menu",
    "Options": "Tùy chọn",
    "Home": "Trang chủ",
}

def sha(path):
    hash = hashlib.sha256()
    with Path(path).open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            hash.update(b)
    return hash.hexdigest()

def apple_strings(entries):
    lines = ["/* UTM SE Vietnamese iOS localization - source keys retained. */", ""]
    for key, translated in sorted(entries.items(), key=lambda x: x[0].lower()):
        if not key or not translated:
            raise ValueError("Empty localization pair")
        if "\x00" in key + translated:
            raise ValueError("Invalid NUL in localization")
        # JSON escaped strings are valid old-style *.strings quoted values.
        lines.append(f"{json.dumps(key, ensure_ascii=False)} = {json.dumps(translated, ensure_ascii=False)};")
    return ("\n".join(lines) + "\n").encode("utf-8")

def main(srcfile, outfile, locdir, upstreamdir, reportfile):
    srcfile, outfile, locdir, upstreamdir, reportfile = map(Path, (srcfile, outfile, locdir, upstreamdir, reportfile))
    if srcfile.resolve() == outfile.resolve():
        raise ValueError("Refusing to replace the input IPA")
    translations = json.loads((locdir / "vi-base.json").read_text(encoding="utf-8"))
    extra = json.loads((locdir / "vi-essential-extra.json").read_text(encoding="utf-8"))
    # First human-reviewed core map takes priority; add missing supplementary keys.
    for k, v in extra.items():
        translations.setdefault(k, v)
    catalogue = (upstreamdir / "Platform/zh-Hans.lproj/Localizable.strings").read_text(encoding="utf-8")
    source_keys = set(KEY_RE.findall(catalogue))
    recognized = source_keys.intersection(translations)
    if len(recognized) < 335:
        raise RuntimeError(f"Insufficient translated UTM key coverage: {len(recognized)}")
    if translations["Settings"] != "Cài đặt" or translations["Boot from ISO image"] != "Khởi động từ tệp ISO":
        raise RuntimeError("Missing essential Vietnamese terms")
    if translations["Failed to access drive image path."] != "Không thể truy cập đường dẫn tệp ảnh đĩa.":
        raise RuntimeError("Missing localized drive failure diagnostic")
    # Supplementary code-only labels remain available even if not in Chinese catalogue.
    local = apple_strings(translations)
    settings = apple_strings(SETTINGS_VI)
    infostring = apple_strings({"CFBundleDisplayName": "UTM SE"})
    # Keep original format value type and placeholder of %lld Cores.
    plural = {
        "%lld Cores": {
            "NSStringLocalizedFormatKey": "%#@cores@",
            "cores": {
                "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                "NSStringFormatValueTypeKey": "lld",
                "one": "%lld nhân",
                "other": "%lld nhân",
            },
        }
    }
    payloads = {
        APP + "vi.lproj/Localizable.strings": local,
        APP + "vi.lproj/Localizable.stringsdict": plistlib.dumps(plural, fmt=plistlib.FMT_XML),
        APP + "vi.lproj/InfoPlist.strings": infostring,
        APP + "Settings.bundle/vi.lproj/Root.strings": settings,
    }
    outfile.parent.mkdir(parents=True,exist_ok=True)
    reportfile.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(srcfile, "r") as src:
        if src.testzip() is not None:
            raise RuntimeError("Input Lite v7 ZIP checksum error")
        names = set(src.namelist())
        if INFO not in names or MAIN not in names:
            raise RuntimeError("Not a recognizable UTM SE IPA")
        info = plistlib.loads(src.read(INFO))
        if info.get("CFBundleIdentifier") != "com.phai.nokias60.UTM-SE":
            raise RuntimeError("Unexpected bundle identifier (do not overwrite EKA2L1)")
        if info.get("MinimumOSVersion") != "15.0":
            raise RuntimeError("Unexpected minimum iOS version")
        for filename in payloads:
            if filename in names:
                raise RuntimeError(f"Would overwrite existing localization file: {filename}")
        existing_langs = {name[len(APP):].split("/")[0][:-6]
                          for name in names if name.startswith(APP) and ".lproj/" in name and
                          name[len(APP):].split("/")[0].endswith(".lproj") and
                          "/" not in name[len(APP):].split("/")[0]}
        declared = info.get("CFBundleLocalizations", [])
        if not isinstance(declared, list):
            raise RuntimeError("Invalid CFBundleLocalizations")
        langs = sorted(set(declared) | existing_langs | {"vi","en"})
        info["CFBundleLocalizations"] = langs
        payloads[INFO] = plistlib.dumps(info, fmt=plistlib.FMT_BINARY, sort_keys=False)
        original_bytes = src.read(MAIN)
        with zipfile.ZipFile(outfile,"w",allowZip64=True) as dst:
            for member in src.infolist():
                # Avoid duplicate ZIP entries; retain all binaries and resources.
                item = copy.copy(member)
                if member.filename == INFO:
                    dst.writestr(item,payloads[INFO])
                elif member.is_dir():
                    dst.writestr(item,b"")
                else:
                    with src.open(member) as read, dst.open(item,"w",force_zip64=True) as write:
                        import shutil
                        shutil.copyfileobj(read,write,1024 * 1024)
            for name, data in payloads.items():
                if name == INFO:
                    continue
                dst.writestr(name, data, compress_type=zipfile.ZIP_DEFLATED)
    with zipfile.ZipFile(srcfile) as src, zipfile.ZipFile(outfile) as dst:
        if dst.testzip() is not None:
            raise RuntimeError("Localized IPA ZIP checksum mismatch")
        orig_set = set(src.namelist())
        new_set = set(dst.namelist())
        if new_set - orig_set != set(payloads) - {INFO} or orig_set - new_set:
            raise RuntimeError("Unexpected ZIP content change")
        if dst.read(MAIN) != original_bytes:
            raise RuntimeError("Main Mach-O mutated")
        for cpu in QEMU:
            p = APP + f"Frameworks/qemu-{cpu}-softmmu.framework/qemu-{cpu}-softmmu"
            if p not in orig_set or src.read(p) != dst.read(p):
                raise RuntimeError(f"Lost or modified QEMU {cpu} framework")
        found = plistlib.loads(dst.read(INFO))
        if (found.get("CFBundleIdentifier") != info["CFBundleIdentifier"] or
                found.get("MinimumOSVersion") != "15.0"):
            raise RuntimeError("Changed bundle identity or minimum OS")
        if "vi" not in found.get("CFBundleLocalizations",[]):
            raise RuntimeError("Vietnamese language not registered")
        if '"Settings" = "Cài đặt";'.encode("utf-8") not in dst.read(APP + "vi.lproj/Localizable.strings"):
            raise RuntimeError("Vietnamese translation not in output IPA")
        plistlib.loads(dst.read(APP + "vi.lproj/Localizable.stringsdict"))
    result = {
        "status": "PASS",
        "added_language": "vi",
        "translated_terms": len(translations),
        "source_catalogue_keys": len(source_keys),
        "verified_catalogue_matches": len(recognized),
        "coverage_percent": round(100*len(recognized)/len(source_keys), 1),
        "app_bundle": info["CFBundleIdentifier"],
        "minimum_ios": info["MinimumOSVersion"],
        "existing_languages_preserved": langs,
        "qemu_frameworks_unchanged": list(QEMU),
        "user_test": "PENDING",
        "source_sha256": sha(srcfile),
        "localized_sha256": sha(outfile),
        "localized_bytes": outfile.stat().st_size,
    }
    reportfile.write_text(json.dumps(result,indent=2,ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(result,indent=2,ensure_ascii=False))

if __name__ == "__main__":
    if len(sys.argv) != 6:
        raise SystemExit("usage: add_vi_localization.py original.ipa localized.ipa localization/ upstream/UTM report.json")
    try:
        main(*sys.argv[1:])
    except Exception as e:
        raise SystemExit("LOCALIZATION FAIL: " + str(e))
