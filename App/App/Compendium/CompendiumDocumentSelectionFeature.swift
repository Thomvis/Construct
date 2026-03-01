import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels
import Compendium
import Helpers

@Reducer
struct CompendiumDocumentSelectionFeature {
    @ObservableState
    struct State: Equatable {
        let unselectedLabel: String?
        let disabledSources: [CompendiumFilters.Source]

        typealias AsyncDocuments = Async<[CompendiumSourceDocument], EquatableError>
        var documents: AsyncDocuments.State = .initial
        typealias AsyncRealms = Async<[CompendiumRealm], EquatableError>
        var realms: AsyncRealms.State = .initial

        var selectedSource: CompendiumFilters.Source?

        var currentDocument: CompendiumSourceDocument? {
            guard let source = selectedSource else { return nil }
            return documents.value?.first(where: { $0.realmId == source.realm && $0.id == source.document })
        }

        var selectedSourceDisplayName: String? {
            currentDocument.map(\.displayName) ?? unselectedLabel
        }

        var allSources: [(document: CompendiumSourceDocument, realm: CompendiumRealm)]? {
            guard let documents = documents.value, let realms = realms.value else {
                return nil
            }

            let documentsByRealm = Dictionary(grouping: documents, by: \.realmId)
            return realms.flatMap { realm in
                (documentsByRealm[realm.id] ?? []).map { document in
                    (document: document, realm: realm)
                }
            }
        }

        init(
            selectedSource: CompendiumFilters.Source? = nil,
            disabledSources: [CompendiumFilters.Source] = [],
            unselectedLabel: String = "All"
        ) {
            self.selectedSource = selectedSource
            self.disabledSources = disabledSources
            self.unselectedLabel = unselectedLabel
        }

        init(
            selectedSource: CompendiumFilters.Source,
            disabledSources: [CompendiumFilters.Source] = []
        ) {
            self.selectedSource = selectedSource
            self.disabledSources = disabledSources
            self.unselectedLabel = nil
        }

        func source(for document: CompendiumSourceDocument, realm: CompendiumRealm) -> CompendiumFilters.Source {
            .init(realm: realm.id, document: document.id)
        }
    }

    @CasePathable
    enum Action: BindableAction, Equatable {
        case onAppear
        case source(CompendiumSourceDocument, CompendiumRealm)
        case clearSource
        case documents(State.AsyncDocuments.Action)
        case realms(State.AsyncRealms.Action)
        case binding(BindingAction<State>)
    }

    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case let .source(document, realm):
                state.selectedSource = state.source(for: document, realm: realm)
                return .none

            case .clearSource:
                state.selectedSource = nil
                return .none

            case .documents, .realms, .binding:
                return .none
            }
        }

        Scope(state: \.documents, action: \.documents) {
            State.AsyncDocuments(compendiumMetadata: compendiumMetadata)
        }

        Scope(state: \.realms, action: \.realms) {
            State.AsyncRealms(compendiumMetadata: compendiumMetadata)
        }
    }
}

struct CompendiumDocumentSelectionView: View {
    let store: StoreOf<CompendiumDocumentSelectionFeature>
    let label: String
    @SwiftUI.Environment(\.isEnabled) var isEnabled

    var body: some View {
        LabeledContent {
            Self.menu(
                store: store,
                label: { name in
                    HStack(spacing: 4) {
                        Text(name)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                    }
                    .fontWeight(.regular)
                    .padding(.trailing, 12)
                }
            )
            .frame(minHeight: 35)
        } label: {
            Text(label)
                .foregroundStyle(isEnabled ? .primary : .secondary)
        }
        .bold()
    }

    public static func menu(
        store: StoreOf<CompendiumDocumentSelectionFeature>,
        label: @escaping (String) -> some View
    ) -> some View {
        MenuContent(store: store, label: label)
    }

    private struct MenuContent<Label: View>: View {
        let store: StoreOf<CompendiumDocumentSelectionFeature>
        let label: (String) -> Label

        var body: some View {
            Menu {
                if let unselectedLabel = store.unselectedLabel {
                    Button(unselectedLabel) {
                        store.send(.clearSource)
                    }
                }

                if let allSources = store.allSources {
                    ForEach(Array(allSources.enumerated()), id: \.offset) { index, source in
                        if CompendiumDocumentSelectionView.needsDividerBefore(source, in: allSources), index > 0 {
                            Divider()
                        }

                        Button(action: {
                            store.send(.source(source.document, source.realm))
                        }) {
                            let sourceValue = CompendiumFilters.Source(realm: source.realm.id, document: source.document.id)
                            if store.selectedSource == sourceValue {
                                SwiftUI.Label(source.document.displayName, systemImage: "checkmark")
                            } else {
                                Text(source.document.displayName)
                            }
                            if source.document.displayName != source.realm.displayName {
                                Text(source.realm.displayName)
                            }
                        }
                        .disabled(store.disabledSources.contains { $0.document == source.document.id && $0.realm == source.realm.id })
                    }
                } else {
                    Text("Loading...")
                }
            } label: {
                if let name = store.selectedSourceDisplayName {
                    label(name)
                }
            }
            .onAppear {
                store.send(.documents(.startLoading))
                store.send(.realms(.startLoading))
            }
        }
    }

    public static func withStore(
        store: StoreOf<CompendiumDocumentSelectionFeature>,
        content: @escaping (StoreOf<CompendiumDocumentSelectionFeature>) -> some View
    ) -> some View {
        WithStoreContent(store: store, content: content)
    }

    private struct WithStoreContent<Content: View>: View {
        let store: StoreOf<CompendiumDocumentSelectionFeature>
        let content: (StoreOf<CompendiumDocumentSelectionFeature>) -> Content

        var body: some View {
            content(store)
                .onAppear {
                    store.send(.documents(.startLoading))
                    store.send(.realms(.startLoading))
                }
        }
    }

    fileprivate static func needsDividerBefore(
        _ source: (document: CompendiumSourceDocument, realm: CompendiumRealm),
        in sources: [(document: CompendiumSourceDocument, realm: CompendiumRealm)]
    ) -> Bool {
        guard let idx = sources.firstIndex(where: { $0.document == source.document }) else {
            return false
        }
        return idx == 0 || sources[idx - 1].realm != source.realm
    }
}

extension CompendiumDocumentSelectionFeature.State {
    public static var nullInstance: Self {
        CompendiumDocumentSelectionFeature.State(
            selectedSource: nil,
            disabledSources: [],
            unselectedLabel: ""
        )
    }
}
