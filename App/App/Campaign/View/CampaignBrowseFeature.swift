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

    struct State: NavigationStackSourceState, Equatable {
        let node: CampaignNode
        var mode: Mode

        typealias AsyncItems = Async<[CampaignNode], EquatableError>
        var items: AsyncItems.State

        let showSettingsButton: Bool

        var sheet: Sheet?

        var presentedScreens: [NavigationDestination: NextScreen]

        init(node: CampaignNode, mode: Mode, items: AsyncItems.State = .initial, showSettingsButton: Bool, sheet: Sheet? = nil, presentedScreens: [NavigationDestination: NextScreen] = [:]) {
            self.node = node
            self.mode = mode
            self.items = items
            self.showSettingsButton = showSettingsButton
            self.sheet = sheet
            self.presentedScreens = presentedScreens
        }

        var localStateForDeduplication: State {
            var res = self
            res.presentedScreens = presentedScreens.mapValues {
                switch $0 {
                case .campaignBrowse: return .campaignBrowse(State.nullInstance)
                case .encounter: return .encounter(EncounterDetailFeature.State.nullInstance)
                }
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

        indirect enum NextScreen: Equatable {
            case campaignBrowse(State)
            case encounter(EncounterDetailFeature.State)
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

    enum Action: NavigationStackSourceAction, Equatable {
        case items(State.AsyncItems.Action)
        case didTapNodeEditDone(State.NodeEditState, CampaignNode?, String)
        case didTapConfirmMoveButton
        case remove(CampaignNode)
        case sheet(State.Sheet?)
        case performMove([CampaignNode], CampaignNode)
        indirect case moveSheet(Action)
        case setNextScreen(State.NextScreen?)
        indirect case nextScreen(NextScreenAction)
        case setDetailScreen(State.NextScreen?)
        indirect case detailScreen(NextScreenAction)

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

        var nextCampaignBrowse: Action? {
            guard case .nextScreen(.campaignBrowse(let a)) = self else { return nil }
            return a
        }

        var nextEncounterDetail: EncounterDetailFeature.Action? {
            guard case .nextScreen(.encounterDetail(let a)) = self else { return nil }
            return a
        }

        var detailEncounterDetail: EncounterDetailFeature.Action? {
            guard case .detailScreen(.encounterDetail(let a)) = self else { return nil }
            return a
        }

        var moveSheet: Action? {
            guard case .moveSheet(let a) = self else { return nil }
            return a
        }

        static func presentScreen(_ destination: NavigationDestination, _ screen: State.NextScreen?) -> Self {
            switch destination {
            case .nextInStack: return .setNextScreen(screen)
            case .detail: return .setDetailScreen(screen)
            }
        }

        static func presentedScreen(_ destination: NavigationDestination, _ action: NextScreenAction) -> Self {
            switch destination {
            case .nextInStack: return .nextScreen(action)
            case .detail: return .detailScreen(action)
            }
        }

        enum NextScreenAction: Equatable {
            case campaignBrowse(Action)
            case encounterDetail(EncounterDetailFeature.Action)
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
            case .setNextScreen(let s):
                state.presentedScreens[.nextInStack] = s
            case .setDetailScreen(let s):
                state.presentedScreens[.detail] = s
            case .nextScreen(.campaignBrowse(.performMove(let items, let destination))):
                // bubble-up
                return .send(.performMove(items, destination))
            case .nextScreen, .detailScreen:
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
        .ifLet(\.presentedNextCampaignBrowse, action: /Action.nextScreen..Action.NextScreenAction.campaignBrowse) {
            CampaignBrowseViewFeature(environment: environment)
        }
        .ifLet(\.presentedNextEncounter, action: /Action.nextScreen..Action.NextScreenAction.encounterDetail) {
            EncounterDetailFeature(environment: environment)
        }
        .ifLet(\.presentedDetailEncounter, action: /Action.detailScreen..Action.NextScreenAction.encounterDetail) {
            EncounterDetailFeature(environment: environment)
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
