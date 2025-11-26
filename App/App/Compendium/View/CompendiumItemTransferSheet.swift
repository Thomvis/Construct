import SwiftUI
import ComposableArchitecture
import Compendium
import GameModels
import Helpers
import Persistence
import SharedViews

/// The UI that enables the user to move/copy compendium items between documents
@Reducer
struct CompendiumItemTransferFeature {
    static let operationEffectId = "CompendiumItemTransferFeature.operationEffectId"

    @ObservableState
    struct State: Equatable {
        let mode: TransferMode
        var conflictResolution: ConflictResolution = .keepBoth

        // The thing that we're moving/copying
        let selection: CompendiumItemSelection
        // If the selection has a single origin document specified, it cannot be selected as the target
        let originDocument: CompendiumFilters.Source?
        var itemCount: Int?

        var documentSelection: CompendiumDocumentSelectionFeature.State

        var operation: Operation?

        var isValid: Bool {
            documentSelection.selectedSource != nil && operation == nil
        }

        init(
            mode: TransferMode,
            selection: CompendiumItemSelection,
            originDocument: CompendiumFilters.Source? = nil
        ) {
            self.mode = mode
            self.selection = selection

            if originDocument == nil {
                switch selection {
                case .multipleFetchRequest(let request):
                    if let source = request.filters?.source {
                        self.originDocument = source
                    } else {
                        self.originDocument = nil
                    }
                case .multipleKeys:
                    // TODO: attempt to determine if all items share a document
                    self.originDocument = nil
                case .single:
                    self.originDocument = originDocument
                }
            } else {
                self.originDocument = originDocument
            }

            self.documentSelection = CompendiumDocumentSelectionFeature.State(
                disabledSources: self.originDocument.nonNilArray,
                unselectedLabel: "Select"
            )
        }

        var notice: Notice? {
            if case .failure(let error) = operation {
                return .error(error, isDismissible: false)
            }
            return nil
        }

        enum Operation: Equatable {
            case pending
            case success
            case failure(String)
        }

        static let nullInstance = State(mode: .copy, selection: .single(CompendiumItemKey(type: .monster, realm: .init(CompendiumRealm.core.id), identifier: "")), originDocument: nil)
    }

    enum Action: BindableAction, Equatable {
        case onAppear
        case onTransferButtonTap
        case onCancelButtonTap
        case documentSelection(CompendiumDocumentSelectionFeature.Action)
        case itemCountResponse(Int)
        case operationDidComplete(State.Operation)
        case onTransferDidSucceed
        case binding(BindingAction<State>)
    }

    @Dependency(\.database) var database
    @Dependency(\.compendiumMetadata) var compendiumMetadata
    @Dependency(\.compendium) var compendium

    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.documentSelection, action: \.documentSelection) {
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
                    case .multipleFetchRequest(let request):
                        count = try compendium.count(request)
                    case .multipleKeys(let keys):
                        count = keys.count
                    }
                    await send(.itemCountResponse(count))
                }

            case .onTransferButtonTap:
                guard state.isValid, let target = state.documentSelection.selectedSource else { return .none }

                state.operation = .pending
                return .run { [state] send in
                    do {
                        try await transfer(
                            state.selection,
                            mode: state.mode,
                            target: target,
                            conflictResolution: state.conflictResolution,
                            db: database.access
                        )
                        await send(.operationDidComplete(.success))
                    } catch {
                        await send(.operationDidComplete(.failure(error.localizedDescription)), animation: .default)
                    }
                }
                .cancellable(id: Self.operationEffectId)
            case .onCancelButtonTap:
                return .cancel(id: Self.operationEffectId)
            case .documentSelection:
                return .none

            case let .itemCountResponse(count):
                state.itemCount = count
                return .none

            case let .operationDidComplete(operation):
                state.operation = operation
                if case .success = operation {
                    return .send(.onTransferDidSucceed)
                }
                return .none

            case .onTransferDidSucceed:
                return .none // for the parent to handle

            case .binding:
                return .none
            }
        }
    }
}

struct CompendiumItemTransferSheet: View {
    @Bindable var store: StoreOf<CompendiumItemTransferFeature>
    @SwiftUI.Environment(\.presentationMode) private var presentationMode
    @SwiftUI.ScaledMetric(relativeTo: .footnote) private var footerHeight = 50

    var body: some View {
        VStack {
            if let notice = store.notice {
                NoticeView(notice: notice)
            }

            SectionContainer {
                CompendiumDocumentSelectionView(
                    store: store.scope(
                        state: \.documentSelection,
                        action: \.documentSelection
                    ),
                    label: "Destination"
                )
            }

            SectionContainer(footer: {
                Text(store.conflictResolution.footerText)
                    .font(.footnote)
                    .foregroundColor(Color.secondary)
                    .padding([.leading, .trailing], 12)
                    .frame(minHeight: footerHeight, alignment: .top)
            }) {
                HStack {
                    Text("Conflict resolution").bold()
                    Spacer()
                    Picker("", selection: $store.conflictResolution.sending(\.binding.conflictResolution)) {
                        ForEach(ConflictResolution.allCases, id: \.self) { strategy in
                            Text(strategy.description).tag(strategy)
                        }
                    }
                }
            }

            Button(action: {
                store.send(.onTransferButtonTap)
            }) {
                switch store.operation {
                case .pending:
                    ProgressView()
                default:
                    Text(store.buttonTitle)
                        .frame(maxWidth: .infinity)

                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
            .disabled(!store.isValid)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    store.send(.onCancelButtonTap)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .navigationTitle(store.mode.actionText)
    }
}

extension TransferMode {
    var actionText: String {
        switch self {
        case .copy: return "Copy"
        case .move: return "Move"
        }
    }
}

extension CompendiumItemTransferFeature.State {
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

public extension ConflictResolution {
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

#if DEBUG
@available(iOS 17.0, *)
struct CompendiumItemTransferSheet_Preview: PreviewProvider {
    static var previews: some View {
        CompendiumItemTransferSheet(
            store: Store(
                initialState: CompendiumItemTransferFeature.State(
                    mode: .copy,
                    selection: .multipleFetchRequest(
                        CompendiumFetchRequest(filters: .init(types: [.monster]))
                    ),
                    originDocument: .init(realm: CompendiumRealm.core.id, document: CompendiumSourceDocument.srd5_1.id)
                )
            ) {
                CompendiumItemTransferFeature()
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
