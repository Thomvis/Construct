import Foundation
import Combine
import SwiftUI
import ComposableArchitecture
import Helpers
import GameModels

@Reducer
struct CampaignBrowseViewFeature {

    @ObservableState
    struct State: Equatable {
        let node: CampaignNode
        var mode: Mode

        typealias AsyncItems = Async<[CampaignNode], EquatableError>
        var items: AsyncItems.State

        let showSettingsButton: Bool

        @Presents var sheet: Sheet.State?

        @Presents var destination: Destination.State?

        init(node: CampaignNode, mode: Mode, items: AsyncItems.State = .initial, showSettingsButton: Bool, sheet: Sheet.State? = nil, destination: Destination.State? = nil) {
            self.node = node
            self.mode = mode
            self.items = items
            self.showSettingsButton = showSettingsButton
            self.sheet = sheet
            self.destination = destination
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

        @ObservableState
        struct NodeEditState: Equatable, Identifiable {
            var id = UUID()
            var name: String = ""
            var contentType: CampaignNode.Contents.ContentType? = nil // non-nil if new non-group node
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

    @CasePathable
    enum Action: Equatable {
        case items(State.AsyncItems.Action)
        case didTapNodeEditDone(State.NodeEditState, CampaignNode?, String)
        case didTapConfirmMoveButton
        case remove(CampaignNode)
        case setSheet(Sheet.State?)
        case performMove([CampaignNode], CampaignNode)
        case setDestination(Destination.State?)
        case didTapNode(CampaignNode)
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

    @Reducer
    enum Destination {
        case campaignBrowse(CampaignBrowseViewFeature)
        case encounter(EncounterDetailFeature)
    }

    @Reducer
    enum Sheet {
        case settings(SettingsFeature)
        case nodeEdit(NodeEditFeature)
        indirect case move(CampaignBrowseViewFeature)
    }

    @Reducer
    struct NodeEditFeature {
        typealias State = CampaignBrowseViewFeature.State.NodeEditState

        enum Action: BindableAction, Equatable {
            case binding(BindingAction<State>)
        }

        var body: some ReducerOf<Self> {
            BindingReducer()
        }
    }

    @Dependency(\.campaignBrowser) var campaignBrowser
    @Dependency(\.crashReporter) var crashReporter
    @Dependency(\.database) var database
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
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
                            try campaignBrowser.move(item, to: destination)
                        } catch {
                            crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                        }
                    }
                    await send(.sheet(.dismiss))
                    await send(.items(.startLoading))
                }
            case .setSheet(let s):
                state.sheet = s
            case .setDestination(let dest):
                state.destination = dest
            case .didTapNode(let node):
                let nextScreen: CampaignBrowseViewFeature.Destination.State
                if let contents = node.contents {
                    switch contents.type {
                    case .encounter:
                        if let encounter: Encounter = try? database.keyValueStore.get(
                            contents.key,
                            crashReporter: crashReporter
                        ) {
                            let runningEncounter: RunningEncounter? = encounter.runningEncounterKey
                                .flatMap { try? database.keyValueStore.get($0, crashReporter: crashReporter) }
                            let detailState = EncounterDetailFeature.State(
                                building: encounter,
                                running: runningEncounter
                            )
                            nextScreen = .encounter(detailState)
                        } else {
                            nextScreen = .encounter(EncounterDetailFeature.State.nullInstance)
                        }
                    case .other:
                        assertionFailure("Other item type is not supported")
                        nextScreen = .encounter(EncounterDetailFeature.State.nullInstance)
                    }
                } else {
                    // group
                    nextScreen = .campaignBrowse(CampaignBrowseViewFeature.State(node: node, mode: state.mode, items: .initial, showSettingsButton: false))
                }
                state.destination = nextScreen
            case .destination(.presented(.campaignBrowse(.performMove(let items, let destination)))):
                // bubble-up
                return .send(.performMove(items, destination))
            case .destination:
                break
            case .didTapNodeEditDone(_, let node?, let title):
                // edit
                return .run { [node] send in
                    // rename content
                    if node.contents?.type == .encounter, let key = node.contents?.key {
                        do {
                            if var encounter: Encounter = try campaignBrowser.store.get(key) {
                                encounter.name = title
                                try campaignBrowser.store.put(encounter)
                            }
                        } catch { assertionFailure("Could not rename encounter") }
                    }

                    var newNode = node
                    newNode.title = title
                    do {
                        try campaignBrowser.put(newNode)
                    } catch {
                        crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
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
                            try campaignBrowser.store.put(encounter)
                        } catch {
                            crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                        }

                        contents = CampaignNode.Contents(key: encounter.key.rawValue, type: .encounter)
                    }

                    do {
                        try campaignBrowser.put(CampaignNode(
                            id: uuid().tagged(),
                            title: title,
                            contents: contents,
                            special: nil,
                            parentKeyPrefix: node.keyPrefixForChildren.rawValue
                        ))
                    } catch {
                        crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                    }
                    await send(.items(.startLoading))
                }
            case .remove(let n):
                return .run { send in
                    do {
                        try campaignBrowser.remove(n)
                    } catch {
                        crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                    }

                    await send(.items(.startLoading))
                }
            case .sheet:
                break
            case .items: break // handled below
            }
            return .none
        }
        WithValue(value: \.node) { node in
            Scope(state: \.items, action: \.items) {
                State.AsyncItems {
                    do {
                        return try campaignBrowser.nodes(in: node)
                    } catch {
                        throw EquatableError(error)
                    }
                }
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$sheet, action: \.sheet)
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

extension CampaignBrowseViewFeature.Destination.State: Equatable {}
extension CampaignBrowseViewFeature.Destination.Action: Equatable {}

extension CampaignBrowseViewFeature.Sheet.State: Equatable {}
extension CampaignBrowseViewFeature.Sheet.Action: Equatable {}
