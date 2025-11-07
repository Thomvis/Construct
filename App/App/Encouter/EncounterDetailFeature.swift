//
//  EncounterDetailViewState.swift
//  Construct
//
//  Created by Thomas Visser on 14/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import CasePaths
import SwiftUI
import ComposableArchitecture
import Helpers
import Persistence
import GameModels
import MechMuse

struct EncounterDetailFeature: Reducer {
    struct AddCombatantSheet: Identifiable, Equatable {
        let id: UUID
        var state: AddCombatantFeature.State

        init(id: UUID = UUID(), state: AddCombatantFeature.State) {
            self.id = id
            self.state = state
        }

        static let nullInstance = AddCombatantSheet(state: AddCombatantFeature.State.nullInstance)
    }

    struct State: Equatable {
        var building: Encounter {
            didSet {
                let b = building
                addCombatantState?.encounter = b

                if let cds = combatantDetailState, let c = b.combatant(for: cds.combatant.id) {
                    combatantDetailState?.combatant = c
                }
            }
        }
        var running: RunningEncounter? {
            didSet {
                if let running = running {
                    addCombatantState?.encounter = running.current
                    if let cds = combatantDetailState {
                        combatantDetailState?.runningEncounter = running
                        if let c = running.current.combatant(for: cds.combatant.id) {
                            combatantDetailState?.combatant = c
                        }
                    }
                    // refresh combatants in selectedCombatantTagsState
                    if let scts = selectedCombatantTagsState {
                        selectedCombatantTagsState?.combatants = scts.combatants.compactMap { running.current.combatant(for: $0.id) }
                    }
                }
            }
        }

        typealias AsyncResumableRunningEncounters = Async<[String], EquatableError>
        var resumableRunningEncounters: AsyncResumableRunningEncounters.State = .initial

        var sheet: Sheet?
        var popover: Popover?

        var editMode: EditMode = .inactive
        var selection = Set<Combatant.Id>()

        var isMechMuseEnabled: Bool

        public init(
            building: Encounter,
            running: RunningEncounter? = nil,
            resumableRunningEncounters: AsyncResumableRunningEncounters.State = .initial,
            sheet: Sheet? = nil,
            popover: Popover? = nil,
            editMode: EditMode = .inactive,
            selection: Set<Combatant.Id> = Set<Combatant.Id>(),
            isMechMuseEnabled: Bool = true
        ) {
            self.building = building
            self.running = running
            self.resumableRunningEncounters = resumableRunningEncounters
            self.sheet = sheet
            self.popover = popover
            self.editMode = editMode
            self.selection = selection
            self.isMechMuseEnabled = isMechMuseEnabled
        }

        var encounter: Encounter {
            get { running?.current ?? building }
            set {
                if running != nil {
                    running?.current = newValue
                } else {
                    building = newValue
                }
            }
        }

        var addCombatantState: AddCombatantFeature.State? {
            get {
                if case .add(let sheet)? = sheet {
                    return sheet.state
                }
                return nil
            }
            set {
                if case .add(let sheet)? = sheet, let state = newValue {
                    self.sheet = .add(AddCombatantSheet(id: sheet.id, state: state))
                }
            }
        }

        var combatantDetailState: CombatantDetailFeature.State? {
            get {
                if case .combatant(let state)? = sheet {
                    return state
                }
                return nil
            }
            set {
                if sheet != nil {
                    self.sheet = newValue.map { .combatant($0) }
                }
            }
        }

        var combatantDetailReferenceItemRequest: ReferenceViewItemRequest?
        var addCombatantReferenceItemRequest: ReferenceViewItemRequest?

        var runningEncounterLogState: RunningEncounterLogViewState? {
            guard case .runningEncounterLog(let state)? = sheet else { return nil }
            return state
        }

        var selectedCombatantTagsState: CombatantTagsFeature.State? {
            get {
                guard case .selectedCombatantTags(let state) = sheet else { return nil }
                return state
            }

            set {
                if let state = newValue {
                    self.sheet = .selectedCombatantTags(state)
                }
            }
        }

        var combatantInitiativePopover: NumberEntryFeature.State? {
            get {
                guard case .combatantInitiative(_, let s) = popover else { return nil }
                return s
            }
            set {
                if let newValue = newValue, case .combatantInitiative(let c, _) = popover {
                    popover = .combatantInitiative(c, newValue)
                }
            }
        }

