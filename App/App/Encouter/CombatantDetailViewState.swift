//
//  CombatantDetailViewState.swift
//  Construct
//
//  Created by Thomas Visser on 22/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SwiftUI
import Combine
import ComposableArchitecture
import Helpers
import DiceRollerFeature
import GameModels
import ActionResolutionFeature
import Compendium

struct CombatantDetailFeature: Reducer {
    @ObservableState
    struct State: Equatable {

        var runningEncounter: RunningEncounter?

        var combatant: Combatant {
            didSet {
                updateChildDestinations(for: combatant)
            }
        }
        // entry is loaded if the combatant is a CompendiumCombatant
        var entry: CompendiumEntry?

        var popover: Popover?
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var destination: Destination.State?
        var safari: SafariViewState?

        init(
            runningEncounter: RunningEncounter? = nil,
            combatant: Combatant,
            entry: CompendiumEntry? = nil,
            popover: Popover? = nil,
            alert: AlertState<Action.Alert>? = nil,
            destination: Destination.State? = nil,
            safari: SafariViewState? = nil,
            itemRequest: ReferenceViewItemRequest? = nil
        ) {
            self.runningEncounter = runningEncounter
            self.combatant = combatant
            self.entry = entry
            self.popover = popover
            self._alert = .init(wrappedValue: alert)
            self._destination = .init(wrappedValue: destination)
            self.safari = safari
            self.itemRequest = itemRequest
        }

        var navigationStackItemStateId: String {
            combatant.id.rawValue.uuidString
        }

        var navigationTitle: String { combatant.discriminatedName }
        var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { .inline }

        var itemRequest: ReferenceViewItemRequest?

        var attribution: AttributedString? {
            if let entry, let attribution = entry.attribution {
                var res = attribution
                // Process the attributed string to convert annotations to links
                StatBlockView.process(attributedString: &res)
                return res
            } else if let def = combatant.definition as? AdHocCombatantDefinition, let original = def.original {
                // Build attributed string that makes the item title tappable
                var res = AttributedString("Based on “")
                res.append(original.attributedTitle)
                res.append(AttributedString("”"))

                // Process the attributed string to convert annotations to links
                StatBlockView.process(attributedString: &res)
                return res
            }
            return nil
        }

        var addLimitedResourceState: CombatantTrackerEditFeature.State? {
            get {
                guard case .addLimitedResource(let state) = popover else { return nil }
                return state
            }
            set {
                if let newValue = newValue {
                    popover = .addLimitedResource(newValue)
                }
            }
        }

        var healthDialogState: HealthDialogFeature.State? {
            get {
                guard case .healthAction(let state) = popover else { return nil }
                return state
            }
            set {
                if let newValue = newValue {
                    popover = .healthAction(newValue)
                }
            }
        }

        var rollCheckDialogState: DiceCalculator.State? {
            get {
                guard case .rollCheck(let state) = popover else { return nil }
                return state
            }
            set {
                if let newValue = newValue {
                    popover = .rollCheck(newValue)
                }
            }
        }

        var diceActionPopoverState: ActionResolutionFeature.State? {
            get {
                guard case .diceAction(let state) = popover else { return nil }
                return state
            }
            set {
                if let newValue = newValue {
                    popover = .diceAction(newValue)
                }
            }
        }

        var initiativePopoverState: NumberEntryFeature.State? {
            get {
                guard case .initiative(let state) = popover else { return nil }
                return state
            }
            set {
                if let newValue = newValue {
                    popover = .initiative(newValue)
                }
            }
        }

        var localStateForDeduplication: Self {
            var res = self
            if let destination {
                res.destination = destination.nullInstance
            }
            if safari != nil {
                res.safari = .nullInstance
            }
            res.popover = popover.map {
                switch $0 {
                case .healthAction: return .healthAction(HealthDialogFeature.State.nullInstance)
                case .initiative: return .initiative(NumberEntryFeature.State.nullInstance)
                case .rollCheck: return .rollCheck(DiceCalculator.State.nullInstance)
                case .diceAction: return .diceAction(ActionResolutionFeature.State.nullInstance)
                case .tagDetails: return .tagDetails(CombatantTag.nullInstance)
                case .addLimitedResource: return .addLimitedResource(CombatantTrackerEditFeature.State.nullInstance)
                }
            }
            return res
        }

        enum Popover: Equatable {
            case healthAction(HealthDialogFeature.State)
            case initiative(NumberEntryFeature.State)
            case rollCheck(DiceCalculator.State)
            case diceAction(ActionResolutionFeature.State)
            case tagDetails(CombatantTag)
            case addLimitedResource(CombatantTrackerEditFeature.State)
        }

        var currentTagEditState: CombatantTagEditFeature.State? {
            get {
                guard case let .combatantTagEditView(state)? = destination else { return nil }
                return state
            }
        }

