#!/usr/bin/env python3
"""Narrowly patch pinned UTM Linux wizard to use EKA2L1-style UIKit copy picker.

Reference mechanism: EKA2L1 iOS RootViewController.mm via the device-tested
Eka2l1_bot_menu_simbiam workflow's cached upstream: UIKit document-picker
delegate -> security scoped URL -> Documents/imports copy.

This patch is experimental, intended to determine whether UIKit delegate
callbacks work when SwiftUI .fileImporter fails on ESign-signed builds.

Keep macOS/visionOS behavior unmodified; keep original UTM bundle identity,
all QEMU libraries, and iOS 15 minimum. Do not treat build PASS as device PASS.
"""
from pathlib import Path
import subprocess
import sys

PIN = "7eadb056ae0f91d979059544d0ddcd2d5a40be92"
if len(sys.argv) != 2:
    raise SystemExit("usage: patch_utm_uikit_copy_picker.py <upstream/UTM>")
root = Path(sys.argv[1]).resolve()
actual = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
if actual != PIN:
    raise SystemExit(f"Refusing unexpected UTM upstream SHA: {actual}")

source_file = root / "Platform/Shared/VMWizardOSLinuxView.swift"
source = source_file.read_text(encoding="utf-8")

def replace_exact(old: str, new: str, label: str) -> None:
    global source
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 source anchor, found {count}")
    source = source.replace(old, new, 1)

replace_exact(
    "import SwiftUI\n",
    """import SwiftUI
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif
""",
    "iOS imports",
)
replace_exact(
    "    @State private var selectImage: SelectImage = .kernel\n",
    """    @State private var selectImage: SelectImage = .kernel
    #if os(iOS)
    @State private var pickerStatus = ""
    #endif
""",
    "picker diagnostics state",
)
replace_exact(
    """            if wizardState.isBusy {
                Spinner(size: .large)
            }
""",
    """            #if os(iOS)
            if !pickerStatus.isEmpty {
                Section {
                    Text(pickerStatus)
                        .font(.footnote)
                } header: {
                    Text("Nhật ký chọn ISO (UIKit)")
                }
            }
            #endif
            if wizardState.isBusy {
                Spinner(size: .large)
            }
""",
    "picker diagnostic status section",
)
replace_exact(
    """        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)
""",
    """        #if os(iOS)
        // EKA2L1-style UIKit delegate, not SwiftUI .fileImporter.
        .sheet(isPresented: $isFileImporterPresented) {
            NokiaUTMUIKitDocumentPicker(
                onPicked: { url in
                    pickerStatus = "Đã nhận từ Files: " + url.lastPathComponent
                    NSLog("[NokiaUTM][ISO] didPickDocumentsAtURLs received file")
                    isFileImporterPresented = false
                    processImage(.success(url))
                },
                onCancelled: {
                    pickerStatus = "Người dùng đã hủy chọn tệp."
                    NSLog("[NokiaUTM][ISO] documentPickerWasCancelled")
                    isFileImporterPresented = false
                }
            )
        }
        #else
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.data], onCompletion: processImage)
        #endif
""",
    "UIKit sheet instead of iOS fileImporter",
)
replace_exact(
    """    private func processImage(_ result: Result<URL, Error>) {
        wizardState.busyWorkAsync {
            let url = try result.get()
            await MainActor.run {
                switch selectImage {
                case .kernel:
                    wizardState.linuxKernelURL = url
                case .initialRamdisk:
                    wizardState.linuxInitialRamdiskURL = url
                case .rootImage:
                    wizardState.linuxRootImageURL = url
                case .bootImage:
                    wizardState.bootImageURL = url
                }
            }
        }
    }
}
""",
    """    private func processImage(_ result: Result<URL, Error>) {
        wizardState.busyWorkAsync {
            let url = try result.get()
            #if os(iOS)
            let usableURL = try NokiaUTMLocalISOImport.copyIntoDocuments(url)
            NSLog("[NokiaUTM][ISO] Imported into local Documents successfully")
            #else
            let usableURL = url
            #endif
            await MainActor.run {
                switch selectImage {
                case .kernel:
                    wizardState.linuxKernelURL = usableURL
                case .initialRamdisk:
                    wizardState.linuxInitialRamdiskURL = usableURL
                case .rootImage:
                    wizardState.linuxRootImageURL = usableURL
                case .bootImage:
                    wizardState.bootImageURL = usableURL
                }
                #if os(iOS)
                pickerStatus = "Đã nhập vào ứng dụng: " + usableURL.lastPathComponent
                #endif
            }
        }
    }
}
""",
    "copy selected image to app Documents",
)
source += """
#if os(iOS)
// UIKit picker callback runs independently of SwiftUI .fileImporter.
// This is based on EKA2L1's existing, user-tested Objective-C delegate pattern.
private struct NokiaUTMUIKitDocumentPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onCancelled: onCancelled)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        let onCancelled: () -> Void

        init(onPicked: @escaping (URL) -> Void, onCancelled: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onCancelled = onCancelled
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            if let first = urls.first {
                onPicked(first)
            } else {
                NSLog("[NokiaUTM][ISO] UIKit delegate returned an empty URL list")
                onCancelled()
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancelled()
        }
    }
}

private enum NokiaUTMLocalISOImport {
    static func copyIntoDocuments(_ pickedURL: URL) throws -> URL {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "NokiaUTMISO", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Không tìm thấy thư mục Documents."
            ])
        }
        // Give each import a private directory. Never overwrite a running VM's ISO.
        let destFolder = docs.appendingPathComponent("NokiaUTMISOImports", isDirectory: true)
                             .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let dest = destFolder.appendingPathComponent(pickedURL.lastPathComponent)
        let scoped = pickedURL.startAccessingSecurityScopedResource()
        defer { if scoped { pickedURL.stopAccessingSecurityScopedResource() } }
        NSLog("[NokiaUTM][ISO] Security-scoped access acquired: %@", scoped ? "YES" : "NO")
        try fm.copyItem(at: pickedURL, to: dest)
        guard fm.isReadableFile(atPath: dest.path) else {
            throw NSError(domain: "NokiaUTMISO", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Đã sao chép nhưng không thể đọc ISO."
            ])
        }
        return dest
    }
}
#endif
"""

assert "asCopy: true" in source
assert "startAccessingSecurityScopedResource()" in source
assert "Nhật ký chọn ISO (UIKit)" in source
assert "pickerStatus" in source
source_file.write_text(source, encoding="utf-8")
print("EKA2L1_STYLE_UIKIT_PICKER_PATCH=PASS", source_file, flush=True)