        var generateCombatantTraitsState: GenerateCombatantTraitsFeature.State? {
            get {
                guard case .generateCombatantTraits(let s) = sheet else { return nil }
                return s
            }
            set {
                if let newValue = newValue {
                    self.sheet = .generateCombatantTraits(newValue)
                }
            }
        }

        var localStateForDeduplication: Self {
            var res = self
            res.sheet = sheet.map {
                switch $0 {
                case .add: return .add(AddCombatantSheet.nullInstance)
                case .combatant: return .combatant(CombatantDetailFeature.State.nullInstance)
                case .runningEncounterLog: return .runningEncounterLog(RunningEncounterLogViewState.nullInstance)
                case .selectedCombatantTags: return .selectedCombatantTags(CombatantTagsFeature.State.nullInstance)
                case .settings: return .settings
                case .generateCombatantTraits: return .generateCombatantTraits(GenerateCombatantTraitsFeature.State.nullInstance)
                }
            }

            res.popover = popover.map {
                switch $0 {
                case .encounterInitiative: return .encounterInitiative
                case .combatantInitiative: return .combatantInitiative(Combatant.nullInstance, NumberEntryFeature.State.nullInstance)
                case .health: return .health(.single(Combatant.nullInstance))
                }
            }

            return res
        }

        enum Sheet: Equatable {
            case add(AddCombatantSheet)
            case combatant(CombatantDetailFeature.State)
            case runningEncounterLog(RunningEncounterLogViewState)
            case selectedCombatantTags(CombatantTagsFeature.State)
            case settings
            case generateCombatantTraits(GenerateCombatantTraitsFeature.State)
        }

        enum Popover: Equatable {
            case encounterInitiative
            case combatantInitiative(Combatant, NumberEntryFeature.State)
            case health(CombatantActionTarget)
        }

        enum CombatantActionTarget: Equatable {
            case single(Combatant)
            case selection
        }
    }

    enum Action: Equatable {
        case onAppear
        case encounter(Encounter.Action) // forwarded to the effective encounter
        case buildingEncounter(Encounter.Action)
        case runningEncounter(RunningEncounter.Action)
        case onResumeRunningEncounterTap(String) // key of the running encounter
        case run(RunningEncounter?)
        case stop
        case sheet(State.Sheet?)
        case popover(State.Popover?)
        case combatantInitiativePopover(NumberEntryFeature.Action)
        case addCombatant(AddCombatantFeature.Action)
        case addCombatantAction(AddCombatantView.Action, Bool)
        case combatantDetail(CombatantDetailFeature.Action)
        case resumableRunningEncounters(State.AsyncResumableRunningEncounters.Action)
        case removeResumableRunningEncounter(String) // key of the running encounter
        case resetEncounter(Bool) // false = clear monsters, true = clear all
        case editMode(EditMode)
        case selection(Set<Combatant.Id>)
        case generateCombatantTraits(GenerateCombatantTraitsFeature.Action)

        case selectionEncounterAction(SelectionEncounterAction)
        case selectionCombatantAction(CombatantAction)

        case selectedCombatantTags(CombatantTagsFeature.Action)

        case showCombatantDetailReferenceItem(Combatant)
        case showAddCombatantReferenceItem
        case didDismissReferenceItem(TabbedDocumentViewContentItem.Id)

        case onGenerateCombatantTraitsButtonTap
        case onFeedbackButtonTap

