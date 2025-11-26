//
//  CompendiumDocumentsFeature.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2023.
//  Copyright 2023 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import SharedViews
import ComposableArchitecture
import GameModels
import Persistence
import Helpers
import SharedViews

@Reducer
struct CompendiumDocumentsFeature {
    @ObservableState
    struct State: Equatable {
        var documents: [CompendiumSourceDocument] = []
        var realms: [CompendiumRealm] = []

        @Presents var sheet: Sheet.State?

        func documents(for realm: CompendiumRealm) -> [CompendiumSourceDocument] {
            documents.filter { $0.realmId == realm.id }
        }
    }

    enum Action: Equatable {
        case onAppear
        case documentsDidChange([CompendiumSourceDocument])
        case realmsDidChange([CompendiumRealm])

        case onEditRealmTap(CompendiumRealm)
        case onAddDocumentToRealmTap(CompendiumRealm)
        case onRemoveEmptyRealmTap(CompendiumRealm)
        case onDocumentTap(CompendiumSourceDocument)
        case onAddRealmButtonTap
        case onAddDocumentButtonTap

        case sheet(PresentationAction<Sheet.Action>)
        case editDocumentSheet
    }

    @Reducer
    enum Sheet {
        case editRealm(EditRealm)
        case editDocument(EditDocument)
    }

    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for try await documents in compendiumMetadata.observeSourceDocuments() {
                        await send(.documentsDidChange(documents.sorted(by: .init(\.displayName))))
                    }
                }.merge(with: .run(operation: { send in
                    for try await realms in compendiumMetadata.observeRealms() {
                        await send(.realmsDidChange(realms.sorted(by: .init(\.displayName))))
                    }
                }))
            case .documentsDidChange(let documents):
                state.documents = documents
            case .realmsDidChange(let realms):
                state.realms = realms
            case .onEditRealmTap(let realm):
                state.sheet = .editRealm(.init(original: realm))
            case .onAddDocumentToRealmTap(let realm):
                state.sheet = .editDocument(apply(.init(realms: state.realms)) { sheet in
                    sheet.realmId = realm.id
                })
            case .onRemoveEmptyRealmTap(let realm):
                return .run { send in
                    try await compendiumMetadata.removeRealm(realm.id)
                }
            case .onDocumentTap(let doc):
                state.sheet = .editDocument(.init(original: doc, realms: state.realms))
            case .onAddRealmButtonTap:
                state.sheet = .editRealm(.init())
            case .onAddDocumentButtonTap:
                state.sheet = .editDocument(.init(realms: state.realms))
            case .sheet, .editDocumentSheet:
                break
            }
            return .none
        }
        .ifLet(\.$sheet, action: \.sheet)
    }
}

@Reducer
struct EditRealm {
    @ObservableState
    struct State: Equatable {
        var original: CompendiumRealm? // nil for new realms, non-nil for editing

        var displayName: String = ""
        var error: String?

        var customSlug: String?
        var effectiveSlug: String {
            if let original {
                return original.id.rawValue
            }
            return customSlug?.nonEmptyString ?? slug(displayName)
        }

        var navigationTitle: String {
            if let original {
                return "Edit “\(original.displayName)”"
            }
            return "Add realm"
        }

        var doneButtonDisabled: Bool {
            displayName.nonEmptyString == nil || original?.isDefaultRealm == true
        }

        var hasPendingChanges: Bool {
            if let original {
                return displayName != original.displayName
            } else {
                return !displayName.isEmpty || customSlug != nil
            }
        }

        var notice: Notice? {
            if original?.isDefaultRealm == true {
                return Notice(
                    icon: "info.circle.fill",
                    message: "This is a default realm and cannot be edited.",
                    foregroundColor: .primary,
                    isDismissible: false
                )
            }

            if let error {
                return .error(error)
            }
            return nil
        }

        init(original: CompendiumRealm? = nil) {
            if let original {
                self.original = original
                self.displayName = original.displayName
                if original.id.rawValue != slug(original.displayName) {
                    self.customSlug = original.id.rawValue
                }
            }
        }
    }

    enum Action: BindableAction, Equatable {
        case onCancelButtonTap
        case onDoneButtonTap
        case onErrorTap
        case onSlugChange(String)
        case errorDidOccur(String)
        case binding(BindingAction<State>)
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onCancelButtonTap:
                return .run { _ in await dismiss() }

            case .onDoneButtonTap:
                guard let displayName = state.displayName.nonEmptyString else {
                    return .none
                }

                guard state.hasPendingChanges else {
                    return .run { _ in await dismiss() }
                }

