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

struct ReferenceItemViewState: Equatable {

    var content: Content

    enum Content: Equatable {
        case home(Home)
        case combatantDetail(CombatantDetail)
        case addCombatant(AddCombatant)

        var homeState: Content.Home? {
            get {
                guard case .home(let s) = self else { return nil }
                return s
            }
            set {
                if let newValue = newValue {
                    self = .home(newValue)
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

        var context: ReferenceContext {
            get {
                switch self {
                case .home(let state): return state.context
                case .combatantDetail(let state): return state.context
                case .addCombatant(let state): return state.context
                }
            }
            set {
                switch self {
                case .home(var state):
                    state.context = newValue
                    self = .home(state)
                case .combatantDetail(var state):
                    state.context = newValue
                    self = .combatantDetail(state)
                case .addCombatant(var state):
                    state.context = newValue
                    self = .addCombatant(state)
                }
            }
        }

        var navigationNode: NavigationNode {
            get {
                switch self {
                case .home(let h): return h
                case .combatantDetail(let cd): return cd.detailState
                case .addCombatant(let ad): return ad.addCombatantState
                }
            }
            set {
                switch newValue {
                case let v as Home:
                    self = .home(v)
                case let v as CombatantDetailViewState:
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
            case .home(let home):
                let title = home.presentedNextCompendium?.presentedNextItemDetail?.navigationTitle
                    ?? home.presentedNextCompendium?.title

                return title.map { "\($0) - Compendium" } ?? "Compendium"
            case .addCombatant(let addCombatant):
                return "\(addCombatant.addCombatantState.compendiumState.title) - \(addCombatant.addCombatantState.encounter.name)"
            case .combatantDetail(let combatantDetail):
                return "Combatant details - \(combatantDetail.encounter.name)"
            }
        }

        /// Provides access to the compendium to be used as reference material
        /// or to build an encounter
        struct Home: Equatable, NavigationStackSourceState {

            var navigationStackItemStateId: String = "home"
            var navigationTitle: String = "Reference"

            var context: ReferenceContext = .empty
            var presentedScreens: [NavigationDestination: NextScreen] = [:]

            enum NextScreen: Equatable {
                case compendium(CompendiumIndexState)
            }
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

            var selectedCombatantId: UUID {
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

            var detailState: CombatantDetailViewState

            init(encounter: Encounter, selectedCombatantId: UUID, runningEncounter: RunningEncounter?) {
                self.encounter = encounter
                self.selectedCombatantId = selectedCombatantId
                self.runningEncounter = runningEncounter

                self.pinToTurn = selectedCombatantId == runningEncounter?.turn?.combatantId

                let combatant = runningEncounter?.current.combatant(for: selectedCombatantId)
                    ?? encounter.combatant(for: selectedCombatantId)
                    ?? Combatant.nullInstance
                self.detailState = CombatantDetailViewState(runningEncounter: runningEncounter, combatant: combatant)
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

                    // Add open items to the suggestions displayed on the compendium toc
                    if case .toc(var toc) = addCombatantState.compendiumState.properties.initialContent {
                        // Add new open compendium entries
                        toc.suggested += context.openCompendiumEntries.filter { entry in
                            [.character, .group, .monster].contains(entry.itemType)
                                && !toc.suggested.contains(where: { $0.key == entry.key })
                        }
                        addCombatantState.compendiumState.properties.initialContent = .toc(toc)
                    }
                }
            }
        }
    }
}

enum ReferenceItemViewAction: Equatable {
    case contentHome(Home)
    case contentCombatantDetail(CombatantDetail)
    case contentAddCombatant(AddCombatant)

    /// Wraps actions that need to be executed inside the EncounterReferenceContext
    /// (aka the EncounterDetailView)
    case inEncounterDetailContext(EncounterReferenceContextAction)

    case onBackTapped
    case set(ReferenceItemViewState)

    enum Home: Equatable, NavigationStackSourceAction {
        case compendiumSearchTapped
        case compendiumSectionTapped(CompendiumItemType)
        case setNextScreen(ReferenceItemViewState.Content.Home.NextScreen?)
        indirect case nextScreen(NextScreenAction)
        case setDetailScreen(ReferenceItemViewState.Content.Home.NextScreen?)
        indirect case detailScreen(NextScreenAction)

        static func presentScreen(_ destination: NavigationDestination, _ screen: ReferenceItemViewState.Content.Home.NextScreen?) -> Self {
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
            case compendium(CompendiumIndexAction)
            case addCombatant(AddCombatantState.Action)
        }
    }

    enum CombatantDetail: Equatable {
        case detail(CombatantDetailViewAction)
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
    static let nullInstance = ReferenceItemViewState(content: .home(Content.Home()))

    static let reducer: Reducer<Self, ReferenceItemViewAction, Environment> = Reducer.combine(
        ReferenceItemViewState.Content.Home.reducer.optional().pullback(state: \.content.homeState, action: /ReferenceItemViewAction.contentHome),
        ReferenceItemViewState.Content.CombatantDetail.reducer.optional().pullback(state: \.content.combatantDetailState, action: /ReferenceItemViewAction.contentCombatantDetail),
        ReferenceItemViewState.Content.AddCombatant.reducer.optional().pullback(state: \.content.addCombatantState, action: /ReferenceItemViewAction.contentAddCombatant),
        Reducer { state, action, env in
            switch action {
            case .onBackTapped:
                state.content.navigationNode.popLastNavigationStackItem()
            case .set(let s): state = s
            // lift actions that need to be executed in the EncounterReferenceContext to .inContext
            case .contentAddCombatant(.addCombatant(.onSelect(let combatants, dismiss: _))):
                return Effect(value: .inEncounterDetailContext(.addCombatant(.add(combatants))))
            case .contentAddCombatant(.onSelection(let a)):
                return Effect(value: .inEncounterDetailContext(.addCombatant(a)))
            case .contentCombatantDetail(.detail(.combatant(let a))):
                guard let combatant = state.content.combatantDetailState?.detailState.combatant else {
                    return .none
                }
                return Effect(value: .inEncounterDetailContext(.combatantAction(combatant.id, a)))
            case .contentCombatantDetail, .contentHome, .contentAddCombatant: break // handled above
            case .inEncounterDetailContext: break // handled by parent
            }
            return .none
        }
    )
}

extension ReferenceItemViewState.Content.Home {
    static let reducer: Reducer<Self, ReferenceItemViewAction.Home, Environment> = Reducer.combine(
        CompendiumIndexState.reducer.optional().pullback(state: \.presentedNextCompendium, action: /ReferenceItemViewAction.Home.nextScreen..ReferenceItemViewAction.Home.NextScreenAction.compendium),
        Reducer { state, action, env in
            switch action {
            case .compendiumSearchTapped:
                let state = CompendiumIndexState(
                    title: "Compendium",
                    properties: CompendiumIndexState.Properties(
                        showImport: false,
                        showAdd: false,
                        initiallyFocusOnSearch: true,
                        initialContent: .searchResults
                    ),
                    results: .initial
                )
                return Effect(value: .setNextScreen(.compendium(state)))
            case .compendiumSectionTapped(let t):
                let compendiumIndexState = CompendiumIndexState.init(
                    title: t.localizedScreenDisplayName,
                    properties: .init(showImport: false, showAdd: false, initiallyFocusOnSearch: false, initialContent: .searchResults),
                    results: .initial(type: t)
                )
                return Effect(value: .setNextScreen(.compendium(compendiumIndexState)))
            case .setNextScreen(let s):
                state.presentedScreens[.nextInStack] = s
            case .nextScreen: break // handled above
            case .setDetailScreen(let s):
                state.presentedScreens[.detail] = s
            case .detailScreen: break // handled above
            }
            return .none
        }
    )
}

extension ReferenceItemViewState.Content.CombatantDetail {
    static let reducer: Reducer<Self, ReferenceItemViewAction.CombatantDetail, Environment> = Reducer.combine(
        CombatantDetailViewState.reducer.pullback(state: \.detailState, action: /ReferenceItemViewAction.CombatantDetail.detail),
        Reducer { state, action, env in
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
    static let reducer: Reducer<Self, ReferenceItemViewAction.AddCombatant, Environment> = Reducer.combine(
        AddCombatantState.reducer.pullback(state: \.addCombatantState, action: /ReferenceItemViewAction.AddCombatant.addCombatant)
    )
}
