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
import SwiftUINavigation
import Helpers
import SharedViews

struct CompendiumDocumentsFeature: ReducerProtocol {
    struct State: Equatable {
        @BindingState var documents: [CompendiumSourceDocument] = []
        @BindingState var realms: [CompendiumRealm] = []

        @PresentationState var sheet: Sheet.State?

        func documents(for realm: CompendiumRealm) -> [CompendiumSourceDocument] {
            documents.filter { $0.realmId == realm.id }
        }
    }

    enum Action: BindableAction, Equatable {
        case onAppear

        case onEditRealmTap(CompendiumRealm)
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
            case editRealm(EditRealm.State)
            case editDocument(EditDocument.State)
        }

        enum Action: Equatable {
            case editRealm(EditRealm.Action)
            case editDocument(EditDocument.Action)
        }

        var body: some ReducerProtocolOf<Self> {
            Scope(state: /State.editRealm, action: /Action.editRealm) {
                EditRealm()
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

struct EditRealm: ReducerProtocol {
    struct State: Equatable {
        var original: CompendiumRealm? // nil for new realms, non-nil for editing

        @BindingState var displayName: String = ""
        @BindingState var error: String?

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
        case binding(BindingAction<State>)
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerProtocolOf<Self> {
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
                        await send(.binding(.set(\.$error, error.localizedDescription)))
                    }
                }
            case .onErrorTap:
                state.error = nil

            case .onSlugChange(let newSlug):
                // Don't allow slug changes for existing realms
                guard state.original == nil else { return .none }
                
                if newSlug != slug(state.displayName) {
                    state.customSlug = newSlug
                } else {
                    state.customSlug = nil
                }
            default: break
            }
            return .none
        }

        BindingReducer()
    }
}

struct EditDocument: ReducerProtocol {
    struct State: Equatable {
        var original: CompendiumSourceDocument? // nil for new documents, non-nil for editing
        let realms: [CompendiumRealm]

        @BindingState var displayName: String = ""
        @BindingState var realmId: CompendiumRealm.Id?

        typealias AsyncOperation = Async<Bool, EquatableError>
        @BindingState var operation: AsyncOperation.State? = nil
        var isLoading: Bool {
            operation?.isLoading == true
        }

        @PresentationState var contents: CompendiumIndexFeature.State?

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

        case onViewItemsInDocumentTap
        case contents(PresentationAction<CompendiumIndexFeature.Action>)

        case binding(BindingAction<State>)
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerProtocolOf<Self> {
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
            default: break
            }
            return .none
        }
        .ifLet(\.$contents, action: /Action.contents) {
            CompendiumIndexFeature(environment: StandaloneCompendiumIndexEnvironment.fromDependencies())
        }

