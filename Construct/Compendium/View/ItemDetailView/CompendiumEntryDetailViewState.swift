//
//  CompendiumItemDetailViewState.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 29/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Combine
import CasePaths

struct CompendiumEntryDetailViewState: NavigationStackSourceState, Equatable {

    var entry: CompendiumEntry
    var popover: Popover?
    var presentedScreens: [NavigationDestination: NextScreen]

    init(entry: CompendiumEntry, presentedScreens: [NavigationDestination: NextScreen] = [:]) {
        self.entry = entry
        self.presentedScreens = presentedScreens
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

    enum Popover: Hashable {
        case creatureAction(DiceActionViewState)
        case rollCheck(Int)
    }

    enum NextScreen: Equatable {
        case creatureEdit(CreatureEditViewState)
        case groupEdit(CompendiumItemGroupEditState)
    }

    static var reducer: Reducer<Self, CompendiumItemDetailViewAction, Environment> {
        return Reducer.combine(
            CreatureEditViewState.reducer.optional().pullback(state: \.presentedNextCreatureEdit, action: /CompendiumItemDetailViewAction.nextScreen..CompendiumItemDetailViewAction.NextScreenAction.creatureEdit),
            CompendiumItemGroupEditState.reducer.optional().pullback(state: \.presentedNextGroupEdit, action: /CompendiumItemDetailViewAction.nextScreen..CompendiumItemDetailViewAction.NextScreenAction.groupEdit),
            DiceActionViewState.reducer.optional().pullback(state: \.createActionPopover, action: /CompendiumItemDetailViewAction.creatureActionPopover),
            Reducer { state, action, env in
                switch action {
                case .entry(let e): state.entry = e
                case .onSaveMonsterAsNPCButton: break // handled by the compendium container
                case .popover(let p): state.popover = p
                case .creatureActionPopover: break // handled by a reducer above
                case .setNextScreen(let s): state.presentedScreens[.nextInStack] = s
                case .setDetailScreen(let s): state.presentedScreens[.detail] = s
                case .nextScreen(.creatureEdit(CreatureEditViewAction.onDoneTap(let state))):
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
                        subscriber.send(.setNextScreen(nil))
                        subscriber.send(completion: .finished)

                        return AnyCancellable { }
                    }
                case .nextScreen(.creatureEdit(CreatureEditViewAction.onRemoveTap(let state))):
                    return Effect.future { callback in
                        if let item = state.originalItem {
                            _ = try? env.database.keyValueStore.remove(item.key)
                        }
                        callback(.success(.setNextScreen(nil)))
                    }
                case .nextScreen(.groupEdit(CompendiumItemGroupEditAction.onDoneTap(let group))):
                    let entry = CompendiumEntry(group)
                    state.entry = entry
                    return Effect.fireAndForget {
                        try? env.compendium.put(entry)
                        // dismissing is done by the parent
                    }
                case .nextScreen(.groupEdit(CompendiumItemGroupEditAction.onRemoveTap(let group))):
                    return Effect.future { callback in
                        _ = try? env.database.keyValueStore.remove(group.key)
                        callback(.success(.setNextScreen(nil)))
                    }
                case .nextScreen, .detailScreen: break // handled by the reducers above
                }
                return .none
            }
        )
    }
}

enum CompendiumItemDetailViewAction: NavigationStackSourceAction, Equatable {
    case entry(CompendiumEntry)
    case onSaveMonsterAsNPCButton(Monster)
    case popover(CompendiumEntryDetailViewState.Popover?)
    case creatureActionPopover(DiceActionViewAction)
    case setNextScreen(CompendiumEntryDetailViewState.NextScreen?)
    case nextScreen(NextScreenAction)
    case setDetailScreen(CompendiumEntryDetailViewState.NextScreen?)
    case detailScreen(NextScreenAction)

    enum NextScreenAction: Equatable {
        case creatureEdit(CreatureEditViewAction)
        case groupEdit(CompendiumItemGroupEditAction)
    }

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

}

extension CompendiumItem {
    var compendiumItemDetailViewStateId: String { key.rawValue }
}

extension CompendiumEntryDetailViewState {
    static let nullInstance = CompendiumEntryDetailViewState(entry: CompendiumEntry.nullInstance)
}
