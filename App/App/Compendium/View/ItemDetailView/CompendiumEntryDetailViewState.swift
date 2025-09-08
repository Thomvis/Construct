//
//  CompendiumItemDetailViewState.swift
//  Construct
//
//  Created by Thomas Visser on 29/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Combine
import CasePaths
import Helpers
import DiceRollerFeature
import GameModels
import ActionResolutionFeature
import Persistence
import Compendium

typealias CompendiumEntryDetailEnvironment = EnvironmentWithDatabase & EnvironmentWithCompendium & EnvironmentWithCompendiumMetadata
    & EnvironmentWithCrashReporter & CreatureEditViewEnvironment & ActionResolutionEnvironment

struct CompendiumEntryDetailViewState: NavigationStackSourceState, Equatable {

    var entry: CompendiumEntry
    var popover: Popover?
    var sheet: Sheet?

    var presentedScreens: [NavigationDestination: NextScreen] = [:]
    var itemRequest: ReferenceViewItemRequest?

    init(entry: CompendiumEntry) {
        self.entry = entry
    }

    var item: CompendiumItem {
        entry.item
    }

    var entryAttribution: AttributedString? {
        if var result = entry.attribution {
            StatBlockView.process(attributedString: &result)
            return result
        }
        return nil
    }

    var navigationStackItemStateId: String { entry.item.compendiumItemDetailViewStateId }

    var navigationTitle: String { item.title }
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { .inline }

    var createActionPopover: ActionResolutionViewState? {
        get {
            if case .creatureAction(let s) = popover {
                return s
            }
            return nil
        }
        set {
            if let newValue = newValue {
                popover = .creatureAction(newValue)
            }
        }
    }

    var rollCheckPopover: DiceCalculatorState? {
        get {
            if case .rollCheck(let s) = popover {
                return s
            }
            return nil
        }
        set {
            if let newValue = newValue {
                popover = .rollCheck(newValue)
            }
        }
    }

    var creatureEditSheet: CreatureEditViewState? {
        get {
            if case .creatureEdit(let s) = sheet {
                return s
            }
            return nil
        }
        set {
            if let newValue = newValue {
                sheet = .creatureEdit(newValue)
            }
        }
    }

    var groupEditSheet: CompendiumItemGroupEditState? {
        get {
            if case .groupEdit(let s) = sheet {
                return s
            }
            return nil
        }
        set {
            if let newValue = newValue {
                sheet = .groupEdit(newValue)
            }
        }
    }

    var transferSheet: CompendiumItemTransferFeature.State? {
        get {
            if case .transfer(let s) = sheet {
                return s
            }
            return nil
        }
        set {
            if let newValue = newValue {
                sheet = .transfer(newValue)
            }
        }
    }

    var localStateForDeduplication: Self {
        var res = self
        res.popover = popover.map {
            switch $0 {
            case .creatureAction: return .creatureAction(.nullInstance)
            case .rollCheck: return .rollCheck(.nullInstance)
            }
        }
        res.sheet = sheet.map {
            switch $0 {
            case .creatureEdit: return .creatureEdit(.nullInstance)
            case .groupEdit: return .groupEdit(.nullInstance)
            case .transfer: return .transfer(.nullInstance)
            }
        }
        res.presentedScreens = presentedScreens.mapValues {
            switch $0 {
            case .compendiumItemDetailView: return .compendiumItemDetailView(.nullInstance)
            case .safariView: return .safariView(.nullInstance)
            }
        }
        return self
    }

    enum Popover: Equatable, Identifiable {
        case creatureAction(ActionResolutionViewState)
        case rollCheck(DiceCalculatorState)

        var id: String {
            switch self {
            case .creatureAction: return "creatureAction"
            case .rollCheck: return "rollCheck"
            }
        }
    }

    enum Sheet: Equatable, Identifiable {
        case creatureEdit(CreatureEditViewState)
        case groupEdit(CompendiumItemGroupEditState)
        case transfer(CompendiumItemTransferFeature.State)

