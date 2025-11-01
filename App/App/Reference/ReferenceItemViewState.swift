//
//  ReferenceItemViewState.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import CasePaths
import Helpers
import GameModels

struct ReferenceItemViewState: Equatable {

    var content: Content

    indirect enum Content: Equatable {
        case compendium(Compendium)
        case combatantDetail(CombatantDetail)
        case addCombatant(AddCombatant)
        case compendiumItem(CompendiumEntryDetailFeature.State)
        case safari(SafariViewState)

        var compendiumState: Content.Compendium? {
            get {
                guard case .compendium(let s) = self else { return nil }
                return s
            }
            set {
                if let newValue = newValue {
                    self = .compendium(newValue)
                }
            }
        }

        var combatantDetailState: CombatantDetail? {
            get {
                if case .combatantDetail(let s) = self {
                    return s
                }
                return nil
            }
            set {
                guard case .combatantDetail = self, let newValue = newValue else { return }
                self = .combatantDetail(newValue)
            }
        }

        var addCombatantState: AddCombatant? {
            get {
                if case .addCombatant(let s) = self {
                    return s
                }
                return nil
            }
            set {
                guard case .addCombatant = self, let newValue = newValue else { return }
                self = .addCombatant(newValue)
            }
        }

        var compendiumItemState: CompendiumEntryDetailFeature.State? {
            get {
                if case .compendiumItem(let s) = self {
                    return s
                }
                return nil
            }
            set {
                guard case .compendiumItem = self, let newValue = newValue else { return }
                self = .compendiumItem(newValue)
            }
        }

        var safariState: SafariViewState? {
            get {
                if case .safari(let s) = self {
                    return s
                }
                return nil
            }
            set {
                guard case .safari = self, let newValue = newValue else { return }
                self = .safari(newValue)
            }
        }

        var context: ReferenceContext {
            get {
                switch self {
                case .compendium(let state): return state.context
                case .combatantDetail(let state): return state.context
                case .addCombatant(let state): return state.context
                case .compendiumItem, .safari: return .empty
                }
            }
            set {
                switch self {
                case .compendium(var state):
                    state.context = newValue
                    self = .compendium(state)
                case .combatantDetail(var state):
                    state.context = newValue
                    self = .combatantDetail(state)
                case .addCombatant(var state):
                    state.context = newValue
                    self = .addCombatant(state)
                case .compendiumItem, .safari: break
                }
            }
        }

        var navigationNode: NavigationNode {
            get {
                switch self {
                case .compendium(let c): return c.compendium
                case .combatantDetail(let cd): return cd.detailState
                case .addCombatant(let ad): return ad.addCombatantState
                case .compendiumItem(let d): return d
                case .safari(let s): return s
                }
            }
            set {
                switch newValue {
                case let v as CompendiumIndexFeature.State:
                    self.compendiumState?.compendium = v
                case let v as CombatantDetailFeature.State:
                    self.combatantDetailState?.detailState = v
                case let v as AddCombatantState:
                    self.addCombatantState?.addCombatantState = v
                default:
                    fatalError("Tried to set unexpected NavigationNode in a reference view item")
                }
            }
        }

        var tabItemTitle: String? {
            switch self {
            case .compendium(let compendium):
                let title = compendium.compendium.presentedNextItemDetail?.navigationTitle

                return title.map { "\($0) - Compendium" } ?? compendium.compendium.title
            case .addCombatant(let addCombatant):
                return "\(addCombatant.addCombatantState.compendiumState.title) - \(addCombatant.addCombatantState.encounter.name)"
            case .combatantDetail(let combatantDetail):
                return "Combatant details - \(combatantDetail.encounter.name)"
            case .compendiumItem(let d):
                return "\(d.navigationTitle) - Compendium"
            case .safari(let s):
                let components = [s.url.path.nonEmptyString, s.url.host]
                if let cs = components.compactMap({ $0 }).nonEmptyArray {
                    return cs.joined(separator: " - ")
                }
                return s.url.absoluteString
            }
        }

        /// Provides access to the compendium to be used as reference material
        /// or to build an encounter
        struct Compendium: Equatable {

            let navigationStackItemStateId: String = "compendium"
            let navigationTitle: String = "Compendium"

            var context: ReferenceContext = .empty
            var compendium = CompendiumIndexFeature.State(
                title: "Compendium",
                properties: .init(showImport: true, showAdd: true, typeRestriction: nil),
                results: .initial
            )
        }

        /// Displays the details of combatants in the encounter, one at a time
        struct CombatantDetail: Equatable {
            var context: ReferenceContext = .empty {
                didSet {
                    if let encounterContext = context.encounterDetailView {
                        self.encounter = encounterContext.encounter
                        self.runningEncounter = encounterContext.running
                    }
                }
            }

            var encounter: Encounter { // updated from the outside
                didSet {
                    updateDetailState()
                }
            }

            var selectedCombatantId: Combatant.Id {
                didSet {
                    updateDetailState()
                }
            }

            var runningEncounter: RunningEncounter? {
                didSet {
                    if pinToTurn, let turn = runningEncounter?.turn {
                        selectedCombatantId = turn.combatantId
                    }
                    updateDetailState()
                }
            }

            var effectiveEncounter: Encounter {
                runningEncounter?.current ?? self.encounter
            }

            var pinToTurn: Bool

            var detailState: CombatantDetailFeature.State

            init(encounter: Encounter, selectedCombatantId: Combatant.Id, runningEncounter: RunningEncounter?) {
                self.encounter = encounter
                self.selectedCombatantId = selectedCombatantId
                self.runningEncounter = runningEncounter

                self.pinToTurn = selectedCombatantId == runningEncounter?.turn?.combatantId

                let combatant = runningEncounter?.current.combatant(for: selectedCombatantId)
                    ?? encounter.combatant(for: selectedCombatantId)
                    ?? Combatant.nullInstance
                self.detailState = CombatantDetailFeature.State(runningEncounter: runningEncounter, combatant: combatant)
            }

            private mutating func updateDetailState() {
                if let combatant = effectiveEncounter.combatant(for: selectedCombatantId) {
                    detailState.combatant = combatant
                }
            }
        }

        struct AddCombatant: Equatable {
            var addCombatantState: AddCombatantState

            var context: ReferenceContext = .empty {
                didSet {
                    if let encounter = context.encounterDetailView?.encounter {
                        addCombatantState.encounter = encounter
                    }

                    let newSuggestions = context.openCompendiumEntries.filter { entry in
                        [.character, .group, .monster].contains(entry.itemType)
                            && !(addCombatantState.compendiumState.suggestions?.contains(where: { $0.key == entry.key }) ?? false)
                    }

                    // Add open items to the suggestions displayed on the compendium
                    addCombatantState.compendiumState.suggestions = addCombatantState.compendiumState.suggestions
                        .map { $0 + newSuggestions } ?? newSuggestions.nonEmptyArray
                }
            }
        }
    }
}

