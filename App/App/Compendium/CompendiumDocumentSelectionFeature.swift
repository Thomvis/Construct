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
            guard let s = selectedSource else { return nil }
            return documents.value?.first(where: { $0.realmId == s.realm && $0.id == s.document })
        }
        
        var allSources: [(document: CompendiumSourceDocument, realm: CompendiumRealm)]? {
            guard let documents = documents.value, let realms = realms.value else {
                return nil
            }
            
            return documents.compactMap { d in
                realms.first(where: { $0.id == d.realmId }).map { r in
                    (document: d, realm: r)
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
            disabledSources: [CompendiumFilters.Source] = [],
        ) {
            self.selectedSource = selectedSource
            self.disabledSources = disabledSources
            self.unselectedLabel = nil
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
                state.selectedSource = .init(realm: realm.id, document: document.id)
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
                    ForEach(Array(allSources.enumerated()), id: \.element.document.id) { index, source in
                        // Add divider between realms
                        if CompendiumDocumentSelectionView.needsDividerBefore(source, in: allSources) {
                            Divider()
                        }

                        Button(action: {
                            store.send(.source(source.document, source.realm))
                        }) {
                            if let s = store.selectedSource, s.document == source.document.id && s.realm == source.realm.id {
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
                if let name = store.currentDocument.map({ $0.displayName }) ?? store.unselectedLabel {
                    label(name)
                }
            }
            .onAppear {
                store.send(.documents(.startLoading))
                store.send(.realms(.startLoading))
            }
        }
    }

    // Wraps some view so it can access our state
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
        return idx == 0 || sources[idx-1].realm != source.realm
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
