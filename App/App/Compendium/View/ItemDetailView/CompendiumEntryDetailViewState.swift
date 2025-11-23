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
import Helpers
import DiceRollerFeature
import GameModels
import ActionResolutionFeature
import Persistence
import Compendium
import MechMuse

struct CompendiumEntryDetailFeature: Reducer {
    struct State: Equatable {

        var entry: CompendiumEntry
        var popover: Popover?
        @PresentationState var sheet: Sheet.State?
        @PresentationState var destination: Destination.State?
        var safari: SafariViewState?
        var itemRequest: ReferenceViewItemRequest?

        init(
            entry: CompendiumEntry,
            popover: Popover? = nil,
            sheet: Sheet.State? = nil,
            destination: Destination.State? = nil,
            safari: SafariViewState? = nil,
            itemRequest: ReferenceViewItemRequest? = nil
        ) {
            self.entry = entry
            self.popover = popover
            self._sheet = PresentationState(wrappedValue: sheet)
            self._destination = PresentationState(wrappedValue: destination)
            self.safari = safari
            self.itemRequest = itemRequest
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

        var navigationStackItemStateId: String { item.compendiumItemDetailViewStateId }

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

        var localStateForDeduplication: Self {
            var res = self
            res.popover = popover.map {
                switch $0 {
                case .creatureAction: return .creatureAction(.nullInstance)
                case .rollCheck: return .rollCheck(.nullInstance)
                }
            }
            res.sheet = res.sheet.map {
                switch $0 {
                case .creatureEdit: return .creatureEdit(.nullInstance)
                case .groupEdit: return .groupEdit(.nullInstance)
                case .transfer: return .transfer(.nullInstance)
                }
            }
            if let destination {
                res.destination = destination.nullInstance
            }
            if safari != nil {
                res.safari = .nullInstance
            }
            return res
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

    }

    enum Action: Equatable {
        case onAppear
        case entry(CompendiumEntry)
        case onSaveMonsterAsNPCButton(Monster)
        case didTapCompendiumItemReferenceTextAnnotation(CompendiumItemReferenceTextAnnotation, AppNavigation)
        case popover(State.Popover?)
        case creatureActionPopover(ActionResolutionFeature.Action)
        case rollCheckPopover(DiceCalculator.Action)
        case setSheet(Sheet.State?)
        case sheet(PresentationAction<Sheet.Action>)
        case didRemoveItem
        case didAddCopy
        case setDestination(Destination.State?)
        case destination(PresentationAction<Destination.Action>)
        case setSafari(SafariViewState?)
    }

    struct Destination: Reducer {
        indirect enum State: Equatable {
            case compendiumItemDetailView(CompendiumEntryDetailFeature.State)
        }

        enum Action: Equatable {
            case compendiumItemDetailView(CompendiumEntryDetailFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.compendiumItemDetailView, action: /Action.compendiumItemDetailView) {
                CompendiumEntryDetailFeature()
            }
        }
    }

    struct Sheet: Reducer {
        enum State: Equatable {
            case creatureEdit(CreatureEditFeature.State)
            case groupEdit(CompendiumItemGroupEditFeature.State)
            case transfer(CompendiumItemTransferFeature.State)
        }

        enum Action: Equatable {
            case creatureEdit(CreatureEditFeature.Action)
            case groupEdit(CompendiumItemGroupEditFeature.Action)
            case transfer(CompendiumItemTransferFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.creatureEdit, action: /Action.creatureEdit) {
                CreatureEditFeature()
            }
            Scope(state: /State.groupEdit, action: /Action.groupEdit) {
                CompendiumItemGroupEditFeature()
            }
            Scope(state: /State.transfer, action: /Action.transfer) {
                CompendiumItemTransferFeature()
            }
        }
    }

    @Dependency(\.compendium) var compendium
    @Dependency(\.database) var database
    @Dependency(\.crashReporter) var crashReporter

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if let group = state.entry.item as? CompendiumItemGroup {
                    let entry = state.entry
                    return .run { [group, entry] send in
                        do {
                            let characters = try group.members.compactMap { member -> Character? in
                                let item = try database.keyValueStore.get(
                                    member.itemKey,
                                    crashReporter: crashReporter
                                )?.item
                                return item as? Character
                            }

                            var newGroup = group
                            if newGroup.updateMemberReferences(with: characters) {
                                var newEntry = entry
                                newEntry.item = newGroup
                                try database.keyValueStore.put(newEntry)
                                await send(.entry(newEntry))
                            }
                        } catch {
                            // failed
                        }
                    }
                }
            case .entry(let e):
                state.entry = e
            case .onSaveMonsterAsNPCButton: break // handled by the compendium container
            case .didTapCompendiumItemReferenceTextAnnotation: break // handled below
            case .popover(let p):
                state.popover = p
            case .creatureActionPopover, .rollCheckPopover: break // handled below
            case .setSheet(let s):
                state.sheet = s
            case .sheet(.presented(.creatureEdit(.didEdit(let result)))):
                if case let .compendium(entry) = result {
                    state.entry = entry
                }
                return .send(.setSheet(nil))
            case .sheet(.presented(.creatureEdit(.didAdd(let result)))):
                if case let .compendium(entry) = result {
                    return .merge(
                        .send(.didAddCopy),
                        .send(.setDestination(.compendiumItemDetailView(.init(entry: entry)))),
                        .send(.setSheet(nil))
                    )
                }
                return .send(.setSheet(nil))
            case .sheet(.presented(.creatureEdit(.onRemoveTap))):
                let entryKey = state.entry.key
                return .run { send in
                    _ = try? database.keyValueStore.remove(entryKey.rawValue)
                    await send(.setSheet(nil))

                    try await Task.sleep(for: .seconds(0.1))
                    await send(.didRemoveItem)
                }
            case .sheet(.presented(.groupEdit(.onDoneTap(let group)))):
                let entry = CompendiumEntry(group, origin: state.entry.origin, document: state.entry.document)
                state.entry = entry
                return .run { send in
                    try? compendium.put(entry)
                    await send(.setSheet(nil))
                }
            case .sheet(.presented(.groupEdit(.onRemoveTap(let group)))):
                return .run { send in
                    _ = try? database.keyValueStore.remove(group.key)
                    await send(.setSheet(nil))

                    try await Task.sleep(for: .seconds(0.1))
                    await send(.didRemoveItem)
                }
            case .sheet(.presented(.transfer(.onTransferDidSucceed))):
                return .run { send in
                    // TODO: refresh screen (but how to know the new entry key if it moved realms)
                    await send(.setSheet(nil))
                }
            case .sheet(.presented):
                break
            case .didRemoveItem, .didAddCopy:
                break
            case .setDestination(let destination):
                state.destination = destination
            case .destination(.presented(.compendiumItemDetailView(.didRemoveItem))):
                return .send(.didRemoveItem)
            case .destination(.presented(.compendiumItemDetailView(.didAddCopy))):
                return .send(.didAddCopy)
            case .destination(.dismiss):
                state.destination = nil
            case .destination:
                break
            case .sheet(.dismiss):
                state.sheet = nil
            case .sheet:
                break
            case .setSafari(let safari):
                state.safari = safari
            }
            return .none
        }
        .ifLet(\.$sheet, action: /Action.sheet) {
            Sheet()
        }
        .ifLet(\.createActionPopover, action: /Action.creatureActionPopover) {
            ActionResolutionFeature()
        }
        .ifLet(\.rollCheckPopover, action: /Action.rollCheckPopover) {
            DiceCalculator()
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }

        CompendiumItemReferenceTextAnnotation.handleTapReducer(
            didTapAction: /Action.didTapCompendiumItemReferenceTextAnnotation,
            requestItem: \.itemRequest,
            internalAction: { .setDestination(.compendiumItemDetailView($0)) },
            externalAction: { .setSafari($0) }
        )
    }
}

extension CompendiumEntryDetailFeature.State {
    static let nullInstance = CompendiumEntryDetailFeature.State(entry: CompendiumEntry.nullInstance)
}

extension CompendiumEntryDetailFeature.State: DestinationTreeNode {}

extension CompendiumEntryDetailFeature.Destination.State {
    var nullInstance: CompendiumEntryDetailFeature.Destination.State {
        switch self {
        case .compendiumItemDetailView:
            return .compendiumItemDetailView(.nullInstance)
        }
    }
}

extension CompendiumEntryDetailFeature.Destination.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        switch self {
        case .compendiumItemDetailView(let state):
            return state.navigationNodes
        }
    }
}

extension CompendiumEntryDetailFeature.State: NavigationStackItemState {}

extension CompendiumItem {
    var compendiumItemDetailViewStateId: String { key.keyString }
}
