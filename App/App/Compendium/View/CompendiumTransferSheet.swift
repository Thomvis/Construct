//
//  CompendiumTransferSheet.swift
//  Construct
//
//  Created by Thomas Visser on 18/01/2025.
//  Copyright © 2025 Thomas Visser. All rights reserved.
//
import SwiftUI
import ComposableArchitecture
import Compendium
import GameModels
import Helpers

struct CompendiumTransferFeature: ReducerProtocol {
    enum Mode: Int {
        case copy = 0
        case move = 1
    }

    enum ConflictResolution: Equatable, CaseIterable {
        case skip
        case overwrite
        case keepBoth

        var description: String {
            switch self {
            case .skip: return "Skip"
            case .overwrite: return "Overwrite"
            case .keepBoth: return "Keep both"
            }
        }

        var footerText: String {
            switch self {
            case .skip: return "Existing items with the same name will not be moved/copied."
            case .overwrite: return "Existing items with the same name will be overwritten."
            case .keepBoth: return "Both existing and new items will be kept, with a suffix added to distinguish them."
            }
        }
    }

    // The thing that we're moving/copying
    enum Selection: Equatable {
        case single(CompendiumItemKey)
        case multiple(CompendiumFetchRequest)
    }

    struct State: Equatable {
        @BindingState var mode: Mode = .copy
        @BindingState var conflictResolution: ConflictResolution = .keepBoth

        let selection: Selection
        // If the selection has a single origin document specified, it cannot be selected as the target
        let originDocument: CompendiumFilters.Source?
        var itemCount: Int?

        var documentSelection: CompendiumDocumentSelectionFeature.State

        var isValid: Bool {
            documentSelection.selectedSource != nil
        }

        init(selection: Selection, originDocument: CompendiumFilters.Source? = nil) {
            self.selection = selection

            if originDocument == nil, case .multiple(let request) = selection, let source = request.filters?.source {
                self.originDocument = source
            } else {
                self.originDocument = originDocument
            }

            self.documentSelection = CompendiumDocumentSelectionFeature.State(
                disabledSources: self.originDocument.nonNilArray,
                unselectedLabel: "Select"
            )
        }

        static let nullInstance = State(selection: .single(CompendiumItemKey(type: .monster, realm: .init(CompendiumRealm.core.id), identifier: "")), originDocument: nil)
    }

    enum Action: BindableAction, Equatable {
        case onAppear
        case onCancelButtonTap
        case onMoveButtonTap
        case documentSelection(CompendiumDocumentSelectionFeature.Action)
        case itemCountResponse(Int)
        case binding(BindingAction<State>)
        case didFinish
    }

    @Dependency(\.database) var database
    @Dependency(\.compendiumMetadata) var compendiumMetadata
    @Dependency(\.compendium) var compendium

    var body: some ReducerProtocolOf<Self> {
        BindingReducer()

        Scope(state: \.documentSelection, action: /Action.documentSelection) {
            CompendiumDocumentSelectionFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [selection = state.selection] send in
                    let count: Int
                    switch selection {
                    case .single:
                        count = 1
                    case .multiple(let request):
                        count = try compendium.count(request)
                    }
                    await send(.itemCountResponse(count))
                }

            case .onCancelButtonTap:
                // We'll handle this in the view using SwiftUI's built-in dismissal
                return .none

            case .onMoveButtonTap:
                guard state.isValid else { return .none }

                database.queue.inTransaction { db in
                    
                }

                // TODO: Implement move/copy logic
                return .send(.didFinish)

            case .documentSelection:
                return .none

            case let .itemCountResponse(count):
                state.itemCount = count
                return .none

            case .didFinish: // handled by parent
                return .none

            case .binding:
                return .none
            }
        }
    }
}

struct CompendiumTransferSheet: View {
    let store: StoreOf<CompendiumTransferFeature>
    @SwiftUI.Environment(\.presentationMode) private var presentationMode

    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                Picker(selection: viewStore.binding(\.$mode)) {
                    Text("Copy").tag(CompendiumTransferFeature.Mode.copy)
                    Text("Move").tag(CompendiumTransferFeature.Mode.move)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)

                SectionContainer {
                    CompendiumDocumentSelectionView(
                        store: store.scope(
                            state: \.documentSelection,
                            action: CompendiumTransferFeature.Action.documentSelection
                        )
                    )
                }

                SectionContainer(footer: {
                    Text(viewStore.conflictResolution.footerText)
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                        .padding([.leading, .trailing], 12)
                }) {
                    HStack {
                        Text("Conflicts").bold()
                        Spacer()
                        Picker("", selection: viewStore.binding(\.$conflictResolution)) {
                            ForEach(CompendiumTransferFeature.ConflictResolution.allCases, id: \.self) { strategy in
                                Text(strategy.description).tag(strategy)
                            }
                        }
                    }
                }

                Button(action: {
                    viewStore.send(.onMoveButtonTap)
                }) {
                    Text(viewStore.buttonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
                .disabled(!viewStore.isValid)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

extension CompendiumTransferFeature.Mode {
    var actionText: String {
        switch self {
        case .copy: return "Copy"
        case .move: return "Move"
        }
    }
}

extension CompendiumTransferFeature.State {
    var buttonTitle: String {
        if let count = itemCount {
            if count == 1 {
                return "\(mode.actionText) 1 item"
            } else {
                return "\(mode.actionText) \(count) items"
            }
        }
        return "\(mode.actionText) items"
    }
}

#if DEBUG
@available(iOS 17.0, *)
struct CompendiumTransferSheet_Preview: PreviewProvider {
    static var previews: some View {
        CompendiumTransferSheet(
            store: Store(
                initialState: CompendiumTransferFeature.State(
                    selection: .multiple(
                        CompendiumFetchRequest(filters: .init(types: [.monster]))
                    ),
                    originDocument: .init(realm: CompendiumRealm.core.id, document: CompendiumSourceDocument.srd5_1.id)
                )
            ) {
                CompendiumTransferFeature()
            }
        )
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
#endif
