//
//  CompendiumDocumentsFeature.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2023.
//  Copyright © 2023 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import SharedViews
import ComposableArchitecture
import GameModels
import Persistence
import SwiftUINavigation
import Helpers

struct CompendiumDocumentsFeature: ReducerProtocol {
    struct State: Equatable {
        @BindingState var documents: [CompendiumSourceDocument] = []
        @BindingState var realms: [CompendiumRealm] = []

        @PresentationState var sheet: Sheet.State?

        func documents(for realm: CompendiumRealm) -> [CompendiumSourceDocument] {
            documents.filter { $0.realmId == realm.id }
        }
    }

    enum Action: BindableAction {
        case onAppear

        case onAddDocumentToRealmTap(CompendiumRealm)
        case onRemoveEmptyRealmTap(CompendiumRealm)
        case onDocumentTap(CompendiumSourceDocument)
        case onAddRealmButtonTap
        case onAddDocumentButtonTap

        case sheet(PresentationAction<Sheet.Action>)
        case editDocumentSheet

        case binding(BindingAction<State>)
    }

    struct Sheet: ReducerProtocol {
        enum State: Equatable {
            case addRealm(AddRealm.State)
            case editDocument(EditDocument.State)
        }

        enum Action {
            case addRealm(AddRealm.Action)
            case editDocument(EditDocument.Action)
        }

        var body: some ReducerProtocolOf<Self> {
            Scope(state: /State.addRealm, action: /Action.addRealm) {
                AddRealm()
            }

            Scope(state: /State.editDocument, action: /Action.editDocument) {
                EditDocument()
            }
        }
    }

    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerProtocolOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for try await documents in compendiumMetadata.observeSourceDocuments() {
                        await send(.binding(.set(\.$documents, documents.sorted(by: .init(\.displayName)))))
                    }
                }.merge(with: .run(operation: { send in
                    for try await realms in compendiumMetadata.observeRealms() {
                        await send(.binding(.set(\.$realms, realms.sorted(by: .init(\.displayName)))))
                    }
                }))
            case .onAddDocumentToRealmTap(let realm):
                state.sheet = .editDocument(apply(.init(realms: state.realms)) { sheet in
                    sheet.realmId = realm.id
                })
            case .onRemoveEmptyRealmTap(let realm):
                break
            case .onDocumentTap(let doc):
                state.sheet = .editDocument(.init(original: doc, realms: state.realms))
            case .onAddRealmButtonTap:
                state.sheet = .addRealm(.init())
            case .onAddDocumentButtonTap:
                state.sheet = .editDocument(.init(realms: state.realms))
            default: break
            }
            return .none
        }
        .ifLet(\.$sheet, action: /Action.sheet) {
            Sheet()
        }

        BindingReducer()
    }
}

struct AddRealm: ReducerProtocol {
    struct State: Equatable {

    }

    enum Action {

    }

    var body: some ReducerProtocolOf<Self> {
        EmptyReducer()
    }
}

struct EditDocument: ReducerProtocol {
    struct State: Equatable {
        var original: CompendiumSourceDocument? // nil for new documents, non-nil for editing
        let realms: [CompendiumRealm]

        @BindingState var displayName: String = ""
        @BindingState var realmId: CompendiumRealm.Id?

        @BindingState var conflictingSlugOnSave: String? = nil

        var customSlug: String?
        var effectiveSlug: String {
            get {
                customSlug?.nonEmptyString ?? slug(displayName)
            }
            set {
                if newValue == slug(displayName) {
                    customSlug = nil
                } else {
                    customSlug = newValue
                }
            }
        }

        var navigationTitle: String {
            if let original {
                return "Edit “\(original.displayName)”"
            }

            return "Add document"
        }

        var doneButtonDisabled: Bool {
            displayName.nonEmptyString == nil || realmId == nil
        }

        init(original: CompendiumSourceDocument? = nil, realms: [CompendiumRealm]) {
            if let original {
                self.original = original

                self.displayName = original.displayName
                if original.id.rawValue != slug(original.displayName) {
                    self.customSlug = original.id.rawValue
                }
                self.realmId = original.realmId
            }

            self.realms = realms
        }
    }

    enum Action: BindableAction {
        case onCancelButtonTap
        case onDoneButtonTap
        case onConfirmRemoveDocumentTap

