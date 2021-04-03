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

struct CompendiumEntryDetailViewState: NavigationStackItemState, Equatable {

    var entry: CompendiumEntry
    @EqKey({ $0?.id })
    var popover: Popover?
    @EqKey({ $0?.id })
    var sheet: Sheet?

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

    static var reducer: Reducer<Self, CompendiumItemDetailViewAction, Environment> {
        return Reducer.combine(
            CreatureEditViewState.reducer.optional().pullback(state: \.creatureEditSheet, action: /CompendiumItemDetailViewAction.sheet..CompendiumItemDetailViewAction.SheetAction.creatureEdit),
            CompendiumItemGroupEditState.reducer.optional().pullback(state: \.groupEditSheet, action: /CompendiumItemDetailViewAction.sheet..CompendiumItemDetailViewAction.SheetAction.groupEdit),
            DiceActionViewState.reducer.optional().pullback(state: \.createActionPopover, action: /CompendiumItemDetailViewAction.creatureActionPopover),
            DiceCalculatorState.reducer.optional().pullback(state: \.rollCheckPopover, action: /CompendiumItemDetailViewAction.rollCheckPopover),
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
                case .sheet(.creatureEdit(CreatureEditViewAction.onRemoveTap(let state))):
                    return Effect.future { callback in
                        if let item = state.originalItem {
                            _ = try? env.database.keyValueStore.remove(item.key)
                        }
                        callback(.success(.setSheet(nil)))
                    }
                case .sheet(.groupEdit(CompendiumItemGroupEditAction.onDoneTap(let group))):
                    let entry = CompendiumEntry(group)
                    state.entry = entry
                    return Effect.future { callback in
                        try? env.compendium.put(entry)
                        callback(.success(.setSheet(nil)))
                    }
                case .sheet(.groupEdit(CompendiumItemGroupEditAction.onRemoveTap(let group))):
                    return Effect.future { callback in
                        _ = try? env.database.keyValueStore.remove(group.key)
                        callback(.success(.setSheet(nil)))
                    }
                case .sheet: break // handled by the reducers above
                }
                return .none
            }
        )
    }
}

enum CompendiumItemDetailViewAction: Equatable {
    case onAppear
    case entry(CompendiumEntry)
    case onSaveMonsterAsNPCButton(Monster)
    case popover(CompendiumEntryDetailViewState.Popover?)
    case creatureActionPopover(DiceActionViewAction)
    case rollCheckPopover(DiceCalculatorAction)
    case setSheet(CompendiumEntryDetailViewState.Sheet?)
    case sheet(SheetAction)

    enum SheetAction: Equatable {
        case creatureEdit(CreatureEditViewAction)
        case groupEdit(CompendiumItemGroupEditAction)
    }
}

extension CompendiumItem {
    var compendiumItemDetailViewStateId: String { key.rawValue }
}

extension CompendiumEntryDetailViewState {
    static let nullInstance = CompendiumEntryDetailViewState(entry: CompendiumEntry.nullInstance)
}
