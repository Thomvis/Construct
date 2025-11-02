//
//  CampaignBrowseViewState.swift
//  Construct
//
//  Created by Thomas Visser on 11/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import ComposableArchitecture
import Helpers
import GameModels

struct CampaignBrowseViewState: NavigationStackSourceState, Equatable {
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

    var localStateForDeduplication: CampaignBrowseViewState {
        var res = self
        res.presentedScreens = presentedScreens.mapValues {
            switch $0 {
            case .campaignBrowse: return .campaignBrowse(CampaignBrowseViewState.nullInstance)
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
        indirect case move(CampaignBrowseViewState)

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
        case campaignBrowse(CampaignBrowseViewState)
        case encounter(EncounterDetailFeature.State)
    }
}

extension CampaignBrowseViewState {
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
}

extension CampaignBrowseViewState: NavigationStackItemState {
    var navigationStackItemStateId: String {
        node.id.rawValue.uuidString
    }

    var navigationTitle: String { navigationBarTitle }
}

enum CampaignBrowseViewAction: NavigationStackSourceAction, Equatable {

    case items(CampaignBrowseViewState.AsyncItems.Action)
    case didTapNodeEditDone(CampaignBrowseViewState.NodeEditState, CampaignNode?, String)
    case didTapConfirmMoveButton
    case remove(CampaignNode)
    case sheet(CampaignBrowseViewState.Sheet?)
    case performMove([CampaignNode], CampaignNode)
    indirect case moveSheet(CampaignBrowseViewAction)
    case setNextScreen(CampaignBrowseViewState.NextScreen?)
    indirect case nextScreen(NextScreenAction)
    case setDetailScreen(CampaignBrowseViewState.NextScreen?)
    indirect case detailScreen(NextScreenAction)

    // Key-path support
    var items: CampaignBrowseViewState.AsyncItems.Action? {
        get {
            guard case .items(let a) = self else { return nil }
            return a
        }
        set {
            guard case .items = self, let value = newValue else { return }
            self = .items(value)
        }
    }

    var nextCampaignBrowse: CampaignBrowseViewAction? {
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

    var moveSheet: CampaignBrowseViewAction? {
        guard case .moveSheet(let a) = self else { return nil }
        return a
    }

    static func presentScreen(_ destination: NavigationDestination, _ screen: CampaignBrowseViewState.NextScreen?) -> Self {
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
        case campaignBrowse(CampaignBrowseViewAction)
        case encounterDetail(EncounterDetailFeature.Action)
    }
}

protocol CampaignBrowseViewNextScreenAction {

}

extension CampaignBrowseViewState {
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

    var moveSheetState: CampaignBrowseViewState? {
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

    static var reducer: AnyReducer<CampaignBrowseViewState, CampaignBrowseViewAction, Environment> {
        return AnyReducer.combine(
            AnyReducer { state, action, env in
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
                                try env.campaignBrowser.move(item, to: destination)
                            } catch {
                                env.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
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
                                if var encounter: Encounter = try env.campaignBrowser.store.get(key) {
                                    encounter.name = title
                                    try env.campaignBrowser.store.put(encounter)
                                }
                            } catch { assertionFailure("Could not rename encounter") }
                        }

                        var newNode = node
                        newNode.title = title
                        do {
                            try env.campaignBrowser.put(newNode)
                        } catch {
                            env.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
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
                                try env.campaignBrowser.store.put(encounter)
                            } catch {
                                env.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                            }

                            contents = CampaignNode.Contents(key: encounter.key.rawValue, type: .encounter)
                        }

                        do {
                            try env.campaignBrowser.put(CampaignNode(
                                id: UUID().tagged(),
                                title: title,
                                contents: contents,
                                special: nil,
                                parentKeyPrefix: node.keyPrefixForChildren.rawValue
                            ))
                        } catch {
                            env.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                        }
                        await send(.items(.startLoading))
                    }
                case .remove(let n):
                    return .run { send in
                        do {
                            try env.campaignBrowser.remove(n)
                        } catch {
                            env.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                        }

                        await send(.items(.startLoading))
                    }
                case .items: break // handled below
                }
                return .none
            },
            AnyReducer { env in
                WithValue(value: \.node) { node in
                    Scope(state: \.items, action: /CampaignBrowseViewAction.items) {
                        CampaignBrowseViewState.AsyncItems {
                            do {
                                return try env.campaignBrowser.nodes(in: node)
                            } catch {
                                throw EquatableError(error)
                            }
                        }
                    }
                }
            },
            AnyReducer { env in
                Reduce(CampaignBrowseViewState.reducer, environment: env)
            }
            .optional().pullback(state: \.presentedNextCampaignBrowse, action: CasePath(embed: { CampaignBrowseViewAction.nextScreen(.campaignBrowse($0)) }, extract: { $0.nextCampaignBrowse })),
            AnyReducer { env in
                EncounterDetailFeature(environment: env)
            }
            .optional().pullback(state: \.presentedNextEncounter, action: CasePath(embed: { CampaignBrowseViewAction.nextScreen(.encounterDetail($0)) }, extract: { $0.nextEncounterDetail })),
            AnyReducer { env in
                EncounterDetailFeature(environment: env)
            }
            .optional().pullback(state: \.presentedDetailEncounter, action: CasePath(embed: { CampaignBrowseViewAction.detailScreen(.encounterDetail($0)) }, extract: { $0.detailEncounterDetail })),
            AnyReducer { env in
                Reduce(CampaignBrowseViewState.reducer, environment: env)
            }
            .optional().pullback(state: \.moveSheetState, action: CasePath(embed: { CampaignBrowseViewAction.moveSheet($0) }, extract: { $0.moveSheet }))
        )
    }
}

extension CampaignBrowseViewState {
    static let nullInstance = CampaignBrowseViewState(node: CampaignNode.root, mode: .browse, showSettingsButton: false)
}

extension CampaignBrowseViewState.NodeEditState {
    static let nullInstance = CampaignBrowseViewState.NodeEditState(name: "")
}