                return .run { [state] send in
                    do {
                        if let original = state.original {
                            // update existing realm
                            try await compendiumMetadata.updateRealm(original.id, displayName)
                        } else {
                            // create new realm
                            try compendiumMetadata.createRealm(CompendiumRealm(
                                id: .init(state.effectiveSlug),
                                displayName: displayName
                            ))
                        }
                        await dismiss()
                    } catch {
                        await send(.errorDidOccur(error.localizedDescription))
                    }
                }
            case .onErrorTap:
                state.error = nil

            case .errorDidOccur(let errorMessage):
                state.error = errorMessage

            case .onSlugChange(let newSlug):
                // Don't allow slug changes for existing realms
                guard state.original == nil else { return .none }
                
                if newSlug != slug(state.displayName) {
                    state.customSlug = newSlug
                } else {
                    state.customSlug = nil
                }
            case .binding:
                break
            }
            return .none
        }
    }
}

@Reducer
struct EditDocument {
    @ObservableState
    struct State: Equatable {
        var original: CompendiumSourceDocument? // nil for new documents, non-nil for editing
        let realms: [CompendiumRealm]

        var displayName: String = ""
        var realmId: CompendiumRealm.Id?

        typealias AsyncOperation = Async<Bool, EquatableError>
        var operation: AsyncOperation.State? = nil
        var isLoading: Bool {
            operation?.isLoading == true
        }

        @Presents var contents: CompendiumIndexFeature.State?

        var customSlug: String?
        var effectiveSlug: String {
            customSlug?.nonEmptyString ?? slug(displayName)
        }

        var navigationTitle: String {
            if let original {
                return "Edit “\(original.displayName)”"
            }

            return "Add document"
        }

        var doneButtonDisabled: Bool {
            displayName.nonEmptyString == nil || realmId == nil || original?.isDefaultDocument == true
        }

        var hasPendingChanges: Bool {
            if let original {
                return displayName != original.displayName ||
                       realmId != original.realmId
            } else {
                return !displayName.isEmpty || customSlug != nil || realmId != nil
            }
        }
        
        var notice: Notice? {
            if original?.isDefaultDocument == true {
                return Notice(
                    icon: "info.circle.fill",
                    message: "This is a default document and cannot be edited.",
                    foregroundColor: .primary,
                    isDismissible: false
                )
            }
            if let error = operation?.error {
                return .error(error)
            }
            return nil
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

    enum Action: BindableAction, Equatable {
        case onCancelButtonTap
        case onDoneButtonTap
        case onErrorTap
        case onConfirmRemoveDocumentTap

        case onSlugChange(String)
        case operationDidUpdate(State.AsyncOperation.State?)

        case onViewItemsInDocumentTap
        case contents(PresentationAction<CompendiumIndexFeature.Action>)

        case binding(BindingAction<State>)
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onCancelButtonTap:
                return .run { _ in await dismiss() }
            case .onDoneButtonTap:
                guard let displayName = state.displayName.nonEmptyString,
                        let realmId = state.realmId else {
                    return .none
                }

                guard state.hasPendingChanges else {
                    return .run { _ in await dismiss() }
                }

                return compendiumMetadataOperation(state: &state) { [state, displayName, realmId] in
                    if let original = state.original {
                        try await compendiumMetadata.updateDocument(
                            CompendiumSourceDocument(
                                id: .init(state.effectiveSlug),
                                displayName: displayName,
                                realmId: realmId
                            ),
                            original.realmId,
                            original.id
                        )
                    } else {
                        // new document
                        try compendiumMetadata.createDocument(CompendiumSourceDocument(
                            id: .init(state.effectiveSlug),
                            displayName: displayName,
                            realmId: realmId
                        ))
                    }
                }
            case .onErrorTap:
                state.operation = nil
            case .onConfirmRemoveDocumentTap:
                guard let original = state.original else { break }

                return compendiumMetadataOperation(state: &state) {
                    // remove document
                    try await compendiumMetadata.removeDocument(original.realmId, original.id)
                }
            case .onSlugChange(let newSlug):
                // Don't allow slug changes for existing documents
                guard state.original == nil else { return .none }
                
                if newSlug != slug(state.displayName) {
                    state.customSlug = newSlug
                } else {
                    state.customSlug = nil
                }
            case .operationDidUpdate(let newOperation):
                state.operation = newOperation
            case .onViewItemsInDocumentTap:
                guard let original = state.original else { break }

                state.contents = CompendiumIndexFeature.State(
                    title: original.displayName,
                    properties: .init(showImport: false, showAdd: false, sourceRestriction: .init(
                        realm: original.realmId,
                        document: original.id
                    )),
                    results: .initial
                )
            case .contents, .binding:
                break
            }
            return .none
        }
        .ifLet(\.$contents, action: \.contents) {
            CompendiumIndexFeature()
        }
    }

