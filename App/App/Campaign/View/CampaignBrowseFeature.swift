import Foundation
import Combine
import SwiftUI
import ComposableArchitecture
import Helpers
import GameModels

struct CampaignBrowseViewFeature: Reducer {
    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    struct State: Equatable {
        let node: CampaignNode
        var mode: Mode

        typealias AsyncItems = Async<[CampaignNode], EquatableError>
        var items: AsyncItems.State

        let showSettingsButton: Bool

        @PresentationState var sheet: Sheet.State?

        @PresentationState var destination: Destination.State?

        init(node: CampaignNode, mode: Mode, items: AsyncItems.State = .initial, showSettingsButton: Bool, sheet: Sheet.State? = nil, destination: Destination.State? = nil) {
            self.node = node
            self.mode = mode
            self.items = items
            self.showSettingsButton = showSettingsButton
            self._sheet = PresentationState(wrappedValue: sheet)
            self._destination = PresentationState(wrappedValue: destination)
        }

        var localStateForDeduplication: State {
            var res = self
            if let destination {
                res.destination = destination.nullInstance
            }
            return res
        }

        enum Mode: Equatable {
            case browse
            case move([CampaignNode])
        }

        struct NodeEditState: Equatable, Identifiable {
            var id = UUID()
            @BindingState var name: String = ""
            @BindingState var contentType: CampaignNode.Contents.ContentType? = nil // non-nil if new non-group node
            var node: CampaignNode? // nil if new node
        }

        var navigationBarTitle: String {
            if node.id == CampaignNode.root.id {
                return NSLocalizedString("Adventure", comment: "Title of the campaign browser")
            }
            return node.title
        }

        var sortedItems: [CampaignNode]? {
            items.value?.sorted { $0.title < $1.title }
        }

        func isItemDisabled(_ item: CampaignNode) -> Bool {
            if case .move = mode {
                return item.contents != nil
            }
            return false
        }

        var isMoveMode: Bool {
            if case .move = mode {
                return true
            }
            return false
        }

        var isMoveOrigin: Bool {
            guard case .move(let nodes) = mode, let node = nodes.first else { return false }
            return node.parentKeyPrefix == self.node.keyPrefixForChildren.rawValue
        }

        func isBeingMoved(_ node: CampaignNode) -> Bool {
            guard case .move(let nodes) = mode else { return false }
            return nodes.contains { $0.id == node.id }
        }

        var movingNodesDescription: String? {
            guard case .move(let nodes) = mode else { return nil }
            return ListFormatter().string(for: nodes.map { "“\($0.title)”" })
        }

        static let nullInstance = State(node: CampaignNode.root, mode: .browse, showSettingsButton: false)
    }

    enum Action: Equatable {
        case items(State.AsyncItems.Action)
        case didTapNodeEditDone(State.NodeEditState, CampaignNode?, String)
        case didTapConfirmMoveButton
        case remove(CampaignNode)
        case setSheet(Sheet.State?)
        case performMove([CampaignNode], CampaignNode)
        case setDestination(Destination.State?)
        case destination(PresentationAction<Destination.Action>)
        case sheet(PresentationAction<Sheet.Action>)

        // Key-path support
        var items: State.AsyncItems.Action? {
            get {
                guard case .items(let a) = self else { return nil }
                return a
            }
            set {
                guard case .items = self, let value = newValue else { return }
                self = .items(value)
            }
        }

    }

    struct Destination: Reducer {
        let environment: Environment

        enum State: Equatable {
            case campaignBrowse(CampaignBrowseViewFeature.State)
            case encounter(EncounterDetailFeature.State)
        }

        enum Action: Equatable {
            case campaignBrowse(CampaignBrowseViewFeature.Action)
            case encounterDetail(EncounterDetailFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.campaignBrowse, action: /Action.campaignBrowse) {
                CampaignBrowseViewFeature(environment: environment)
            }
            Scope(state: /State.encounter, action: /Action.encounterDetail) {
                EncounterDetailFeature(environment: environment)
            }
        }
    }

    struct Sheet: Reducer {
        let environment: Environment

        enum State: Equatable {
            case settings
            case nodeEdit(CampaignBrowseViewFeature.State.NodeEditState)
            indirect case move(CampaignBrowseViewFeature.State)
        }

        enum Action: Equatable {
            case settings(Never)
            case nodeEdit(CampaignBrowseViewFeature.NodeEdit.Action)
            case move(CampaignBrowseViewFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.nodeEdit, action: /Action.nodeEdit) {
                CampaignBrowseViewFeature.NodeEdit()
            }
            Scope(state: /State.move, action: /Action.move) {
                CampaignBrowseViewFeature(environment: environment)
            }
        }
    }

