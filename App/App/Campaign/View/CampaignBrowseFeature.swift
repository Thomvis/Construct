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

        var sheet: Sheet?

        @PresentationState var destination: Destination.State?

        init(node: CampaignNode, mode: Mode, items: AsyncItems.State = .initial, showSettingsButton: Bool, sheet: Sheet? = nil, destination: Destination.State? = nil) {
            self.node = node
            self.mode = mode
            self.items = items
            self.showSettingsButton = showSettingsButton
            self.sheet = sheet
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

        enum Sheet: Equatable, Identifiable {
            case settings
            case nodeEdit(NodeEditState)
            indirect case move(State)

            var id: String {
                switch self {
                case .settings: return "settings"
                case .nodeEdit(let s): return s.id.uuidString
                case .move: return "move"
                }
            }
        }

        struct NodeEditState: Equatable, Identifiable {
            var id = UUID()
            var name: String
            var contentType: CampaignNode.Contents.ContentType? // non-nil if new non-group node
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

        var nodeEditState: NodeEditState? {
            get {
                guard case .nodeEdit(let s)? = sheet else { return nil }
                return s
            }
            set {
                if let newValue = newValue {
                    sheet = .nodeEdit(newValue)
                }
            }
        }

        var moveSheetState: State? {
            get {
                guard case .move(let s)? = sheet else { return nil }
                return s
            }
            set {
                if let newValue = newValue {
                    sheet = .move(newValue)
                }
            }
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
        case sheet(State.Sheet?)
        case performMove([CampaignNode], CampaignNode)
        indirect case moveSheet(Action)
        case setDestination(Destination.State?)
        case destination(PresentationAction<Destination.Action>)

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

        var moveSheet: Action? {
            guard case .moveSheet(let a) = self else { return nil }
            return a
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
            case .moveSheet(.performMove(let items, let destination)):
                return .run { send in
                    // perform move
                    for item in items {
                        do {
                            try environment.campaignBrowser.move(item, to: destination)
                        } catch {
                            environment.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                        }
                    }

                    await send(.sheet(nil))
                    await send(.items(.startLoading))
                }
            case .moveSheet:
                break
            case .sheet(let s):
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
        .ifLet(\.moveSheetState, action: /Action.moveSheet) {
            CampaignBrowseViewFeature(environment: environment)
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