        BindingReducer()
    }

    private func compendiumMetadataOperation(
        state: inout State,
        operation: @escaping () async throws -> Void,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) -> EffectTask<Action> {
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

                send(.binding(.set(\.$operation, State.AsyncOperation.State(isLoading: false, result: operationResult.mapError { $0.toEquatableError() }))), animation: .default)

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
        WithViewStore(store, observe: \.self) { viewStore in
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewStore.state.realms, id: \.id) { realm in
                        let documents = viewStore.state.documents(for: realm)

                        SectionContainer(
                            title: realm.displayName,
                            accessory: Menu(content: {

                                Button(action: {
                                    viewStore.send(.onEditRealmTap(realm))
                                }, label: {
                                    Label("Edit realm", systemImage: "pencil")
                                })

                                Divider()

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
                                    .frame(minHeight: 35)
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
                .padding(8)
            }
            .sheet(
                store: store.scope(state: \.$sheet, action: CompendiumDocumentsFeature.Action.sheet),
                state: /CompendiumDocumentsFeature.Sheet.State.editRealm,
                action: CompendiumDocumentsFeature.Sheet.Action.editRealm
            ) { store in
                AutoSizingSheetContainer {
                    SheetNavigationContainer {
                        EditRealmView(store: store)
                    }
//                    .autoSizingSheetContent(constant: ViewStore(store).state)
                }
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
//                    .autoSizingSheetContent(constant: ViewStore(store).state)
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .navigationTitle("Documents")
        }
    }
}

struct CompendiumDocumentEditView: View {

    let store: StoreOf<EditDocument>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            ScrollView {
                VStack(spacing: 20) {
                    if let notice = viewStore.notice {
                        NoticeView(notice: notice)
                    }

                    SectionContainer {
                        VStack {
                            TextFieldWithSlug(
                                title: "Document name",
                                text: viewStore.$displayName,
                                slug: viewStore.binding(
                                    get: \.effectiveSlug,
                                    send: { .onSlugChange($0) }
                                ),
                                configuration: .init(
                                    textForegroundColor: Color(UIColor.label),
                                    slugForegroundColor: Color(UIColor.secondaryLabel),
                                    slugFieldEnabled: viewStore.state.original == nil
                                ),
                                requestFocusOnText: Binding.constant(viewStore.state.original == nil)
                            )
                            .disabled(viewStore.state.original?.isDefaultDocument == true)
                            .padding(.trailing, 10) // to align with the picker field

                            Divider()

                            MenuPickerField(
                                title: "Realm",
                                selection: viewStore.$realmId
                            ) {
                                ForEach(viewStore.state.realms, id: \.id) { realm in
                                    Text("\(realm.displayName) (\(realm.id.rawValue))").tag(Optional.some(realm.id))
                                }
                            }
                            .disabled(viewStore.state.original?.isDefaultDocument == true)
                        }
                    }

                    if viewStore.state.original != nil {
                        SectionContainer {
                            NavigationRowButton {
                                viewStore.send(.onViewItemsInDocumentTap)
                            } label: {
                                HStack {
                                    Label("View items in document", systemImage: "book")
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
                        .disabled(viewStore.state.original?.isDefaultDocument == true)
                    }
                }
                .padding()
                .autoSizingSheetContent(constant: 100)
            }
            .navigationDestination(
                store: store.scope(state: \.$contents, action: EditDocument.Action.contents),
                destination: { store in
                    CompendiumIndexView(store: store)
                }
            )
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if viewStore.state.isLoading {
                        ProgressView()
                    } else {
                        Button(action: {
                            viewStore.send(.onDoneButtonTap, animation: .spring())
                        }, label: {
                            Text("Done").bold()
                        })
                        .disabled(viewStore.state.doneButtonDisabled)
                    }
                }

                ToolbarItem(placement: .navigation) {
                    Button("Cancel", role: .destructive) {
                        viewStore.send(.onCancelButtonTap)
                    }
                }
            }
            .navigationTitle(viewStore.state.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(viewStore.state.hasPendingChanges || viewStore.state.isLoading)
        }
    }
}

struct EditRealmView: View {
    let store: StoreOf<EditRealm>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            ScrollView {
                VStack(spacing: 20) {
                    if let notice = viewStore.notice {
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
                                viewStore.send(.onErrorTap, animation: .default)
                            }
                        }
                    }

                    SectionContainer {
                        TextFieldWithSlug(
                            title: "Realm name",
                            text: viewStore.$displayName,
                            slug: viewStore.binding(
                                get: \.effectiveSlug,
                                send: { .onSlugChange($0) }
                            ),
                            configuration: .init(
                                textForegroundColor: Color(UIColor.label),
                                slugForegroundColor: Color(UIColor.secondaryLabel),
                                slugFieldEnabled: viewStore.state.original == nil
                            ),
                            requestFocusOnText: Binding.constant(viewStore.state.original == nil)
                        )
                        .padding(.trailing, 10)
                    }
                    .disabled(viewStore.state.original?.isDefaultRealm == true)
                }
                .padding()
                .autoSizingSheetContent(constant: 100)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        viewStore.send(.onDoneButtonTap)
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
            .interactiveDismissDisabled(viewStore.state.hasPendingChanges)
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