        case onSlugChange(String)

        case binding(BindingAction<State>)
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerProtocolOf<Self> {
        Reduce { state, action in
            switch action {
            case .onCancelButtonTap:
                return .fireAndForget { await dismiss() }
            case .onDoneButtonTap:
                state.conflictingSlugOnSave = nil

                return .run { [state] send in
                    if state.original == nil {
                        guard let displayName = state.displayName.nonEmptyString,
                                let realmId = state.realmId else {
                            return
                        }

                        // new document
                        // todo: check if document doesn't override an existing one
                        try compendiumMetadata.createDocument(CompendiumSourceDocument(
                            id: .init(state.effectiveSlug),
                            displayName: displayName,
                            realmId: realmId
                        ))

                        await dismiss()
                    } else {
                        await send(.binding(.set(\.$conflictingSlugOnSave, state.effectiveSlug)), animation: .spring())
                    }
                }
            case .onConfirmRemoveDocumentTap:
                return .fireAndForget {
                    // todo

                    await dismiss()
                }
            case .onSlugChange(let slug):
                state.customSlug = slug
            default: break
            }
            return .none
        }

        BindingReducer()
    }
}

struct CompendiumDocumentsView: View {

    let store: StoreOf<CompendiumDocumentsFeature>

    var body: some View {
        WithViewStore(store) { viewStore in
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewStore.state.realms, id: \.id) { realm in
                        let documents = viewStore.state.documents(for: realm)

                        SectionContainer(
                            title: realm.displayName,
                            accessory: Menu(content: {
                                Button(action: {
                                    viewStore.send(.onAddDocumentToRealmTap(realm))
                                }, label: {
                                    Label("Add document", systemImage: "doc.badge.plus")
                                })

                                Button(role: .destructive, action: {
                                    viewStore.send(.onRemoveEmptyRealmTap(realm))
                                }, label: {
                                    Label("Remove empty realm", systemImage: "trash")
                                })
                                .disabled(!documents.isEmpty)
                            }, label: {
                                Image(systemName: "ellipsis.circle")
                            })
                        ) {
                            if documents.isEmpty {
                                Text("No documents").italic()
                            } else {
                                VStack {
                                    ForEach(documents, id: \.id) { document in
                                        NavigationRowButton {
                                            viewStore.send(.onDocumentTap(document))
                                        } label: {
                                            HStack {
                                                Text(document.displayName)
                                                Spacer()
                                                Text(document.id.rawValue)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(minHeight: 35)

                                        if document != documents.last {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                RoundedButtonToolbar {
                    Button(action: {
                        viewStore.send(.onAddRealmButtonTap)
                    }) {
                        Label("Add realm", systemImage: "plus.circle")
                    }

                    Button(action: {
                        viewStore.send(.onAddDocumentButtonTap)
                    }) {
                        Label("Add document", systemImage: "doc.badge.plus")
                    }
                }
            }
            .sheet(
                store: store.scope(state: \.$sheet, action: CompendiumDocumentsFeature.Action.sheet),
                state: /CompendiumDocumentsFeature.Sheet.State.addRealm,
                action: CompendiumDocumentsFeature.Sheet.Action.addRealm
            ) { _ in
                Text("Hello")
            }
            .sheet(
                store: store.scope(state: \.$sheet, action: CompendiumDocumentsFeature.Action.sheet),
                state: /CompendiumDocumentsFeature.Sheet.State.editDocument,
                action: CompendiumDocumentsFeature.Sheet.Action.editDocument
            ) { store in
                AutoSizingSheetContainer {
                    SheetNavigationContainer {
                        CompendiumDocumentEditView(store: store)
                    }
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

struct CompendiumDocumentEditView: View {

    let store: StoreOf<EditDocument>

    var body: some View {
        WithViewStore(store) { viewStore in
            ScrollView {
                VStack(spacing: 20) {

                    if let slug = viewStore.state.conflictingSlugOnSave {
                        SectionContainer {
                            HStack(spacing: 12) {
                                Text(Image(systemName: "exclamationmark.octagon"))

                                Text("Shorthand \(Text(slug).fontDesign(.monospaced)) is not available. Tap the shorthand to edit.")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(8)
                            .foregroundStyle(Color(UIColor.systemRed))
                            .symbolRenderingMode(.monochrome)
                            .symbolVariant(.fill)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    SectionContainer {
                        VStack {
                            TextFieldWithSlug(
                                title: "Document name",
                                text: viewStore.binding(\.$displayName),
                                slug: viewStore.binding(
                                    get: \.effectiveSlug,
                                    send: { .onSlugChange($0) }
                                ),
                                configuration: .init(
                                    textForegroundColor: Color(UIColor.label),
                                    slugForegroundColor: Color(UIColor.secondaryLabel)
                                ),
                                requestFocusOnText: Binding.constant(viewStore.state.original == nil)
                            )
                            .padding(.trailing, 10) // to align with the picker field

                            Divider()

                            MenuPickerField(
                                title: "Realm",
                                selection: viewStore.binding(\.$realmId)
                            ) {
                                ForEach(viewStore.state.realms, id: \.id) { realm in
                                    Text("\(realm.displayName) (\(realm.id.rawValue))").tag(Optional.some(realm.id))
                                }
                            }
                        }
                    }

                    if viewStore.state.original != nil {
//                        SectionContainer(title: "Contents") {
//                            VStack(alignment: .leading) {
//                                Text("Document contains 1 item(s)")
//                                    .foregroundStyle(Color.secondary)
//                                    .frame(minHeight: 35)
//
//                                Divider()
//
//                                DisclosureGroup(content: {
//                                    SectionContainer(backgroundColor: Color(UIColor.systemBackground)) {
//                                        HStack {
//                                            Picker(selection: Binding.constant(0)) {
//                                                Text("Select destination...").tag(0)
//                                            } label: {
//                                                Text("B")
//                                            }
//
//                                            Spacer()
//
//                                            Button(action: { }, label: {
//                                                Text("Move")
//                                            })
//                                            .disabled(true)
//                                            .buttonStyle(.borderedProminent)
//                                            .buttonBorderShape(.roundedRectangle)
//                                        }
//                                    }
//                                    .padding(.top, 4)
//                                }, label: {
//                                    Label("Move", systemImage: "doc").tint(Color.secondary).bold()
//                                        .symbolVariant(.circle.fill)
//                                        .imageScale(.large)
//                                        .symbolRenderingMode(.hierarchical)
//                                })
//                            }
//                        }

                        SectionContainer {
                            VStack {
                                Menu {
                                    Text("Remove the document and its contents").font(.footnote)

                                    Divider()

                                    Button(role: .destructive) {
                                        viewStore.send(.onConfirmRemoveDocumentTap)
                                    } label: {
                                        Label("Confirm", systemImage: "trash")
                                    }

                                } label: {
                                    Button(role: .destructive, action: { }) {
                                        Label("Remove document & contents", systemImage: "trash")
                                        Spacer()
                                    }
                                    .symbolVariant(.circle.fill)
                                    .imageScale(.large)
                                }
                                .frame(minHeight: 35)
                            }
                        }
                        .symbolRenderingMode(.hierarchical)
                    }
                }
                .padding()
                .autoSizingSheetContent(constant: 100)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        viewStore.send(.onDoneButtonTap, animation: .spring())
                    }, label: {
                        Text("Done").bold()
                    })
                    .disabled(viewStore.state.doneButtonDisabled)
                }

                ToolbarItem(placement: .navigation) {
                    Button("Cancel", role: .destructive) {
                        viewStore.send(.onCancelButtonTap)
                    }
                }
            }
            .navigationTitle(viewStore.state.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
struct CompendiumDocumentsPreview: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CompendiumDocumentsView(
                store: Store(initialState: .init()) {
                    CompendiumDocumentsFeature()
                        .transformDependency(\.compendiumMetadata) { compendiumMetadata in
                            @Dependency(\.database) var database

                            do {
                                try database.keyValueStore.put(CompendiumRealm.core)
                                try database.keyValueStore.put(CompendiumRealm.homebrew)

                                try database.keyValueStore.put(CompendiumSourceDocument.srd5_1)
                                try database.keyValueStore.put(CompendiumSourceDocument.unspecifiedCore)
                                try database.keyValueStore.put(CompendiumSourceDocument.homebrew)
                            } catch {
                                print(error)
                            }

                            compendiumMetadata = .live(database)
                        }
                        .dependency(\.database, Database.uninitialized)
                }
            )
            .navigationTitle("Source documents")
        }
    }
}
#endif