    struct NodeEdit: Reducer {
        typealias State = CampaignBrowseViewFeature.State.NodeEditState

        enum Action: BindableAction, Equatable {
            case binding(BindingAction<State>)
        }

        var body: some ReducerOf<Self> {
            BindingReducer()
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            let node = state.node
            switch action {
            case .didTapConfirmMoveButton:
                let s = state

                if case .move(let nodes) = s.mode {
                    return .send(.performMove(nodes, s.node))
                }
            case .performMove: // will bubble up below
                break
            case .sheet(.presented(.move(.performMove(let items, let destination)))):
                return .run { send in
                    // perform move
                    for item in items {
                        do {
                            try environment.campaignBrowser.move(item, to: destination)
                        } catch {
                            environment.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                        }
                    }
                    await send(.sheet(.dismiss))
                    await send(.items(.startLoading))
                }
            case .sheet(.presented(.move)):
                break
            case .setSheet(let s):
                state.sheet = s
            case .setDestination(let destination):
                state.destination = destination
            case .destination(.presented(.campaignBrowse(.performMove(let items, let destination)))):
                // bubble-up
                return .send(.performMove(items, destination))
            case .destination(.dismiss):
                state.destination = nil
            case .destination:
                break
            case .didTapNodeEditDone(_, let node?, let title):
                // edit
                return .run { [node] send in
                    // rename content
                    if node.contents?.type == .encounter, let key = node.contents?.key {
                        do {
                            if var encounter: Encounter = try environment.campaignBrowser.store.get(key) {
                                encounter.name = title
                                try environment.campaignBrowser.store.put(encounter)
                            }
                        } catch { assertionFailure("Could not rename encounter") }
                    }

                    var newNode = node
                    newNode.title = title
                    do {
                        try environment.campaignBrowser.put(newNode)
                    } catch {
                        environment.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                    }
                    await send(.items(.startLoading))
                }
            case .didTapNodeEditDone(let state, nil, let title):
                // new
                return .run { send in
                    var contents: CampaignNode.Contents? = nil
                    if state.contentType == .encounter {
                        let encounter = Encounter(name: title, combatants: [])
                        do {
                            try environment.campaignBrowser.store.put(encounter)
                        } catch {
                            environment.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                        }

                        contents = CampaignNode.Contents(key: encounter.key.rawValue, type: .encounter)
                    }

                    do {
                        try environment.campaignBrowser.put(CampaignNode(
                            id: UUID().tagged(),
                            title: title,
                            contents: contents,
                            special: nil,
                            parentKeyPrefix: node.keyPrefixForChildren.rawValue
                        ))
                    } catch {
                        environment.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                    }
                    await send(.items(.startLoading))
                }
            case .remove(let n):
                return .run { send in
                    do {
                        try environment.campaignBrowser.remove(n)
                    } catch {
                        environment.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                    }

                    await send(.items(.startLoading))
                }
            case .sheet(.dismiss):
                state.sheet = nil
            case .sheet:
                break
            case .items: break // handled below
            }
            return .none
        }
        WithValue(value: \.node) { node in
            Scope(state: \.items, action: /Action.items) {
                State.AsyncItems {
                    do {
                        return try environment.campaignBrowser.nodes(in: node)
                    } catch {
                        throw EquatableError(error)
                    }
                }
            }
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination(environment: environment)
        }
        .ifLet(\.$sheet, action: /Action.sheet) {
            Sheet(environment: environment)
        }
    }
}

extension CampaignBrowseViewFeature.State: NavigationStackItemState {
    var navigationStackItemStateId: String {
        node.id.rawValue.uuidString
    }

    var navigationTitle: String { navigationBarTitle }
}

extension CampaignBrowseViewFeature.State.NodeEditState {
    static let nullInstance = CampaignBrowseViewFeature.State.NodeEditState(name: "")
}

extension CampaignBrowseViewFeature.State: DestinationTreeNode {}

extension CampaignBrowseViewFeature.Destination.State {
    var nullInstance: CampaignBrowseViewFeature.Destination.State {
        switch self {
        case .campaignBrowse:
            return .campaignBrowse(CampaignBrowseViewFeature.State.nullInstance)
        case .encounter:
            return .encounter(EncounterDetailFeature.State.nullInstance)
        }
    }
}

extension CampaignBrowseViewFeature.Destination.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        switch self {
        case .campaignBrowse(let state):
            return state.navigationNodes
        case .encounter(let state):
            return state.navigationNodes
        }
    }
}
