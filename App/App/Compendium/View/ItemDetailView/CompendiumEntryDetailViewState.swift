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
import MechMuse

typealias CompendiumEntryDetailEnvironment = EnvironmentWithDatabase & EnvironmentWithCompendium & EnvironmentWithCompendiumMetadata
    & EnvironmentWithCrashReporter & (EnvironmentWithModifierFormatter & EnvironmentWithMainQueue & EnvironmentWithDiceLog & EnvironmentWithCompendiumMetadata & EnvironmentWithMechMuse & EnvironmentWithCompendium & EnvironmentWithDatabase) & ActionResolutionEnvironment

struct CompendiumEntryDetailFeature: Reducer {
    struct State: NavigationStackSourceState, Equatable {

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

        var createActionPopover: ActionResolutionFeature.State? {
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

        var rollCheckPopover: DiceCalculator.State? {
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

        var creatureEditSheet: CreatureEditFeature.State? {
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

        var groupEditSheet: CompendiumItemGroupEditFeature.State? {
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
                case .compendiumItemDetailView: return .compendiumItemDetailView(CompendiumEntryDetailFeature.State(entry: CompendiumEntry.nullInstance))
                case .safariView: return .safariView(.nullInstance)
                }
            }
            return self
        }

        enum Popover: Equatable, Identifiable {
            case creatureAction(ActionResolutionFeature.State)
            case rollCheck(DiceCalculator.State)

            var id: String {
                switch self {
                case .creatureAction: return "creatureAction"
                case .rollCheck: return "rollCheck"
                }
            }
        }

        enum Sheet: Equatable, Identifiable {
            case creatureEdit(CreatureEditFeature.State)
            case groupEdit(CompendiumItemGroupEditFeature.State)
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
            case compendiumItemDetailView(CompendiumEntryDetailFeature.State)
            case safariView(SafariViewState)
        }
    }

    enum Action: NavigationStackSourceAction, Equatable {
        case onAppear
        case entry(CompendiumEntry)
        case onSaveMonsterAsNPCButton(Monster)
        case didTapCompendiumItemReferenceTextAnnotation(CompendiumItemReferenceTextAnnotation, AppNavigation)
        case popover(State.Popover?)
        case creatureActionPopover(ActionResolutionFeature.Action)
        case rollCheckPopover(DiceCalculator.Action)
        case setSheet(State.Sheet?)
        case sheet(SheetAction)
        case didRemoveItem
        case didAddCopy

        case setNextScreen(State.NextScreen?)
        case nextScreen(NextScreenAction)
        case setDetailScreen(State.NextScreen?)
        case detailScreen(NextScreenAction)

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

        enum SheetAction: Equatable {
            case creatureEdit(CreatureEditFeature.Action)
            case groupEdit(CompendiumItemGroupEditFeature.Action)
            case transfer(CompendiumItemTransferFeature.Action)
        }

        enum NextScreenAction: Equatable {
            indirect case compendiumItemDetailView(CompendiumEntryDetailFeature.Action)
            case safariView
        }
    }

    let environment: CompendiumEntryDetailEnvironment

