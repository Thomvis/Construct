import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels
import Compendium
import Helpers

struct CompendiumDocumentSelectionFeature: ReducerProtocol {
    struct State: Equatable {

        let unselectedLabel: String
        let disabledSources: [CompendiumFilters.Source]

        var documents: Async<[CompendiumSourceDocument], Error> = .initial
        var realms: Async<[CompendiumRealm], Error> = .initial
        
        @BindingState var selectedSource: CompendiumFilters.Source?
        
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
    }
    
    enum Action: BindableAction, Equatable {
        case onAppear
        case source(CompendiumSourceDocument, CompendiumRealm)
        case clearSource
        case documents(Async<[CompendiumSourceDocument], Error>.Action)
        case realms(Async<[CompendiumRealm], Error>.Action)
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.compendiumMetadata) var compendiumMetadata

    private struct AsyncDocumentsAndRealmsEnvironment: EnvironmentWithCompendiumMetadata {
        var compendiumMetadata: CompendiumMetadata
    }

    var body: some ReducerProtocolOf<Self> {
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

        Scope(state: \.documents, action: /Action.documents) {
            Reduce(
                Async<[CompendiumSourceDocument], Swift.Error>.reducer(),
                environment: AsyncDocumentsAndRealmsEnvironment(compendiumMetadata: compendiumMetadata)
            )
        }

        Scope(state: \.realms, action: /Action.realms) {
            Reduce(
                Async<[CompendiumRealm], Swift.Error>.reducer(),
                environment: AsyncDocumentsAndRealmsEnvironment(compendiumMetadata: compendiumMetadata)
            )
        }
    }
}

struct CompendiumDocumentSelectionView: View {
    let store: StoreOf<CompendiumDocumentSelectionFeature>
    @SwiftUI.Environment(\.isEnabled) var isEnabled

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            LabeledContent {
                Menu {
                    Button(viewStore.unselectedLabel) {
                        viewStore.send(.clearSource)
                    }

                    if let allSources = viewStore.allSources {
                        ForEach(allSources, id: \.document.id) { source in
                            // Add divider between realms
                            if needsDividerBefore(source, in: allSources) {
                                Divider()
                            }

                            Button(action: {
                                viewStore.send(.source(source.document, source.realm))
                            }) {
                                if let s = viewStore.selectedSource, s.document == source.document.id && s.realm == source.realm.id {
                                    Label(source.document.displayName, systemImage: "checkmark")
                                } else {
                                    Text(source.document.displayName)
                                }
                                if source.document.displayName != source.realm.displayName {
                                    Text(source.realm.displayName)
                                }
                            }
                            .disabled(viewStore.state.disabledSources.contains { $0.document == source.document.id && $0.realm == source.realm.id })                        }
                    } else {
                        Text("Loading...")
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let doc = viewStore.currentDocument {
                            Text(doc.displayName)
                        } else {
                            Text(viewStore.unselectedLabel)
                        }

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                    }
                    .fontWeight(.regular)
                    .padding(.trailing, 12)
                }
                .frame(minHeight: 35)
            } label: {
                Text("Sources")
                    .foregroundStyle(isEnabled ? .primary : .secondary)
            }
            .bold()
            .onAppear {
                viewStore.send(.documents(.startLoading))
                viewStore.send(.realms(.startLoading))
            }
        }
    }
    
    private func needsDividerBefore(
        _ source: (document: CompendiumSourceDocument, realm: CompendiumRealm),
        in sources: [(document: CompendiumSourceDocument, realm: CompendiumRealm)]
    ) -> Bool {
        guard let idx = sources.firstIndex(where: { $0.document == source.document }) else {
            return false
        }
        return idx == 0 || sources[idx-1].realm != source.realm
    }
} 