        var id: String {
            switch self {
            case .creatureEdit(let s): return s.navigationStackItemStateId
            case .groupEdit(let s): return s.navigationStackItemStateId
            case .transfer: return "move"
            }
        }
    }

    enum NextScreen: Equatable {
        case compendiumItemDetailView(CompendiumEntryDetailViewState)
        case safariView(SafariViewState)
    }

    static var reducer: AnyReducer<Self, CompendiumItemDetailViewAction, CompendiumEntryDetailEnvironment> {
        return AnyReducer.combine(
            CreatureEditViewState.reducer.optional().pullback(state: \.creatureEditSheet, action: /CompendiumItemDetailViewAction.sheet..CompendiumItemDetailViewAction.SheetAction.creatureEdit, environment: { $0 }),
            CompendiumItemGroupEditState.reducer.optional().pullback(state: \.groupEditSheet, action: /CompendiumItemDetailViewAction.sheet..CompendiumItemDetailViewAction.SheetAction.groupEdit, environment: { $0 }),
            AnyReducer { env in
                CompendiumItemTransferFeature()
                    .dependency(\.compendiumMetadata, env.compendiumMetadata)
            }
            .optional().pullback(state: \.transferSheet, action: /CompendiumItemDetailViewAction.sheet..CompendiumItemDetailViewAction.SheetAction.transfer),
            ActionResolutionViewState.reducer.optional().pullback(state: \.createActionPopover, action: /CompendiumItemDetailViewAction.creatureActionPopover, environment: { $0 }),
            DiceCalculatorState.reducer.optional().pullback(state: \.rollCheckPopover, action: /CompendiumItemDetailViewAction.rollCheckPopover, environment: { $0 }),
            AnyReducer.lazy(CompendiumEntryDetailViewState.reducer).optional().pullback(state: \.presentedNextCompendiumItemDetailView, action: /CompendiumItemDetailViewAction.nextScreen..CompendiumItemDetailViewAction.NextScreenAction.compendiumItemDetailView),
            CompendiumItemReferenceTextAnnotation.handleTapReducer(
                didTapAction: /CompendiumItemDetailViewAction.didTapCompendiumItemReferenceTextAnnotation,
                requestItem: \.itemRequest,
                internalAction: /CompendiumItemDetailViewAction.setNextScreen..Self.NextScreen.compendiumItemDetailView,
                externalAction: /CompendiumItemDetailViewAction.setNextScreen..Self.NextScreen.safariView,
                environment: { $0 }
            ),
            AnyReducer { state, action, env in
                switch action {
                case .onAppear:
                    if let group = state.entry.item as? CompendiumItemGroup {
                        let entry = state.entry
                        // refresh group members
                        return .run { [group, entry] send in
                            do {
                                let characters = try group.members.compactMap { member -> Character? in
                                    let item = try env.database.keyValueStore.get(
                                        member.itemKey,
                                        crashReporter: env.crashReporter
                                    )?.item
                                    return item as? Character
                                }

                                var newGroup = group
                                if newGroup.updateMemberReferences(with: characters) {
                                    var newEntry = entry
                                    newEntry.item = newGroup
                                    try env.database.keyValueStore.put(newEntry)
                                    await send(.entry(newEntry))
                                }
                            } catch {
                                // failed
                            }
                        }
                    }
                case .entry(let e): state.entry = e
                case .onSaveMonsterAsNPCButton: break // handled by the compendium container
                case .didTapCompendiumItemReferenceTextAnnotation: break // handled above
                case .popover(let p): state.popover = p
                case .creatureActionPopover: break // handled by a reducer above
                case .rollCheckPopover: break // handled by a reducer above
                case .setSheet(let s): state.sheet = s
                case .sheet(.creatureEdit(CreatureEditViewAction.didEdit(let result))):
                    if case let .compendium(entry) = result {
                        state.entry = entry
                        return .send(.setSheet(nil))
                    }
                    return .send(.setSheet(nil))
                case .sheet(.creatureEdit(CreatureEditViewAction.didAdd(let result))):
                    // A copy was edited and added
                    if case let .compendium(entry) = result {
                        return .merge(
                            .send(.didAddCopy),
                            .send(.setNextScreen(.compendiumItemDetailView(.init(entry: entry)))),
                            .send(.setSheet(nil))
                        )
                    } else {
                        return .send(.setSheet(nil))
                    }
                case .sheet(.creatureEdit(CreatureEditViewAction.onRemoveTap)):
                    let entryKey = state.entry.key
                    return .run { send in
                        _ = try? env.database.keyValueStore.remove(entryKey.rawValue)
                        await send(.setSheet(nil))

                        try await Task.sleep(for: .seconds(0.1))
                        await send(.didRemoveItem)
                    }
                case .sheet(.groupEdit(CompendiumItemGroupEditAction.onDoneTap(let group))):
                    let entry = CompendiumEntry(group, origin: state.entry.origin, document: state.entry.document)
                    state.entry = entry
                    return .run { send in
                        try? env.compendium.put(entry)
                        await send(.setSheet(nil))
                    }
                case .sheet(.groupEdit(CompendiumItemGroupEditAction.onRemoveTap(let group))):
                    return .run { send in
                        _ = try? env.database.keyValueStore.remove(group.key)
                        await send(.setSheet(nil))

                        try await Task.sleep(for: .seconds(0.1))
                        await send(.didRemoveItem)
                    }
                case .sheet(.transfer(CompendiumItemTransferFeature.Action.onTransferDidSucceed)):
                    return .run { send in
                        // TODO: refresh screen (but how to know the new entry key if it moved realms)
                        await send(.setSheet(nil))
                    }
                case .sheet: break // handled by the reducers above
                case .didRemoveItem: break // handled by the compendium index reducer
                case .didAddCopy: break // handled by the compendium index reducer
                case .setNextScreen(let s):
                    state.presentedScreens[.nextInStack] = s
                case .setDetailScreen(let s):
                    state.presentedScreens[.detail] = s
                case .nextScreen, .detailScreen: break // handled by reducers above
                }
                return .none
            }
        )
    }
}