    init(environment: CompendiumEntryDetailEnvironment) {
        self.environment = environment
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if let group = state.entry.item as? CompendiumItemGroup {
                    let entry = state.entry
                    // refresh group members
                    return .run { [group, entry] send in
                        do {
                            let characters = try group.members.compactMap { member -> Character? in
                                let item = try environment.database.keyValueStore.get(
                                    member.itemKey,
                                    crashReporter: environment.crashReporter
                                )?.item
                                return item as? Character
                            }

                            var newGroup = group
                            if newGroup.updateMemberReferences(with: characters) {
                                var newEntry = entry
                                newEntry.item = newGroup
                                try environment.database.keyValueStore.put(newEntry)
                                await send(.entry(newEntry))
                            }
                        } catch {
                            // failed
                        }
                    }
                }
            case .entry(let e): state.entry = e
            case .onSaveMonsterAsNPCButton: break // handled by the compendium container
            case .didTapCompendiumItemReferenceTextAnnotation: break // handled below
            case .popover(let p): state.popover = p
            case .creatureActionPopover: break // handled by a reducer below
            case .rollCheckPopover: break // handled by a reducer below
            case .setSheet(let s): state.sheet = s
            case .sheet(.creatureEdit(CreatureEditFeature.Action.didEdit(let result))):
                if case let .compendium(entry) = result {
                    state.entry = entry
                    return .send(.setSheet(nil))
                }
                return .send(.setSheet(nil))
            case .sheet(.creatureEdit(CreatureEditFeature.Action.didAdd(let result))):
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
            case .sheet(.creatureEdit(CreatureEditFeature.Action.onRemoveTap)):
                let entryKey = state.entry.key
                return .run { send in
                    _ = try? environment.database.keyValueStore.remove(entryKey.rawValue)
                    await send(.setSheet(nil))

                    try await Task.sleep(for: .seconds(0.1))
                    await send(.didRemoveItem)
                }
            case .sheet(.groupEdit(CompendiumItemGroupEditFeature.Action.onDoneTap(let group))):
                let entry = CompendiumEntry(group, origin: state.entry.origin, document: state.entry.document)
                state.entry = entry
                return .run { send in
                    try? environment.compendium.put(entry)
                    await send(.setSheet(nil))
                }
            case .sheet(.groupEdit(CompendiumItemGroupEditFeature.Action.onRemoveTap(let group))):
                return .run { send in
                    _ = try? environment.database.keyValueStore.remove(group.key)
                    await send(.setSheet(nil))

                    try await Task.sleep(for: .seconds(0.1))
                    await send(.didRemoveItem)
                }
            case .sheet(.transfer(CompendiumItemTransferFeature.Action.onTransferDidSucceed)):
                return .run { send in
                    // TODO: refresh screen (but how to know the new entry key if it moved realms)
                    await send(.setSheet(nil))
                }
            case .sheet: break // handled by the reducers below
            case .didRemoveItem: break // handled by the compendium index reducer
            case .didAddCopy: break // handled by the compendium index reducer
            case .setNextScreen(let s):
                state.presentedScreens[.nextInStack] = s
            case .setDetailScreen(let s):
                state.presentedScreens[.detail] = s
            case .nextScreen, .detailScreen: break // handled by reducers below
            }
            return .none
        }
        .ifLet(\.creatureEditSheet, action: /Action.sheet..Action.SheetAction.creatureEdit) {
            CreatureEditFeature()
        }
        .ifLet(\.groupEditSheet, action: /Action.sheet..Action.SheetAction.groupEdit) {
            CompendiumItemGroupEditFeature(environment: environment)
        }
        .ifLet(\.transferSheet, action: /Action.sheet..Action.SheetAction.transfer) {
            CompendiumItemTransferFeature()
                .dependency(\.compendiumMetadata, environment.compendiumMetadata)
        }
        .ifLet(\.createActionPopover, action: /Action.creatureActionPopover) {
            ActionResolutionFeature(environment: environment)
        }
        .ifLet(\.rollCheckPopover, action: /Action.rollCheckPopover) {
            DiceCalculator(environment: environment)
        }
        .ifLet(\.presentedNextCompendiumItemDetailView, action: /Action.nextScreen..Action.NextScreenAction.compendiumItemDetailView) {
            CompendiumEntryDetailFeature(environment: environment)
        }

        Reduce(
            CompendiumItemReferenceTextAnnotation.handleTapReducer(
                didTapAction: /Action.didTapCompendiumItemReferenceTextAnnotation,
                requestItem: \.itemRequest,
                internalAction: /Action.setNextScreen..State.NextScreen.compendiumItemDetailView,
                externalAction: /Action.setNextScreen..State.NextScreen.safariView,
                environment: { $0 }
            ),
            environment: environment
        )
    }
}

extension CompendiumItem {
    var compendiumItemDetailViewStateId: String { key.keyString }
}

