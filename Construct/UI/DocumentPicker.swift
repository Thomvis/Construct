//
//  DocumentPicker.swift
//  Construct
//
//  Created by Thomas Visser on 21/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
final class DocumentPicker: NSObject, UIViewControllerRepresentable, UIDocumentPickerDelegate {

    typealias UIViewControllerType = UIDocumentPickerViewController

    let didPick: ([URL]) -> Void
    var dp: DocumentPicker? // fixme/bug: if we don't keep a strong reference here, this object is dealloc'ed before it can call didPick

    init(didPick: @escaping ([URL]) -> Void) {
        self.didPick = didPick
        super.init()
        self.dp = self
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.content], asCopy: true)
        vc.delegate = self
        return vc
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<DocumentPicker>) {

    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.dp = nil
        self.didPick(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.dp = nil
    }

}
#endif