        enum SelectionEncounterAction: Hashable {
            case duplicate
            case remove
        }
    }

    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
//            case .onAppear:
//                return EffectTask.run { [state] send in
//                    if state.resumableRunningEncounters.result == nil {
//                        await send(.resumableRunningEncounters(.startLoading))
//                    }
//
//                    await send(.buildingEncounter(.refreshCompendiumItems))
//                }
//            case .onResumeRunningEncounterTap(let resumableKey):
//                return .run { send in
//                    do {
//                        if let runningEncounter: RunningEncounter = try environment.database.keyValueStore.get(
//                            resumableKey,
//                            crashReporter: environment.crashReporter
//                        ) {
//                            await send(.run(runningEncounter))
//                        } else {
//                            assertionFailure("Could not resume run: \(resumableKey) not found")
//                        }
//                    } catch {
//                        assertionFailure("Could not resume run: \(error)")
//                    }
//                }.animation()
//            case .run(let runningEncounter):
//                let base = apply(state.building) {
//                    $0.ensureStableDiscriminators = true
//                }
//                let re = runningEncounter
//                    ?? RunningEncounter(
//                        id: environment.generateUUID().tagged(),
//                        base: base,
//                        current: base,
//                        turn: state.building.initiativeOrder.first.map { RunningEncounter.Turn(round: 1, combatantId: $0.id) }
//                    )
//                state.running = re
//                // let's not use this until it's a setting
//                // state.building.runningEncounterKey = re.key
//            case .stop:
//                state.running = nil
//                state.encounter.runningEncounterKey = nil
//                return .send(.resumableRunningEncounters(.startLoading))
//            case .encounter(let a): // forward to the effective encounter
//                if state.running != nil {
//                    return .send(.runningEncounter(.current(a)))
//                } else {
//                    return .send(.buildingEncounter(a))
//                }
//            case .buildingEncounter: break
//            case .runningEncounter: break
//            case .resumableRunningEncounters: break // handled below
//            case .removeResumableRunningEncounter(let key):
//                return .run { send in
//                    _ = try? environment.database.keyValueStore.remove(key)
//                    await send(.resumableRunningEncounters(.startLoading))
//                }
//            case .sheet(let s):
//                state.sheet = s
//            case .addCombatant(AddCombatantFeature.Action.onSelect(let combatants, let dismiss)):
//                var effects: [EffectTask<Action>] = combatants.map { combatant in
//                    .send(.encounter(.add(combatant)))
//                }
//
//                if dismiss {
//                    effects.append(
//                        .run { send in
//                            await Task.yield()
//                            await send(.sheet(nil))
//                        }
//                    )
//                }
//
//                return .concatenate(effects)
//            case .addCombatant: break // handled by AddCombatantFeature reducer
//            case .addCombatantAction(let action, let dismiss):
//                let state = state
//                return .run { send in
//                    switch action {
//                    case .add(let combatants):
//                        for c in combatants {
//                            await send(.encounter(.add(c)))
//                        }
//                    case .addByKey(let keys, let party):
//                        for key in keys {
//                            await send(.encounter(.addByKey(key, party)))
//                        }
//                    case .remove(let definitionID, let quantity):
//                        for c in state.encounter.combatants(with: definitionID).reversed().prefix(quantity) {
//                            await send(.encounter(.remove(c)))
//                        }
//                    }
//
//                    if dismiss {
//                        await send(.sheet(nil))
//                    }
//                }
//            case .combatantDetail(.combatant(let a)):
//                if let combatantDetailState = state.combatantDetailState {
//                    return .send(.encounter(.combatant(combatantDetailState.combatant.id, a)))
//                }
//            case .combatantDetail: break // handled by CombatantDetailFeature reducer
//            case .popover(let p):
//                state.popover = p
//            case .combatantInitiativePopover: break // handled below

//            case .resetEncounter(let clearAll):
//                state.building.runningEncounterKey = nil
//                if clearAll {
//                    state.building.combatants = []
//                } else {
//                    state.building.combatants.removeAll { $0.party == nil && $0.definition.player == nil }
//                }
//
//                let runningEncounterPrefix = RunningEncounter.keyPrefix(for: state.building)
//                return .run { send in
//                    // remove all runs
//                    _ = try? environment.database.keyValueStore.removeAll(.keyPrefix(runningEncounterPrefix.rawValue))
//                    await send(.resumableRunningEncounters(.startLoading))
//                }
//            case .editMode(let mode):
//                state.editMode = mode
//                if mode == .inactive {
//                    state.selection.removeAll()
//                }
//            case .selection(let s):
//                state.selection = s
//            case .generateCombatantTraits(.onDoneButtonTap):
//                state.sheet = nil
//            case .generateCombatantTraits: break // handled below
//            case .selectionCombatantAction(let action):
//                return .merge(
//                    state.selection.map {
//                        .send(.encounter(.combatant($0, action)))
//                    }
//                )
//            case .selectionEncounterAction(let action):
//                let encounter = state.encounter
//                return .merge(
//                    state.selection.compactMap { id -> EffectTask<Action>? in
//                        guard let combatant = encounter.combatant(for: id) else { return nil }
//                        switch action {
//                        case .duplicate:
//                            return .send(.encounter(.duplicate(combatant)))
//                        case .remove:
//                            return .send(.encounter(.remove(combatant)))
//                        }
//                    }
//                )
//            case .selectedCombatantTags(.combatant(let c, let a)):
//                return .send(.encounter(.combatant(c.id, a)))
//            case .selectedCombatantTags: break // handled below
//            case .showCombatantDetailReferenceItem(let combatant):
//                let detailState = ReferenceItem.State.Content.CombatantDetail(
//                    encounter: state.encounter,
//                    selectedCombatantId: combatant.id,
//                    runningEncounter: state.running
//                )
//
//                state.combatantDetailReferenceItemRequest = ReferenceViewItemRequest(
//                    id: state.combatantDetailReferenceItemRequest?.id ?? UUID().tagged(),
//                    state: ReferenceItem.State(content: .combatantDetail(detailState)),
//                    oneOff: false
//                )
//            case .showAddCombatantReferenceItem:
//                state.addCombatantReferenceItemRequest = ReferenceViewItemRequest(
//                    id: state.addCombatantReferenceItemRequest?.id ?? UUID().tagged(),
//                    state: ReferenceItem.State(content: .addCombatant(ReferenceItem.State.Content.AddCombatant(addCombatantState: AddCombatantFeature.State(encounter: state.encounter)))),
//                    oneOff: false
//                )
//            case .didDismissReferenceItem(let id):
//                if state.addCombatantReferenceItemRequest?.id == id {
//                    state.addCombatantReferenceItemRequest = nil
//                } else if state.combatantDetailReferenceItemRequest?.id == id {
//                    state.combatantDetailReferenceItemRequest = nil
//                }
            case .onGenerateCombatantTraitsButtonTap:
                state.sheet = .generateCombatantTraits(.init(
                    encounter: state.encounter
                ))
            case .onFeedbackButtonTap:
                guard environment.canSendMail() else { break }