enum ReferenceItemViewAction: Equatable {
    case contentCompendium(Compendium)
    case contentCombatantDetail(CombatantDetail)
    case contentAddCombatant(AddCombatant)
    case contentCompendiumItem(CompendiumEntryDetailFeature.Action)
    case contentSafari

    /// Wraps actions that need to be executed inside the EncounterReferenceContext
    /// (aka the EncounterDetailView)
    case inEncounterDetailContext(EncounterReferenceContextAction)

    case onBackTapped
    case set(ReferenceItemViewState)
    case close // handled by ReferenceView

    enum Compendium: Equatable {
        case compendium(CompendiumIndexFeature.Action)
    }

    enum CombatantDetail: Equatable {
        case detail(CombatantDetailFeature.Action)
        case previousCombatantTapped
        case nextCombatantTapped
        case togglePinToTurnTapped
    }

    enum AddCombatant: Equatable {
        case addCombatant(AddCombatantState.Action)
        case onSelection(AddCombatantView.Action)
    }
}

extension ReferenceItemViewState {
    static let nullInstance = ReferenceItemViewState(content: .compendium(Content.Compendium()))

    static let reducer: AnyReducer<Self, ReferenceItemViewAction, Environment> = AnyReducer.combine(
        ReferenceItemViewState.Content.Compendium.reducer.optional().pullback(state: \.content.compendiumState, action: /ReferenceItemViewAction.contentCompendium),
        ReferenceItemViewState.Content.CombatantDetail.reducer.optional().pullback(state: \.content.combatantDetailState, action: /ReferenceItemViewAction.contentCombatantDetail),
        ReferenceItemViewState.Content.AddCombatant.reducer.optional().pullback(
            state: \.content.addCombatantState,
            action: /ReferenceItemViewAction.contentAddCombatant,
            environment: { $0 }
        ),
        AnyReducer { env in
            CompendiumEntryDetailFeature(environment: env)
        }
        .optional()
        .pullback(
            state: \.content.compendiumItemState,
            action: /ReferenceItemViewAction.contentCompendiumItem,
            environment: { $0 }
        ),
        AnyReducer { state, action, env in
            switch action {
            case .onBackTapped:
                state.content.navigationNode.popLastNavigationStackItem()
            case .set(let s): state = s
            // lift actions that need to be executed in the EncounterReferenceContext to .inContext
            case .contentAddCombatant(.addCombatant(.onSelect(let combatants, dismiss: _))):
                return .send(.inEncounterDetailContext(.addCombatant(.add(combatants))))
            case .contentAddCombatant(.onSelection(let a)):
                return .send(.inEncounterDetailContext(.addCombatant(a)))
            case .contentCombatantDetail(.detail(.combatant(let a))):
                guard let combatant = state.content.combatantDetailState?.detailState.combatant else {
                    return .none
                }
                return .send(.inEncounterDetailContext(.combatantAction(combatant.id, a)))
            case .contentCombatantDetail, .contentCompendium, .contentAddCombatant, .contentCompendiumItem: break // handled above
            case .contentSafari: break // does not occur
            case .inEncounterDetailContext: break // handled by parent
            case .close: break // handled by parent
            }
            return .none
        }
    )
}

