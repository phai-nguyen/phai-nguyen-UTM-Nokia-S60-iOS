#!/usr/bin/env python3
"""Give iOS a second ISO-selection path that does not use UIDocumentPicker.

iOS Files can expose this app's Documents directory through UIFileSharingEnabled,
which the pinned UTM Info.plist already sets true. User copies the ISO into
On My iPhone / UTM SE and taps a visible local filename in the Linux wizard.

This avoids the .fileImporter/UIDocumentPicker callback altogether. It does
not modify code signing, entitlements, QEMU, firmware or other VM architectures.
"""
from pathlib import Path
import subprocess
import sys

PIN = "7eadb056ae0f91d979059544d0ddcd2d5a40be92"
if len(sys.argv) != 2:
    raise SystemExit("usage: patch_utm_local_iso_picker.py <upstream-utm-path>")
root = Path(sys.argv[1]).resolve()
actual = subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],text=True).strip()
if actual != PIN:
    raise SystemExit(f"UTM commit mismatch (expected pinned {PIN}, got {actual})")

p = root / "Platform/Shared/VMWizardOSLinuxView.swift"
source = p.read_text(encoding="utf-8")
changes = [
    (
        "    @State private var selectImage: SelectImage = .kernel\n",
        """    @State private var selectImage: SelectImage = .kernel
    // Diagnostic v4: select ISO already copied into the app's Documents directory.
    @State private var locallyAvailableISOFiles: [URL] = []
""",
    ),
    (
        """            if wizardState.isBusy {
                Spinner(size: .large)
            }
""",
        """            #if os(iOS)
            if wizardState.bootDevice == .cd || wizardState.bootDevice == .drive {
                Section {
                    if locallyAvailableISOFiles.isEmpty {
                        Text("Chưa thấy tệp ISO/IMG trong thư mục UTM SE.")
                            .foregroundColor(.secondary)
                        Text("Trong ứng dụng Tệp: Trên iPhone của tôi → UTM SE. Chép tệp .iso vào thư mục đó, quay lại đây và nhấn Làm mới.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(locallyAvailableISOFiles, id: \\.path) { iso in
                            Button {
                                wizardState.bootImageURL = iso
                                selectImage = .bootImage
                            } label: {
                                HStack {
                                    Text(iso.lastPathComponent)
                                        .lineLimit(2)
                                    Spacer()
                                    if wizardState.bootImageURL == iso {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                            }
                        }
                    }
                    Button("Làm mới danh sách ISO trong ứng dụng") {
                        refreshLocalISOFiles()
                    }
                } header: {
                    Text("Chọn ISO từ bộ nhớ ứng dụng (không dùng Browse)")
                }
                .onAppear(perform: refreshLocalISOFiles)
            }
            #endif

            if wizardState.isBusy {
                Spinner(size: .large)
            }
""",
    ),
    (
        """    private func processImage(_ result: Result<URL, Error>) {
""",
        """    #if os(iOS)
    /// Read-only listing of directly accessible files; no security scope needed.
    /// This is intentionally separate from the system UIDocumentPicker.
    private func refreshLocalISOFiles() {
        let manager = FileManager.default
        guard let docs = manager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            locallyAvailableISOFiles = []
            return
        }
        do {
            // Ensure Files > On My iPhone shows this app's document container, even
            // before the first VM has been created. Never overwrite user documents.
            try manager.createDirectory(at: docs, withIntermediateDirectories: true)
            let readme = docs.appendingPathComponent("COPY-ISO-HERE.txt")
            if !manager.fileExists(atPath: readme.path) {
                try? "Chép file ISO vào cùng thư mục này; trở lại UTM, nhấn Làm mới.\\n".write(
                    to: readme, atomically: true, encoding: .utf8
                )
            }
            let contents = try manager.contentsOfDirectory(
                at: docs, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
            )
            locallyAvailableISOFiles = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                let isDiskImage = ["iso", "img", "qcow2", "vhd", "vhdx", "vmdk"].contains(ext)
                let isReadable = manager.isReadableFile(atPath: url.path)
                let regular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                return isDiskImage && regular && isReadable
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            print("[NokiaUTM][LocalISO] files=\\(locallyAvailableISOFiles.count)")
        } catch {
            print("[NokiaUTM][LocalISO] scan failed: \\(error.localizedDescription)")
            locallyAvailableISOFiles = []
        }
    }
    #endif

    private func processImage(_ result: Result<URL, Error>) {
""",
    ),
]
for old, new in changes:
    count=source.count(old)
    if count != 1:
        raise SystemExit(f"Need exactly one patch site ({old[:75]!r}): found {count}")
    source=source.replace(old,new,1)

p.write_text(source,encoding="utf-8")
# Ensure existing SwiftUI picker remains unchanged to isolate this experiment.
assert 'allowedContentTypes: [.data]' in source
assert "Làm mới danh sách ISO trong ứng dụng" in source
print("LOCAL_ISO_FALLBACK_PATCH=PASS",p)