    private func compendiumMetadataOperation(
        state: inout State,
        operation: @escaping () async throws -> Void,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) -> Effect<Action> {
        state.operation = State.AsyncOperation.State(isLoading: true)
        return .run(
            operation: { @MainActor send in
                let operationTask = Task {
                    try await operation()
                    return true
                }

                // make the operation take a minimum amount of time, to prevent UI flickering
                let delayTask = Task {
                    try await Task.sleep(for: .seconds(0.5))
                }

                let (operationResult, _) = await (operationTask.result, delayTask.result)

                send(.operationDidUpdate(State.AsyncOperation.State(isLoading: false, result: operationResult.mapError { $0.toEquatableError() })), animation: .default)

                if operationResult.value != nil {
                    await dismiss()
                }
            },
            fileID: fileID,
            line: line
        )
    }
}

struct CompendiumDocumentsView: View {

    let store: StoreOf<CompendiumDocumentsFeature>

    var body: some View {
        content
            .onAppear {
                store.send(.onAppear)
            }
            .navigationTitle("Documents")
    }

    @ViewBuilder
    private func realmSection(
        realm: CompendiumRealm,
        documents: [CompendiumSourceDocument]
    ) -> some View {
        SectionContainer(
            title: realm.displayName,
            accessory: Menu(content: {
                Button(action: {
                    store.send(.onEditRealmTap(realm))
                }, label: {
                    SwiftUI.Label("Edit realm", systemImage: "pencil")
                })

                Divider()

                Button(action: {
                    store.send(.onAddDocumentToRealmTap(realm))
                }, label: {
                    SwiftUI.Label("Add document", systemImage: "doc.badge.plus")
                })

                Button(role: .destructive, action: {
                    store.send(.onRemoveEmptyRealmTap(realm))
                }, label: {
                    SwiftUI.Label("Remove empty realm", systemImage: "trash")
                })
                .disabled(!documents.isEmpty)
            }, label: {
                Image(systemName: "ellipsis.circle")
            })
        ) {
            if documents.isEmpty {
                Text("No documents").italic()
                    .frame(minHeight: 35)
            } else {
                VStack {
                    ForEach(documents, id: \.id) { document in
                        NavigationRowButton {
                            store.send(.onDocumentTap(document))
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

    @ViewBuilder
    private var content: some View {
        let sheetStore = store.scope(state: \.$sheet, action: \.sheet)

        let documentsView = ScrollView {
            VStack(spacing: 20) {
                ForEach(store.realms, id: \.id) { realm in
                    let documents = store.documents.filter { $0.realmId == realm.id }

                    realmSection(realm: realm, documents: documents)
                }
            }
            .padding()
        }

        documentsView
            .safeAreaInset(edge: .bottom) {
                RoundedButtonToolbar {
                    Button(action: {
                        store.send(.onAddRealmButtonTap)
                    }) {
                        SwiftUI.Label("Add realm", systemImage: "plus.circle")
                    }

                    Button(action: {
                        store.send(.onAddDocumentButtonTap)
                    }) {
                        SwiftUI.Label("Add document", systemImage: "doc.badge.plus")
                    }
                }
                .padding(8)
            }
            .sheet(
                store: sheetStore
            ) { sheetStore in
                switch sheetStore.case {
                case let .editRealm(store):
                    AutoSizingSheetContainer {
                        SheetNavigationContainer {
                            EditRealmView(store: store)
                        }
                    }
                case let .editDocument(store):
                    AutoSizingSheetContainer {
                        SheetNavigationContainer {
                            CompendiumDocumentEditView(store: store)
                        }
                    }
                }
            }
    }
}

extension CompendiumDocumentsFeature.Sheet.State: Equatable {}
extension CompendiumDocumentsFeature.Sheet.Action: Equatable {}

struct CompendiumDocumentEditView: View {

    @Bindable var store: StoreOf<EditDocument>

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let notice = store.notice {
                    NoticeView(notice: notice)
                }

                SectionContainer {
                    VStack {
                        TextFieldWithSlug(
                            title: "Document name",
                            text: $store.displayName.sending(\.binding.displayName),
                            slug: Binding(
                                get: { store.effectiveSlug },
                                set: { store.send(.onSlugChange($0)) }
                            ),
                            configuration: .init(
                                textForegroundColor: Color(UIColor.label),
                                slugForegroundColor: Color(UIColor.secondaryLabel),
                                slugFieldEnabled: store.original == nil
                            ),
                            requestFocusOnText: Binding.constant(store.original == nil)
                        )
                        .disabled(store.original?.isDefaultDocument == true)
                        .padding(.trailing, 10) // to align with the picker field

                        Divider()

                        MenuPickerField(
                            title: "Realm",
                            selection: $store.realmId.sending(\.binding.realmId)
                        ) {
                            ForEach(store.realms, id: \.id) { realm in
                                Text("\(realm.displayName) (\(realm.id.rawValue))").tag(Optional.some(realm.id))
                            }
                        }
                        .disabled(store.original?.isDefaultDocument == true)
                    }
                }

                if store.original != nil {
                    SectionContainer {
                        NavigationRowButton {
                            store.send(.onViewItemsInDocumentTap)
                        } label: {
                            HStack {
                                SwiftUI.Label("View items in document", systemImage: "book")
                            }
                            .frame(minHeight: 35)
                        }
                    }

                    SectionContainer {
                        VStack {
                            Menu {
                                Text("All items in the document will be removed.").font(.footnote)

                                Divider()

                                Button(role: .destructive) {
                                    store.send(.onConfirmRemoveDocumentTap)
                                } label: {
                                    SwiftUI.Label("Confirm", systemImage: "trash")
                                }

                            } label: {
                                Button(role: .destructive, action: { }) {
                                    SwiftUI.Label("Remove document & contents", systemImage: "trash")
                                    Spacer()
                                }
                                .symbolVariant(.circle.fill)
                                .imageScale(.large)
                            }
                            .frame(minHeight: 35)
                        }
                    }
                    .symbolRenderingMode(.hierarchical)
                    .disabled(store.original?.isDefaultDocument == true)
                }
            }
            .padding()
            .autoSizingSheetContent(constant: 100)
        }
        .navigationDestination(
            store: store.scope(state: \.$contents, action: \.contents),
            destination: { store in
                CompendiumIndexView(store: store)
            }
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if store.isLoading {
                    ProgressView()
                } else {
                    Button(action: {
                        store.send(.onDoneButtonTap, animation: .spring())
                    }, label: {
                        Text("Done").bold()
                    })
                    .disabled(store.doneButtonDisabled)
                }
            }

            ToolbarItem(placement: .navigation) {
                Button("Cancel", role: .destructive) {
                    store.send(.onCancelButtonTap)
                }
            }
        }
        .navigationTitle(store.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(store.hasPendingChanges || store.isLoading)
    }
}

struct EditRealmView: View {
    @Bindable var store: StoreOf<EditRealm>

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let notice = store.notice {
                    SectionContainer {
                        VStack(alignment: notice.isDismissible ? .trailing : .leading) {
                            HStack(spacing: 12) {
                                Text(Image(systemName: notice.icon))
                                Text(notice.message)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(8)
                            .foregroundStyle(notice.foregroundColor)
                            .symbolRenderingMode(.monochrome)
                            .symbolVariant(.fill)

                            if notice.isDismissible {
                                Text("Tap to dismiss")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                    .onTapGesture {
                        if notice.isDismissible {
                            store.send(.onErrorTap, animation: .default)
                        }
                    }
                }

                SectionContainer {
                    TextFieldWithSlug(
                        title: "Realm name",
                        text: $store.displayName.sending(\.binding.displayName),
                        slug: Binding(
                            get: { store.effectiveSlug },
                            set: { store.send(.onSlugChange($0)) }
                        ),
                        configuration: .init(
                            textForegroundColor: Color(UIColor.label),
                            slugForegroundColor: Color(UIColor.secondaryLabel),
                            slugFieldEnabled: store.original == nil
                        ),
                        requestFocusOnText: Binding.constant(store.original == nil)
                    )
                    .padding(.trailing, 10)
                }
                .disabled(store.original?.isDefaultRealm == true)
            }
            .padding()
            .autoSizingSheetContent(constant: 100)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    store.send(.onDoneButtonTap)
                }, label: {
                    Text("Done").bold()
                })
                .disabled(store.doneButtonDisabled)
            }

            ToolbarItem(placement: .navigation) {
                Button("Cancel", role: .destructive) {
                    store.send(.onCancelButtonTap)
                }
            }
        }
        .navigationTitle(store.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(store.hasPendingChanges)
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
