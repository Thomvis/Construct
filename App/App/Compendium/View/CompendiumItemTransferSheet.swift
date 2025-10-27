import SwiftUI
import ComposableArchitecture
import Compendium
import GameModels
import Helpers
import Persistence
import SharedViews

/// The UI that enables the user to move/copy compendium items between documents
struct CompendiumItemTransferFeature: ReducerProtocol {
    static let operationEffectId = "CompendiumItemTransferFeature.operationEffectId"

    struct State: Equatable {
        let mode: TransferMode
        @BindingState var conflictResolution: ConflictResolution = .keepBoth

        // The thing that we're moving/copying
        let selection: CompendiumItemSelection
        // If the selection has a single origin document specified, it cannot be selected as the target
        let originDocument: CompendiumFilters.Source?
        var itemCount: Int?

        var documentSelection: CompendiumDocumentSelectionFeature.State

        @BindingState var operation: Operation?

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
                case .multipleKeys(let keys):
                    // If all keys share the same origin document, disable selecting it as target
                    if let first = keys.first {
                        let realm = first.realm
                        let doc = first.identifier.split(separator: ":").first
                        // Don't rely on identifier parsing; attempt via compendium metadata in onAppear
                        // Here, we leave it nil; onAppear will not depend on originDocument.
                        self.originDocument = nil
                    } else {
                        self.originDocument = nil
                    }
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
        case onTransferDidSucceed
        case binding(BindingAction<State>)
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
                    case .multipleFetchRequest(let request):
                        count = try compendium.count(request)
                    case .multipleKeys(let keys):
                        count = keys.count
                    }
                    await send(.itemCountResponse(count))
                }

            case .onTransferButtonTap:
                guard state.isValid, let target = state.documentSelection.selectedSource else { return .none }

                return .run { [state] send in

                    await send(.set(\.$operation, .pending))
                    do {
                        try await transfer(
                            state.selection,
                            mode: state.mode,
                            target: target,
                            conflictResolution: state.conflictResolution,
                            db: database.access
                        )
                        await send(.set(\.$operation, .success))
                        await send(.onTransferDidSucceed)
                    } catch {
                        await send(.set(\.$operation, .failure(error.localizedDescription)), animation: .default)
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

            case .onTransferDidSucceed:
                return .none // for the parent to handle

            case .binding:
                return .none
            }
        }
    }
}

struct CompendiumItemTransferSheet: View {
    let store: StoreOf<CompendiumItemTransferFeature>
    @SwiftUI.Environment(\.presentationMode) private var presentationMode
    @SwiftUI.ScaledMetric(relativeTo: .footnote) private var footerHeight = 50

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            VStack {
                if let notice = viewStore.state.notice {
                    NoticeView(notice: notice)
                }

                SectionContainer {
                    CompendiumDocumentSelectionView(
                        store: store.scope(
                            state: \.documentSelection,
                            action: CompendiumItemTransferFeature.Action.documentSelection
                        ),
                        label: "Destination"
                    )
                }

                SectionContainer(footer: {
                    Text(viewStore.conflictResolution.footerText)
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                        .padding([.leading, .trailing], 12)
                        .frame(minHeight: footerHeight, alignment: .top)
                }) {
                    HStack {
                        Text("Conflict resolution").bold()
                        Spacer()
                        Picker("", selection: viewStore.$conflictResolution) {
                            ForEach(ConflictResolution.allCases, id: \.self) { strategy in
                                Text(strategy.description).tag(strategy)
                            }
                        }
                    }
                }

                Button(action: {
                    viewStore.send(.onTransferButtonTap)
                }) {
                    switch viewStore.state.operation {
                    case .pending:
                        ProgressView()
                    default:
                        Text(viewStore.buttonTitle)
                            .frame(maxWidth: .infinity)

                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
                .disabled(!viewStore.isValid)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewStore.send(.onCancelButtonTap)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .navigationTitle(viewStore.state.mode.actionText)
        }
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