enum CompendiumItemDetailViewAction: NavigationStackSourceAction, Equatable {
    case onAppear
    case entry(CompendiumEntry)
    case onSaveMonsterAsNPCButton(Monster)
    case didTapCompendiumItemReferenceTextAnnotation(CompendiumItemReferenceTextAnnotation, AppNavigation)
    case popover(CompendiumEntryDetailViewState.Popover?)
    case creatureActionPopover(ActionResolutionViewAction)
    case rollCheckPopover(DiceCalculatorAction)
    case setSheet(CompendiumEntryDetailViewState.Sheet?)
    case sheet(SheetAction)
    case didRemoveItem
    case didAddCopy

    case setNextScreen(CompendiumEntryDetailViewState.NextScreen?)
    case nextScreen(NextScreenAction)
    case setDetailScreen(CompendiumEntryDetailViewState.NextScreen?)
    case detailScreen(NextScreenAction)

    static func presentScreen(_ destination: NavigationDestination, _ screen: CompendiumEntryDetailViewState.NextScreen?) -> Self {
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

    enum SheetAction: Equatable {
        case creatureEdit(CreatureEditViewAction)
        case groupEdit(CompendiumItemGroupEditAction)
        case transfer(CompendiumItemTransferFeature.Action)
    }

    enum NextScreenAction: Equatable {
        indirect case compendiumItemDetailView(CompendiumItemDetailViewAction)
        case safariView
    }
}

extension CompendiumItem {
    var compendiumItemDetailViewStateId: String { key.keyString }
}

extension CompendiumEntryDetailViewState {
    static let nullInstance = CompendiumEntryDetailViewState(entry: CompendiumEntry.nullInstance)
}