        mutating func updateChildDestinations(for combatant: Combatant) {
            guard let destination else { return }
            switch destination {
            case var .combatantTagsView(state):
                state.update(combatant)
                self.destination = .combatantTagsView(state)
            case var .combatantResourcesView(state):
                state.combatant = combatant
                self.destination = .combatantResourcesView(state)
            default:
                break
            }
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case combatant(CombatantAction)
        case popover(State.Popover?)
        case alert(PresentationAction<Alert>)
        case addLimitedResource(CombatantTrackerEditFeature.Action)
        case healthDialog(HealthDialogFeature.Action)
        case rollCheckDialog(DiceCalculator.Action)
        case diceActionPopover(ActionResolutionFeature.Action)
        case initiativePopover(NumberEntryFeature.Action)
        case editCreatureConfirmingUnlinkIfNeeded
        case saveToCompendium
        case unlinkFromCompendium
        case unlinkAndEditCreature

        case didTapCompendiumItemReferenceTextAnnotation(CompendiumItemReferenceTextAnnotation, AppNavigation)

        case setDestination(Destination.State?)
        case destination(PresentationAction<Destination.Action>)
        case setSafari(SafariViewState?)

        enum Alert: Equatable {
            case unlinkAndEditCreature
        }
    }

    @Reducer
    enum Destination {
        case combatantTagsView(CombatantTagsFeature)
        case combatantTagEditView(CombatantTagEditFeature)
        case creatureEditView(CreatureEditFeature)
        case combatantResourcesView(CombatantResourcesFeature)
        case runningEncounterLogView(EmptyReducer<RunningEncounterLogViewState, RunningEncounterLogViewAction>)
        case compendiumItemDetailView(CompendiumEntryDetailFeature)
    }

    @Dependency(\.compendium) var compendium
    @Dependency(\.keyboard) var keyboard
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        mainReducer
        tapHandlingReducer
    }

    private var mainReducer: some ReducerOf<Self> {
        Reduce(self.reduce)
            .ifLet(\.$destination, action: \.destination)
            .ifLet(\.rollCheckDialogState, action: \.rollCheckDialog) {
                DiceCalculator()
            }
            .ifLet(\.diceActionPopoverState, action: \.diceActionPopover) {
                ActionResolutionFeature()
            }
            .ifLet(\.initiativePopoverState, action: \.initiativePopover) {
                NumberEntryFeature()
            }
            .ifLet(\.addLimitedResourceState, action: \.addLimitedResource) {
                CombatantTrackerEditFeature()
            }
            .ifLet(\.healthDialogState, action: \.healthDialog) {
                HealthDialogFeature()
            }
    }

    private var tapHandlingReducer: some ReducerOf<Self> {
        CompendiumItemReferenceTextAnnotation.handleTapReducer(
            didTapAction: { action in
                guard case let .didTapCompendiumItemReferenceTextAnnotation(annotation, navigation) = action else {
                    return nil
                }
                return (annotation, navigation)
            },
            requestItem: \.itemRequest,
            internalAction: { .setDestination(.compendiumItemDetailView($0)) },
            externalAction: { .setSafari($0) }
        )
    }

    private func reduce(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            if let def = state.combatant.definition as? CompendiumCombatantDefinition {
                state.entry = try? compendium.get(def.item.key)
            }
        case .combatant: break // should be handled by parent
        case .popover(let popover):
            state.popover = popover
        case .alert(.presented(.unlinkAndEditCreature)):
            state.alert = nil
            return .send(.unlinkAndEditCreature)
        case .alert(.dismiss):
            state.alert = nil
        case .addLimitedResource(.onDoneTap):
            guard case .addLimitedResource(let editState) = state.popover else { return .none }
            return .run { send in
                keyboard.dismissKeyboard()
                await send(.popover(nil))
                await send(.combatant(.addResource(editState.resource)))
            }
        case .addLimitedResource: break // handled below
        case .healthDialog: break // handled below
        case .rollCheckDialog: break // handled above
        case .diceActionPopover: break // handled above
        case .initiativePopover: break // handled above
        case .editCreatureConfirmingUnlinkIfNeeded:
            if let def = state.combatant.definition as? AdHocCombatantDefinition {
                return .send(.setDestination(.creatureEditView(CreatureEditFeature.State(edit: def))))
            }

            if state.combatant.definition is CompendiumCombatantDefinition {
                state.alert = AlertState {
                    TextState("Detach Combatant to Edit")
                } actions: {
                    ButtonState(action: .unlinkAndEditCreature) {
                        TextState("Detach & Edit")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This combatant needs to be detached from the compendium to make changes just for this encounter.")
                }
            }
        case .saveToCompendium:
            guard let def = state.combatant.definition as? AdHocCombatantDefinition else { return .none }

            let item: CompendiumCombatant
            if def.isUnique {
                item = Character(id: uuid().tagged(), realm: .init(CompendiumRealm.homebrew.id), level: def.level, stats: def.stats, player: def.player)
            } else {
                item = Monster(realm: .init(CompendiumRealm.homebrew.id), stats: def.stats, challengeRating: def.stats.challengeRating ?? Fraction(integer: 0))
            }
            _ = item
        case .unlinkFromCompendium:
            let currentDefinition = state.combatant.definition

            let original = (currentDefinition as? CompendiumCombatantDefinition).map { CompendiumItemReference(itemTitle: $0.name, itemKey: $0.item.key) }
            let definition = AdHocCombatantDefinition(id: uuid().tagged(), stats: currentDefinition.stats, player: currentDefinition.player, level: currentDefinition.level, original: original)
            state.entry = nil
            return .send(.combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: definition))))
        case .unlinkAndEditCreature:
            return .merge(
                .send(.unlinkFromCompendium),
                .run { send in
                    await Task.yield()
                    await send(.editCreatureConfirmingUnlinkIfNeeded)
                }
            )
        case .didTapCompendiumItemReferenceTextAnnotation: break // handled by CompendiumItemReferenceTextAnnotation.handleTapReducer
        case .setDestination(let destination):
            state.destination = destination
        case .destination(.presented(.combatantTagsView(.combatant(let combatant, let combatantAction)))):
            guard combatant.id == state.combatant.id else { return .none }
            // bubble-up action
            return .send(.combatant(combatantAction))
        case .destination(.presented(.combatantResourcesView(.combatant(let combatantAction)))):
            // bubble-up action
            return .send(.combatant(combatantAction))
        case .destination(.presented(.combatantTagEditView(.onDoneTap))):
            let tag = state.currentTagEditState?.tag
            state.destination = nil

            if let tag {
                return .send(.combatant(.addTag(tag)))
            }
        case .destination(.presented(.creatureEditView(.didEdit(let result)))):
            if case let .adHoc(definition) = result {
                return .merge(
                    .send(.setDestination(nil)),
                    .send(.combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: definition))))
                )
            }
            return .none
        case .destination:
            break
        case .setSafari(let safari):
            state.safari = safari
        }
        return .none
    }
}

