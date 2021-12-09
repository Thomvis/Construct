//
//  CompendiumImportView.swift
//  Construct
//
//  Created by Thomas Visser on 21/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

// Fixme: this view is not using the reducer architecture
struct CompendiumImportView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var env: Environment

    @State var selectedReader: Reader? = Self.readers.first
    @State var source: Source = .file

    @State var urlSource: String = ""

    @State var openDocumentPicker = false
    @State var pickedFileUrl: URL? = nil

    @State var importProgress: ImportProgress = .none

    var body: some View {
        Form {
            // Select importer
            Section(header: Text("Type")) {
                ForEach(Self.readers) { reader in
                    HStack(spacing: 12) {
                        Checkbox(selected: self.selectedReader?.id == reader.id)
                            .foregroundColor(Color(UIColor.systemFill))

                        VStack(alignment: .leading) {
                            Text(reader.name)
                            reader.description.map {
                                Text($0).font(.footnote).foregroundColor(Color(UIColor.secondaryLabel))
                            }
                        }
                    }
                    .onTapGesture {
                        self.selectedReader = reader
                    }
                }
            }

            // Configure source
            Section(header: Text("Source")) {
                Picker(selection: $source, label: Text("Source")) {
                    Text("Url").tag(Source.url)
                    Text("File").tag(Source.file)
                }.pickerStyle(SegmentedPickerStyle())

                if source == .url {
                    ClearableTextField("Url", text: $urlSource)
                } else if source == .file {
                    Button(action: {
                        self.openDocumentPicker = true
                    }) {
                        pickedFileUrl.map { url in
                            Text("Selected \"\(url.lastPathComponent)\"")
                        }.replaceNilWith {
                            Text("Select file...")
                        }
                    }
                }
            }
            .disabled(selectedReader == nil)

            Button(action: {
                self.env.dismissKeyboard()
                self.performImport()
            }) {
                HStack(spacing: 12) {
                    if importProgress.isImporting {
                        ProgressView()
                    }

                    Text(importProgress.isImporting ? "Importing..." : "Import into compendium")
                }
            }.disabled(!canImport || importProgress.isImporting)
        }
        .navigationBarTitle(CompendiumImportViewState().navigationTitle)
        .sheet(isPresented: $openDocumentPicker) {
            DocumentPicker { urls in
                self.pickedFileUrl = urls.first
            }
        }
        .alert(item: Binding(get: { importProgress.forAlert }, set: { _ in })) { progress in
            guard let title = progress.localizedTitle else {
                return Alert(title: Text("Unknown error"))
            }

            return Alert(
                title: Text(title),
                message: progress.localizedDescription.map(Text.init),
                dismissButton: Alert.Button.default(
                    Text("OK"),
                    action: {
                        if progress.result != nil {
                            self.presentationMode.wrappedValue.dismiss()
                            env.requestAppStoreReview()
                        }
                    }
                )
            );
        }
    }

    var canImport: Bool {
        if selectedReader == nil { return false }

        if source == .file && pickedFileUrl == nil { return false }

        if source == .url && URL(string: urlSource) == nil { return false }

        return true
    }

    func performImport() {
        guard !importProgress.isImporting else { return }
        guard let reader = selectedReader else {
            importProgress = .failed(Errors.formInvalid)
            return
        }

        let dataSource: CompendiumDataSource
        if source == .file, let url = pickedFileUrl {
            dataSource = FileDataSource(path: url.path)
        } else if source == .url, let url = URL(string: urlSource) {
            dataSource = URLDataSource(url: reader.prepareUrl?(url).absoluteString ?? url.absoluteString)
        } else {
            importProgress = .failed(Errors.formInvalid)
            return
        }

        let importer = CompendiumImporter(compendium: env.compendium)
        let task = CompendiumImportTask(reader: reader.create(dataSource), overwriteExisting: true)

        let cancellable = importer.run(task)
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let e as Error) = completion {
                    self.importProgress = .failed(e)
                }
            }, receiveValue: { result in
                self.importProgress = .succeeded(result)
            })

        importProgress = .started(cancellable)
    }

    struct Reader: Identifiable {
        let id = UUID()
        let name: String
        let description: String?

        let create: (CompendiumDataSource) -> CompendiumDataSourceReader
        let prepareUrl: ((URL) -> URL)?
    }

    static var readers: [Reader] = [
        Reader(
            name: "Compendium XML",
            description: "Only creature entries are supported",
            create: XMLMonsterDataSourceReader.init,
            prepareUrl: nil
        ),
        Reader(
            name: "Improved Initiative JSON",
            description: "Only creature entries are supported",
            create: ImprovedInitiativeDataSourceReader.init,
            prepareUrl: nil
        ),
//        Reader(
//            name: "D&D Beyond Character",
//            description: nil,
//            create: DDBCharacterDataSourceReader.init,
//            prepareUrl: { url in
//                DDBCharacterSheetURLParser.parse(url.absoluteString).flatMap { id in
//                    URL(string: "https://www.dndbeyond.com/character/\(id)/json")
//                } ?? url
//            }
//        )
    ]

    enum Source: String, CaseIterable {
        case url, file
    }

    enum ImportProgress {
        case none, started(AnyCancellable), failed(Error), succeeded(CompendiumImporter.Result)

        var isImporting: Bool {
            if case .started = self { return true }
            return false
        }

        var result: CompendiumImporter.Result? {
            if case .succeeded(let result) = self { return result }
            return nil
        }

        var error: String? {
            if case .failed(let e) = self {
                return e.localizedDescription
            }
            return nil
        }
    }

    enum Errors: Error {
        case formInvalid
    }

}

struct CompendiumImportViewState: NavigationStackItemState, Equatable {
    var navigationStackItemStateId = "import"

    var navigationTitle: String { "Import" }
}

enum CompendiumImportViewAction {

}

extension CompendiumImportView.ImportProgress: Identifiable {
    var id: Int {
        switch self {
        case .none: return 0
        case .started: return 1
        case .succeeded: return 2
        case .failed: return 3
        }
    }
}

extension CompendiumImportView.ImportProgress {
    var forAlert: Self? {
        switch self {
        case .none, .started: return nil
        case .succeeded, .failed: return self
        }
    }

    var localizedTitle: String? {
        switch self {
        case .none, .started: return nil
        case .succeeded: return "Import completed"
        case .failed: return "Import failed"
        }
    }

    var localizedDescription: String? {
        switch self {
        case .none, .started: return nil
        case .succeeded(let result):
            return "\(result.newItemCount + result.overwrittenItemCount) item(s) imported (\(result.newItemCount ) new). \(result.invalidItemCount) item(s) skipped."
        case .failed(let error):
            return error.localizedDescription
        }
    }
}
