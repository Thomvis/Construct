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

    var navigationStackItemStateId: String { entry.item.compendiumItemDetailViewStateId }

    var navigationTitle: String { item.title }
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { .inline }

    var createActionPopover: DiceActionViewState? {
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

    enum Popover: Hashable, Identifiable {
        case creatureAction(DiceActionViewState)
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

        var id: String {
            switch self {
            case .creatureEdit(let s): return s.navigationStackItemStateId
            case .groupEdit(let s): return s.navigationStackItemStateId
            }
        }
    }

    enum NextScreen: Equatable {
        case compendiumItemDetailView(CompendiumEntryDetailViewState)
        case safariView(SafariViewState)
    }

    static var reducer: Reducer<Self, CompendiumItemDetailViewAction, Environment> {
        return Reducer.combine(
            CreatureEditViewState.reducer.optional().pullback(state: \.creatureEditSheet, action: /CompendiumItemDetailViewAction.sheet..CompendiumItemDetailViewAction.SheetAction.creatureEdit),
            CompendiumItemGroupEditState.reducer.optional().pullback(state: \.groupEditSheet, action: /CompendiumItemDetailViewAction.sheet..CompendiumItemDetailViewAction.SheetAction.groupEdit),
            DiceActionViewState.reducer.optional().pullback(state: \.createActionPopover, action: /CompendiumItemDetailViewAction.creatureActionPopover),
            DiceCalculatorState.reducer.optional().pullback(state: \.rollCheckPopover, action: /CompendiumItemDetailViewAction.rollCheckPopover, environment: \.diceRollerEnvironment),
            Reducer.lazy(CompendiumEntryDetailViewState.reducer).optional().pullback(state: \.presentedNextCompendiumItemDetailView, action: /CompendiumItemDetailViewAction.nextScreen..CompendiumItemDetailViewAction.NextScreenAction.compendiumItemDetailView),
            CompendiumItemReferenceTextAnnotation.handleTapReducer(
                didTapAction: /CompendiumItemDetailViewAction.didTapCompendiumItemReferenceTextAnnotation,
                requestItem: \.itemRequest,
                internalAction: /CompendiumItemDetailViewAction.setNextScreen..Self.NextScreen.compendiumItemDetailView,
                externalAction: /CompendiumItemDetailViewAction.setNextScreen..Self.NextScreen.safariView
            ),
            Reducer { state, action, env in
                switch action {
                case .onAppear:
                    if var group = state.entry.item as? CompendiumItemGroup {
                        var entry = state.entry
                        // refresh group members
                        return Effect.future { callback in
                            do {
                                let characters = try group.members.compactMap { member -> Character? in
                                    let item = try env.database.keyValueStore.get(member.itemKey)?.item
                                    return item as? Character
                                }

                                if group.updateMemberReferences(with: characters) {
                                    entry.item = group
                                    try env.database.keyValueStore.put(entry)
                                    callback(.success(.entry(entry)))
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
                case .sheet(.creatureEdit(CreatureEditViewAction.onDoneTap(let state))):
                    return Effect.run { subscriber in
                        let item = state.compendiumItem
                        if let orig = state.originalItem, orig.key != item?.key {
                            _ = try? env.database.keyValueStore.remove(orig.key)
                        }
                        if let item = item {
                            let entry = CompendiumEntry(item)
                            try? env.compendium.put(entry)
                            subscriber.send(.entry(entry))
                        }
                        subscriber.send(.setSheet(nil))
                        subscriber.send(completion: .finished)

                        return AnyCancellable { }
                    }
                case .sheet(.creatureEdit(CreatureEditViewAction.onRemoveTap)):
                    let entryKey = state.entry.key
                    return Effect.run { subscriber in
                        _ = try? env.database.keyValueStore.remove(entryKey)
                        subscriber.send(.setSheet(nil))
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                            subscriber.send(.didRemoveItem)
                            subscriber.send(completion: .finished)
                        }

                        return AnyCancellable { }
                    }
                case .sheet(.groupEdit(CompendiumItemGroupEditAction.onDoneTap(let group))):
                    let entry = CompendiumEntry(group)
                    state.entry = entry
                    return Effect.future { callback in
                        try? env.compendium.put(entry)
                        callback(.success(.setSheet(nil)))
                    }
                case .sheet(.groupEdit(CompendiumItemGroupEditAction.onRemoveTap(let group))):
                    return Effect.run { subscriber in
                        _ = try? env.database.keyValueStore.remove(group.key)
                        subscriber.send(.setSheet(nil))
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                            subscriber.send(.didRemoveItem)
                            subscriber.send(completion: .finished)
                        }

                        return AnyCancellable { }
                    }
                case .sheet: break // handled by the reducers above
                case .didRemoveItem: break // handled by the compendium index reducer
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
    case creatureActionPopover(DiceActionViewAction)
    case rollCheckPopover(DiceCalculatorAction)
    case setSheet(CompendiumEntryDetailViewState.Sheet?)
    case sheet(SheetAction)
    case didRemoveItem

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
    }

    enum NextScreenAction: Equatable {
        indirect case compendiumItemDetailView(CompendiumItemDetailViewAction)
        case safariView
    }
}

extension CompendiumItem {
    var compendiumItemDetailViewStateId: String { key.rawValue }
}

extension CompendiumEntryDetailViewState {
    static let nullInstance = CompendiumEntryDetailViewState(entry: CompendiumEntry.nullInstance)
}