extension CombatantDetailFeature.State {
    static let nullInstance = CombatantDetailFeature.State(combatant: Combatant.nullInstance)
}

extension CombatantDetailFeature.State: DestinationTreeNode {}

extension CombatantDetailFeature.Destination.State {
    var nullInstance: CombatantDetailFeature.Destination.State {
        switch self {
        case .combatantTagsView:
            return .combatantTagsView(.nullInstance)
        case .combatantTagEditView:
            return .combatantTagEditView(.nullInstance)
        case .creatureEditView:
            return .creatureEditView(.nullInstance)
        case .combatantResourcesView:
            return .combatantResourcesView(.nullInstance)
        case .runningEncounterLogView:
            return .runningEncounterLogView(.nullInstance)
        case .compendiumItemDetailView:
            return .compendiumItemDetailView(CompendiumEntryDetailFeature.State(entry: CompendiumEntry.nullInstance))
        }
    }
}

extension CombatantDetailFeature.Destination.State: Equatable {}
extension CombatantDetailFeature.Destination.Action: Equatable {}

extension CombatantDetailFeature.Destination.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        switch self {
        case .combatantTagsView(let state):
            return state.navigationNodes
        case .combatantTagEditView(let state):
            return state.navigationNodes
        case .creatureEditView(let state):
            return state.navigationNodes
        case .combatantResourcesView(let state):
            return state.navigationNodes
        case .runningEncounterLogView(let state):
            return state.navigationNodes
        case .compendiumItemDetailView(let state):
            return state.navigationNodes
        }
    }
}

extension CompendiumItemReferenceTextAnnotation {
    static func handleTapReducer<State, Action>(
        didTapAction: @escaping (Action) -> (CompendiumItemReferenceTextAnnotation, AppNavigation)?,
        requestItem: WritableKeyPath<State, ReferenceViewItemRequest?>,
        internalAction: @escaping (CompendiumEntryDetailFeature.State) -> Action,
        externalAction: @escaping (SafariViewState) -> Action
    ) -> some Reducer<State, Action> {
        Reduce<State, Action> { state, action in
            @Dependency(\.compendium) var compendium
            @Dependency(\.crashReporter) var crashReporter
            
            if let (annotation, appNavigation) = didTapAction(action) {
                switch compendium.resolve(annotation: annotation) {
                case .internal(let reference):
                    if let entry = try? compendium.get(reference.itemKey, crashReporter: crashReporter) {
                        let detailState = CompendiumEntryDetailFeature.State(entry: entry)
                        switch appNavigation {
                        case .column:
                            state[keyPath: requestItem] = ReferenceViewItemRequest(
                                id: UUID().tagged(),
                                state: ReferenceItem.State(content: .compendiumItem(detailState)),
                                oneOff: true
                            )
                        case .tab: return .send(internalAction(detailState))
                        }
                    }
                case .external(let url):
                    let externalState = SafariViewState(url: url)
                    switch appNavigation {
                    case .column:
                        state[keyPath: requestItem] = ReferenceViewItemRequest(
                            id: UUID().tagged(),
                            state: ReferenceItem.State(content: .safari(externalState)),
                            oneOff: true
                        )
                    case .tab: return .send(externalAction(externalState))
                    }
                case .notFound: break
                }
            }
            return .none
        }
    }
}
