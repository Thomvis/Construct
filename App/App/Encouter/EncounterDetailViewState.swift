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

struct EncounterDetailViewState: Equatable {
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

    var addCombatantState: AddCombatantState? {
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

    var selectedCombatantTagsState: CombatantTagsViewState? {
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

    var generateCombatantTraitsState: GenerateCombatantTraitsViewState? {
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
            case .selectedCombatantTags: return .selectedCombatantTags(CombatantTagsViewState.nullInstance)
            case .settings: return .settings
            case .generateCombatantTraits: return .generateCombatantTraits(GenerateCombatantTraitsViewState.nullInstance)
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
        case selectedCombatantTags(CombatantTagsViewState)
        case settings
        case generateCombatantTraits(GenerateCombatantTraitsViewState)
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

extension EncounterDetailViewState {
    enum Action: Equatable {
        case onAppear
        case encounter(Encounter.Action) // forwarded to the effective encounter
        case buildingEncounter(Encounter.Action)
        case runningEncounter(RunningEncounter.Action)
        case onResumeRunningEncounterTap(String) // key of the running encounter
        case run(RunningEncounter?)
        case stop
        case sheet(Sheet?)
        case popover(Popover?)
        case combatantInitiativePopover(NumberEntryFeature.Action)
        case addCombatant(AddCombatantState.Action)
        case addCombatantAction(AddCombatantView.Action, Bool)
        case combatantDetail(CombatantDetailFeature.Action)
        case resumableRunningEncounters(AsyncResumableRunningEncounters.Action)
        case removeResumableRunningEncounter(String) // key of the running encounter
        case resetEncounter(Bool) // false = clear monsters, true = clear all
        case editMode(EditMode)
        case selection(Set<Combatant.Id>)
        case generateCombatantTraits(GenerateCombatantTraitsViewAction)

        case selectionEncounterAction(SelectionEncounterAction)
        case selectionCombatantAction(CombatantAction)

        case selectedCombatantTags(CombatantTagsViewAction)

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

    static var reducer: AnyReducer<EncounterDetailViewState, Action, Environment> {
        return AnyReducer.combine(
            AddCombatantState.reducer.optional().pullback(
                state: \.addCombatantState,
                action: /Action.addCombatant,
                environment: { $0 }
            ),
            AnyReducer { env in
                NumberEntryFeature(environment: env)
            }
            .optional()
            .pullback(
                state: \.combatantInitiativePopover,
                action: /Action.combatantInitiativePopover,
                environment: { $0 }
            ),
            GenerateCombatantTraitsViewState.reducer.optional().pullback(
                state: \.generateCombatantTraitsState,
                action: /Action.generateCombatantTraits,
                environment: { $0 }
            )
            .onChange(of: \.generateCombatantTraitsState?.traits, perform: { traits, state, action, env in
                guard let combatants = state.generateCombatantTraitsState?.combatants else { return .none }

                // apply all changes from the "generate combatant traits" view
                for c in combatants {
                    state.encounter.combatants[id: c.id]?.traits = c.traits
                }
                return .none
            }),
            AnyReducer { state, action, env in
                switch action {
                case .onAppear:
                    return EffectTask.run { [state] send in
                        if state.resumableRunningEncounters.result == nil {
                            await send(.resumableRunningEncounters(.startLoading))
                        }

                        await send(.buildingEncounter(.refreshCompendiumItems))
                    }
                case .onResumeRunningEncounterTap(let resumableKey):
                    return .run { send in
                        do {
                            if let runningEncounter: RunningEncounter = try env.database.keyValueStore.get(
                                resumableKey,
                                crashReporter: env.crashReporter
                            ) {
                                await send(.run(runningEncounter))
                            } else {
                                assertionFailure("Could not resume run: \(resumableKey) not found")
                            }
                        } catch {
                            assertionFailure("Could not resume run: \(error)")
                        }
                    }.animation()
                case .run(let runningEncounter):
                    let base = apply(state.building) {
                        $0.ensureStableDiscriminators = true
                    }
                    let re = runningEncounter
                        ?? RunningEncounter(id: env.generateUUID().tagged(), base: base, current: base, turn: state.building.initiativeOrder.first.map { RunningEncounter.Turn(round: 1, combatantId: $0.id) })
                    state.running = re
                    // let's not use this until it's a setting
                    // state.building.runningEncounterKey = re.key
                case .stop:
                    state.running = nil
                    state.encounter.runningEncounterKey = nil
                    return .send(.resumableRunningEncounters(.startLoading))
                case .encounter(let a): // forward to the effective encounter
                    if state.running != nil {
                        return .send(.runningEncounter(.current(a)))
                    } else {
                        return .send(.buildingEncounter(a))
                    }
                case .buildingEncounter: break
                case .runningEncounter: break
                case .resumableRunningEncounters: break // handled below
                case .removeResumableRunningEncounter(let key):
                    return .run { send in
                        _ = try? env.database.keyValueStore.remove(key)
                        await send(.resumableRunningEncounters(.startLoading))
                    }
                case .sheet(let s):
                    state.sheet = s
                case .addCombatant(AddCombatantState.Action.onSelect(let combatants, let dismiss)):
                    var effects: [EffectTask<Action>] = combatants.map { combatant in
                        .send(.encounter(.add(combatant)))
                    }

                    if dismiss {
                        effects.append(
                            .run { send in
                                await Task.yield()
                                await send(.sheet(nil))
                            }
                        )
                    }

                    return .concatenate(effects)
                case .addCombatant: break // handled by AddCombatantState.reducer
                case .addCombatantAction(let action, let dismiss):
                    let state = state
                    return .run { send in
                        switch action {
                        case .add(let combatants):
                            for c in combatants {
                                await send(.encounter(.add(c)))
                            }
                        case .addByKey(let keys, let party):
                            for key in keys {
                                await send(.encounter(.addByKey(key, party)))
                            }
                        case .remove(let definitionID, let quantity):
                            for c in state.encounter.combatants(with: definitionID).reversed().prefix(quantity) {
                                await send(.encounter(.remove(c)))
                            }
                        }

                        if dismiss {
                            await send(.sheet(nil))
                        }
                    }
                case .combatantDetail(.combatant(let a)):
                    if let combatantDetailState = state.combatantDetailState {
                        return .send(.encounter(.combatant(combatantDetailState.combatant.id, a)))
                    }
                case .combatantDetail: break // handled by CombatantDetailFeature reducer
                case .popover(let p):
                    state.popover = p
                case .combatantInitiativePopover: break // handled above
                case .resetEncounter(let clearAll):
                    state.building.runningEncounterKey = nil
                    if clearAll {
                        state.building.combatants = []
                    } else {
                        state.building.combatants.removeAll { $0.party == nil && $0.definition.player == nil }
                    }

                    let runningEncounterPrefix = RunningEncounter.keyPrefix(for: state.building)
                    return .run { send in
                        // remove all runs
                        _ = try? env.database.keyValueStore.removeAll(.keyPrefix(runningEncounterPrefix.rawValue))
                        await send(.resumableRunningEncounters(.startLoading))
                    }
                case .editMode(let mode):
                    state.editMode = mode
                    if mode == .inactive {
                        state.selection.removeAll()
                    }
                case .selection(let s):
                    state.selection = s
                case .generateCombatantTraits(.onDoneButtonTap):
                    state.sheet = nil
                case .generateCombatantTraits: break // handled above
                case .selectionCombatantAction(let action):
                    return .merge(
                        state.selection.map {
                            .send(.encounter(.combatant($0, action)))
                        }
                    )
                case .selectionEncounterAction(let action):
                    let encounter = state.encounter
                    return .merge(
                        state.selection.compactMap { id -> EffectTask<Action>? in
                            guard let combatant = encounter.combatant(for: id) else { return nil }
                            switch action {
                            case .duplicate:
                                return .send(.encounter(.duplicate(combatant)))
                            case .remove:
                                return .send(.encounter(.remove(combatant)))
                            }
                        }
                    )
                case .selectedCombatantTags(.combatant(let c, let a)):
                    return .send(.encounter(.combatant(c.id, a)))
                case .selectedCombatantTags: break // handled below
                case .showCombatantDetailReferenceItem(let combatant):
                    let detailState = ReferenceItemViewState.Content.CombatantDetail(
                        encounter: state.encounter,
                        selectedCombatantId: combatant.id,
                        runningEncounter: state.running
                    )

                    state.combatantDetailReferenceItemRequest = ReferenceViewItemRequest(
                        id: state.combatantDetailReferenceItemRequest?.id ?? UUID().tagged(),
                        state: ReferenceItemViewState(content: .combatantDetail(detailState)),
                        oneOff: false
                    )
                case .showAddCombatantReferenceItem:
                    state.addCombatantReferenceItemRequest = ReferenceViewItemRequest(
                        id: state.addCombatantReferenceItemRequest?.id ?? UUID().tagged(),
                        state: ReferenceItemViewState(content: .addCombatant(ReferenceItemViewState.Content.AddCombatant(addCombatantState: AddCombatantState(encounter: state.encounter)))),
                        oneOff: false
                    )
                case .didDismissReferenceItem(let id):
                    if state.addCombatantReferenceItemRequest?.id == id {
                        state.addCombatantReferenceItemRequest = nil
                    } else if state.combatantDetailReferenceItemRequest?.id == id {
                        state.combatantDetailReferenceItemRequest = nil
                    }
                case .onGenerateCombatantTraitsButtonTap:
                    state.sheet = .generateCombatantTraits(.init(
                        encounter: state.encounter
                    ))
                case .onFeedbackButtonTap:
                    guard env.canSendMail() else { break }

                    let currentState = state
                    return .run { send in
                        try await Task.sleep(for: .seconds(0.1)) // delay for a bit so the menu has disappeared

                        let imageData = await MainActor.run {
                            env.screenshot()?.pngData()
                        }

                        env.sendMail(.init(
                            subject: "Encounter Feedback",
                            attachment: Array(builder: {
                                FeedbackMailContents.Attachment(customDump: currentState)

                                if let imageData {
                                    FeedbackMailContents.Attachment(data: imageData, mimeType: "image/png", fileName: "view.png")
                                }
                            })
                        ))
                    }
                }
                return .none
            },
            Encounter.reducer.pullback(
                state: \.building,
                action: /Action.buildingEncounter,
                environment: { $0 }
            ),
            RunningEncounter.reducer.optional().pullback(state: \.running, action: /Action.runningEncounter),
            AnyReducer.withState({ $0.building.id }) { state in
                AnyReducer { env in
                    AsyncResumableRunningEncounters {
                        do {
                            return try env.database.keyValueStore.fetchKeys(.keyPrefix(RunningEncounter.keyPrefix(for: state.building).rawValue))
                        } catch {
                            throw error.toEquatableError()
                        }
                    }
                }.pullback(state: \.resumableRunningEncounters, action: /Action.resumableRunningEncounters)
            },
            AnyReducer { env in
                CombatantDetailFeature(environment: env)
            }
            .optional().pullback(state: \.combatantDetailState, action: /Action.combatantDetail),
            CombatantTagsViewState.reducer.optional().pullback(state: \.selectedCombatantTagsState, action: /Action.selectedCombatantTags)
        )
    }
}

extension EncounterDetailViewState: NavigationStackItemState {
    var navigationStackItemStateId: String { encounter.rawKey }

    var navigationTitle: String { encounter.name }
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { .inline }
}

struct AddCombatantSheet: Identifiable, Equatable {
    let id: UUID
    var state: AddCombatantState

    init(id: UUID = UUID(), state: AddCombatantState) {
        self.id = id
        self.state = state
    }
}

extension AddCombatantSheet {
    static let nullInstance = AddCombatantSheet(state: AddCombatantState.nullInstance)
}

extension EncounterDetailViewState {
    static let nullInstance = EncounterDetailViewState(building: Encounter.nullInstance, isMechMuseEnabled: false)
}

struct EncounterDetailFeature: Reducer {
    typealias State = EncounterDetailViewState
    typealias Action = EncounterDetailViewState.Action

    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            EncounterDetailViewState.reducer.run(&state, action, environment)
        }
    }
}

typealias EncounterDetailViewAction = EncounterDetailViewState.Action
