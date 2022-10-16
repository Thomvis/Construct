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

struct DocumentPicker: UIViewControllerRepresentable {

    typealias UIViewControllerType = UIDocumentPickerViewController

    let didPick: ([URL]) -> Void

    func makeCoordinator() -> Delegate {
        return Delegate(didPick: didPick)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.content], asCopy: true)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<DocumentPicker>) {
        context.coordinator.didPick = didPick
    }

    final class Delegate: NSObject, UIDocumentPickerDelegate {
        var didPick: ([URL]) -> Void

        init(didPick: @escaping ([URL]) -> Void) {
            self.didPick = didPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            self.didPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {

        }
    }

}
