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

    typealias ResumableRunningEncounters = Async<[KeyValueStore.Record], Error>
    var resumableRunningEncounters: ResumableRunningEncounters = .initial

    var sheet: Sheet?
    var popover: Popover?

    var editMode: EditMode = .inactive
    var selection = Set<Combatant.Id>()

    var isMechMuseEnabled: Bool

    public init(
        building: Encounter,
        running: RunningEncounter? = nil,
        resumableRunningEncounters: ResumableRunningEncounters = .initial,
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

    var combatantDetailState: CombatantDetailViewState? {
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

    var combatantInitiativePopover: NumberEntryViewState? {
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
            case .combatant: return .combatant(CombatantDetailViewState.nullInstance)
            case .runningEncounterLog: return .runningEncounterLog(RunningEncounterLogViewState.nullInstance)
            case .selectedCombatantTags: return .selectedCombatantTags(CombatantTagsViewState.nullInstance)
            case .settings: return .settings
            case .generateCombatantTraits: return .generateCombatantTraits(GenerateCombatantTraitsViewState.nullInstance)
            }
        }

        res.popover = popover.map {
            switch $0 {
            case .encounterInitiative: return .encounterInitiative
            case .combatantInitiative: return .combatantInitiative(Combatant.nullInstance, NumberEntryViewState.nullInstance)
            case .health: return .health(.single(Combatant.nullInstance))
            }
        }

        return res
    }

    enum Sheet: Equatable {
        case add(AddCombatantSheet)
        case combatant(CombatantDetailViewState)
        case runningEncounterLog(RunningEncounterLogViewState)
        case selectedCombatantTags(CombatantTagsViewState)
        case settings
        case generateCombatantTraits(GenerateCombatantTraitsViewState)
    }

    enum Popover: Equatable {
        case encounterInitiative
        case combatantInitiative(Combatant, NumberEntryViewState)
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
        case combatantInitiativePopover(NumberEntryViewAction)
        case addCombatant(AddCombatantState.Action)
        case addCombatantAction(AddCombatantView.Action, Bool)
        case combatantDetail(CombatantDetailViewAction)
        case resumableRunningEncounters(ResumableRunningEncounters.Action)
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

    static var reducer: Reducer<EncounterDetailViewState, Action, Environment> {
        return Reducer.combine(
            AddCombatantState.reducer.optional().pullback(state: \.addCombatantState, action: /Action.addCombatant),
            NumberEntryViewState.reducer.optional().pullback(state: \.combatantInitiativePopover, action: /Action.combatantInitiativePopover, environment: { $0 }),
            GenerateCombatantTraitsViewState.reducer.optional().pullback(state: \.generateCombatantTraitsState, action: /Action.generateCombatantTraits, environment: { $0 }),
            Reducer { state, action, env in
                switch action {
                case .onAppear:
                    var actions: [Action] = [.buildingEncounter(.refreshCompendiumItems)]
                    if state.resumableRunningEncounters.result == nil {
                        actions.insert(.resumableRunningEncounters(.startLoading), at: 0)
                    }

                    return actions.publisher.eraseToEffect()
                case .onResumeRunningEncounterTap(let resumableKey):
                    return Effect.future { callback in
                        do {
                            if let runningEncounter: RunningEncounter = try env.database.keyValueStore.get(
                                resumableKey,
                                crashReporter: env.crashReporter
                            ) {
                                callback(.success(.run(runningEncounter)))
                            } else {
                                assertionFailure("Could not resume run: \(resumableKey) not found")
                                callback(.success(nil))
                            }
                        } catch {
                            assertionFailure("Could not resume run: \(error)")
                            callback(.success(nil))
                        }
                    }.compactMap { $0 }.receive(on: env.mainQueue.animation()).eraseToEffect()
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
                    return Effect(value: .resumableRunningEncounters(.startLoading))
                case .encounter(let a): // forward to the effective encounter
                    if state.running != nil {
                        return Effect(value: .runningEncounter(.current(a)))
                    } else {
                        return Effect(value: .buildingEncounter(a))
                    }
                case .buildingEncounter: break
                case .runningEncounter: break
                case .resumableRunningEncounters: break // handled below
                case .removeResumableRunningEncounter(let key):
                    return Effect.future { callback in
                        _ = try? env.database.keyValueStore.remove(key)
                        callback(.success(.resumableRunningEncounters(.startLoading)))
                    }
                case .sheet(let s):
                    state.sheet = s
                case .addCombatant(AddCombatantState.Action.onSelect(let combatants, let dismiss)):
                    return combatants.map { c in
                        .encounter(.add(c))
                    }.publisher.append(
                        // Async is needed if this action also dismissed a
                        dismiss
                            ? Just(Action.sheet(nil)).delay(for: 0, scheduler: env.mainQueue).eraseToAnyPublisher()
                            : Empty().eraseToAnyPublisher()
                    ).eraseToEffect()
                case .addCombatant: break // handled by AddCombatantState.reducer
                case .addCombatantAction(let action, let dismiss):
                    let state = state
                    return Effect.run { subscriber in
                        switch action {
                        case .add(let combatants):
                            for c in combatants {
                                subscriber.send(.encounter(.add(c)))
                            }
                        case .addByKey(let keys, let party):
                            for key in keys {
                                subscriber.send(.encounter(.addByKey(key, party)))
                            }
                        case .remove(let definitionID, let quantity):
                            for c in state.encounter.combatants(with: definitionID).reversed().prefix(quantity) {
                                subscriber.send(.encounter(.remove(c)))
                            }
                        }

                        if dismiss {
                            subscriber.send(.sheet(nil))
                        }
                        subscriber.send(completion: .finished)
                        return AnyCancellable { }
                    }
                case .combatantDetail(.combatant(let a)):
                    if let combatantDetailState = state.combatantDetailState {
                        return Effect(value: .encounter(.combatant(combatantDetailState.combatant.id, a)))
                    }
                case .combatantDetail: break // handled by CombatantDetailViewState.reducer
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
                    return Effect.future { callback in
                        // remove all runs
                        _ = try? env.database.keyValueStore.removeAll(runningEncounterPrefix.rawValue)
                        callback(.success(.resumableRunningEncounters(.startLoading)))
                    }
                case .editMode(let mode):
                    state.editMode = mode
                    if mode == .inactive {
                        state.selection.removeAll()
                    }
                case .selection(let s):
                    state.selection = s
                case .generateCombatantTraits(.onCancelButtonTap):
                    state.sheet = nil
                case .generateCombatantTraits(.onDoneButtonTap):
                    guard let childState = state.generateCombatantTraitsState else { break }
                    for (id, c) in childState.traits {
                        state.encounter.combatants[id: id]?.traits = c
                    }

                    state.sheet = nil
                case .generateCombatantTraits: break // handled above
                case .selectionCombatantAction(let action):
                    return state.selection.map {
                        .encounter(.combatant($0, action))
                    }.publisher.eraseToEffect()
                case .selectionEncounterAction(let action):
                    let encounter = state.encounter
                    return state.selection.compactMap {
                        guard let combatant = encounter.combatant(for: $0) else { return nil }
                        switch action {
                        case .duplicate:
                            return .encounter(.duplicate(combatant))
                        case .remove:
                            return .encounter(.remove(combatant))
                        }
                    }.publisher.eraseToEffect()
                case .selectedCombatantTags(.combatant(let c, let a)):
                    return Effect(value: .encounter(.combatant(c.id, a)))
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
                        encounter: state.encounter,
                        isMechMuseConfigured: env.preferences().mechMuse.apiKey != nil
                    ))
                case .onFeedbackButtonTap:
                    guard env.canSendMail() else { break }

                    let currentState = state
                    return Effect.run(operation: { @MainActor send in
                        try await Task.sleep(for: .seconds(0.1)) // delay for a bit so the menu has disappeared

                        env.sendMail(.init(
                            subject: "Encounter Feedback",
                            attachment: Array(builder: {
                                FeedbackMailContents.Attachment(customDump: currentState)

                                if let imageData = env.screenshot()?.pngData() {
                                    FeedbackMailContents.Attachment(data: imageData, mimeType: "image/png", fileName: "view.png")
                                }
                            })
                        ))
                    })
                }
                return .none
            },
            Encounter.reducer.pullback(state: \.building, action: /Action.buildingEncounter),
            RunningEncounter.reducer.optional().pullback(state: \.running, action: /Action.runningEncounter),
            Reducer.withState({ $0.building.id }) { state in
                ResumableRunningEncounters.reducer { env in
                    do {
                        let nodes = try env.database.keyValueStore.fetchAllRaw(RunningEncounter.keyPrefix(for: state.building).rawValue)
                        return Just(nodes).setFailureType(to: Error.self).eraseToAnyPublisher()
                    } catch {
                        return Fail(error: error).eraseToAnyPublisher()
                    }
                }.pullback(state: \.resumableRunningEncounters, action: /Action.resumableRunningEncounters)
            },
            CombatantDetailViewState.reducer.optional().pullback(state: \.combatantDetailState, action: /Action.combatantDetail),
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