                let currentState = state
                return .run { send in
                    try await Task.sleep(for: .seconds(0.1)) // delay for a bit so the menu has disappeared

                    let imageData = await MainActor.run {
                        environment.screenshot()?.pngData()
                    }

                    environment.sendMail(.init(
                        subject: "Encounter Feedback",
                        attachment: Array(builder: {
                            FeedbackMailContents.Attachment(customDump: currentState)

                            if let imageData {
                                FeedbackMailContents.Attachment(data: imageData, mimeType: "image/png", fileName: "view.png")
                            }
                        })
                    ))
                }
            default: break
            }
            return .none
        }
        .ifLet(\.addCombatantState, action: /Action.addCombatant) {
            AddCombatantFeature(environment: environment)
        }
        .ifLet(\.combatantInitiativePopover, action: /Action.combatantInitiativePopover) {
            NumberEntryFeature(environment: environment)
        }
        .ifLet(\.running, action: /Action.runningEncounter) {
            RunningEncounter.Reducer(environment: environment)
        }
        .ifLet(\.combatantDetailState, action: /Action.combatantDetail) {
            CombatantDetailFeature(environment: environment)
        }
        .ifLet(\.selectedCombatantTagsState, action: /Action.selectedCombatantTags) {
            CombatantTagsFeature(environment: environment)
        }
        Scope(state: \.building, action: /Action.buildingEncounter) {
            Encounter.Reducer(environment: environment)
        }

        EmptyReducer()
            .ifLet(\.generateCombatantTraitsState, action: /Action.generateCombatantTraits) {
                GenerateCombatantTraitsFeature(environment: environment)
            }
            .onChange(of: \.generateCombatantTraitsState?.traits) { _, _ in
                Reduce { state, action in
                    guard let combatants = state.generateCombatantTraitsState?.combatants else { return .none }

                    // apply all changes from the "generate combatant traits" view
                    for c in combatants {
                        state.encounter.combatants[id: c.id]?.traits = c.traits
                    }
                    return .none
                }
            }

        WithValue(value: \.building.id) { id in
            Scope(state: \.resumableRunningEncounters, action: /Action.resumableRunningEncounters) {
                State.AsyncResumableRunningEncounters {
                    do {
                        return try environment.database.keyValueStore.fetchKeys(.keyPrefix(RunningEncounter.keyPrefix(for: id).rawValue))
                    } catch {
                        throw error.toEquatableError()
                    }
                }
            }
        }
    }
}


extension EncounterDetailFeature.State: NavigationStackItemState {
    var navigationStackItemStateId: String { encounter.rawKey }

    var navigationTitle: String { encounter.name }
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { .inline }
}


extension EncounterDetailFeature.State {
    static let nullInstance = EncounterDetailFeature.State(building: Encounter.nullInstance, isMechMuseEnabled: false)
}