extension ReferenceItemViewState.Content.Compendium {
    static let reducer: AnyReducer<Self, ReferenceItemViewAction.Compendium, Environment> = AnyReducer.combine(
        compendiumRootReducer.pullback(state: \.compendium, action: /ReferenceItemViewAction.Compendium.compendium)
    )
}

extension ReferenceItemViewState.Content.CombatantDetail {
    static let reducer: AnyReducer<Self, ReferenceItemViewAction.CombatantDetail, Environment> = AnyReducer.combine(
        AnyReducer { env in
            CombatantDetailFeature(environment: env)
        }
        .pullback(state: \.detailState, action: /ReferenceItemViewAction.CombatantDetail.detail),
        AnyReducer { state, action, env in
            switch action {
            case .detail: break // handled above
            case .previousCombatantTapped:
                if let idx = state.effectiveEncounter.combatants.firstIndex(where: { $0.id == state.selectedCombatantId }), idx > 0 {
                    state.selectedCombatantId = state.effectiveEncounter.combatants[idx-1].id
                } else if let last = state.effectiveEncounter.combatants.last {
                    state.selectedCombatantId = last.id
                }
                state.pinToTurn = false
            case .nextCombatantTapped:
                if let idx = state.effectiveEncounter.combatants.firstIndex(where: { $0.id == state.selectedCombatantId }), idx < state.effectiveEncounter.combatants.endIndex-1 {
                    state.selectedCombatantId = state.effectiveEncounter.combatants[idx+1].id
                } else if let first = state.effectiveEncounter.combatants.first {
                    state.selectedCombatantId = first.id
                }
                state.pinToTurn = false
            case .togglePinToTurnTapped:
                state.pinToTurn.toggle()
            }
            return .none
        }
    )
}

extension ReferenceItemViewState.Content.AddCombatant {
    static let reducer: AnyReducer<Self, ReferenceItemViewAction.AddCombatant, AddCombatantEnvironment> = AnyReducer.combine(
        AddCombatantState.reducer.pullback(state: \.addCombatantState, action: /ReferenceItemViewAction.AddCombatant.addCombatant)
    )
}

extension ReferenceItemViewState.Content {
    var typeHash: AnyHashable {
        switch self {
        case .compendium: return "compendium"
        case .combatantDetail: return "combatantDetail"
        case .addCombatant: return "addCombatant"
        case .compendiumItem: return "compendiumItem"
        case .safari: return "safari"
        }
    }
}
