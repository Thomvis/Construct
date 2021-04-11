//
//  CompendiumImportView.swift
//  SwiftUITest
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
            // Show error
            importProgress.error.map {
                Text("Import failed: \($0)").foregroundColor(Color(UIColor.systemRed))
            }

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
                if importProgress.isImporting {
                    Text("Importing...")
                } else {
                    Text("Import now")
                }
            }.disabled(!canImport || importProgress.isImporting)
        }
        .navigationBarTitle(CompendiumImportViewState().navigationTitle)
        .sheet(isPresented: $openDocumentPicker) {
            DocumentPicker { urls in
                self.pickedFileUrl = urls.first
            }
        }
        .alert(isPresented: Binding(get: { importProgress.isSuccess }, set: { _ in })) {
            Alert(title: Text("Import completed"), dismissButton: Alert.Button.default(Text("OK"), action: {
                self.presentationMode.wrappedValue.dismiss()
            }));
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

        let cancellable = importer.run(task).delay(for: .seconds(0), scheduler: DispatchQueue.main).sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                self.importProgress = .succeeded
            case .failure(let e as Error):
                self.importProgress = .failed(e)
            }
        }, receiveValue: { _ in })
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
        case none, started(AnyCancellable), failed(Error), succeeded

        var isImporting: Bool {
            if case .started = self { return true }
            return false
        }

        var isSuccess: Bool {
            if case .succeeded = self { return true }
            return false
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
