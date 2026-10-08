#!/usr/bin/env python3
"""Small fixture-only tests: no signing, no user provisioning data."""
import importlib.util
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("repack_esign_identity",ROOT/"scripts"/"repack_esign_identity.py")
tool=importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)

class RepackIdentityTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.src=self.root/"source.ipa"
        self.dest=self.root/"new.ipa"
        self.report=self.root/"manifest.json"
        props={
            "CFBundleIdentifier":tool.BASE,
            "MinimumOSVersion":"15.0",
            "UIFileSharingEnabled":True,
            "LSSupportsOpeningDocumentsInPlace":True,
            "AppGroupIdentifier":"group.com.phai.nokias60.UTM",
        }
        with zipfile.ZipFile(self.src,"w",zipfile.ZIP_DEFLATED) as f:
            f.writestr(tool.INFO,plistlib.dumps(props))
            f.writestr("Payload/UTM SE.app/UTM SE",b"dummy-executable")
            for cpu in ("aarch64","i386","x86_64","ppc","ppc64","riscv64","m68k"):
                f.writestr(f"Payload/UTM SE.app/Frameworks/qemu-{cpu}-softmmu.framework/qemu-{cpu}-softmmu",b"x")
    def test_match_bundle_only_and_keep_all_binaries(self):
        tool.run(self.src,self.dest,self.report,"com.example.nokiautm")
        with zipfile.ZipFile(self.src) as source,zipfile.ZipFile(self.dest) as dest:
            self.assertEqual(source.namelist(),dest.namelist())
            self.assertEqual(plistlib.loads(dest.read(tool.INFO))["CFBundleIdentifier"],"com.example.nokiautm")
            for name in source.namelist():
                if name!=tool.INFO:
                    self.assertEqual(source.read(name),dest.read(name))
    def test_never_replace_existing_eka2l1(self):
        for name in ("app.lavender1865.valley8348","com.eka2l1.emulator",tool.BASE):
            with self.subTest(name=name),self.assertRaises(ValueError):
                tool.run(self.src,self.dest,self.report,name)
    def test_reject_invalid_identifiers(self):
        for name in ("","abc","abc.def","app!.name.bad","a/b/c"):
            with self.subTest(name=name),self.assertRaises(ValueError):
                tool.run(self.src,self.dest,self.report,name)

if __name__=="__main__":
    unittest.main()
