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
    struct State: NavigationStackSourceState, Equatable {

        var runningEncounter: RunningEncounter?

        var combatant: Combatant {
            didSet {
                let c = combatant
                presentedNextCombatantTagsView?.update(c)
                presentedNextCombatantResourcesView?.combatant = c
            }
        }
        // entry is loaded if the combatant is a CompendiumCombatant
        var entry: CompendiumEntry?

        var popover: Popover?
        var alert: AlertState<Action>?

        var presentedScreens: [NavigationDestination: NextScreen] = [:]

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
            res.presentedScreens = presentedScreens.mapValues {
                switch $0 {
                case .combatantTagsView: return .combatantTagsView(CombatantTagsFeature.State.nullInstance)
                case .combatantTagEditView: return .combatantTagEditView(CombatantTagEditFeature.State.nullInstance)
                case .creatureEditView: return .creatureEditView(CreatureEditFeature.State.nullInstance)
                case .combatantResourcesView: return .combatantResourcesView(CombatantResourcesFeature.State.nullInstance)
                case .runningEncounterLogView: return .runningEncounterLogView(RunningEncounterLogViewState.nullInstance)
                case .compendiumItemDetailView: return .compendiumItemDetailView(CompendiumEntryDetailFeature.State(entry: CompendiumEntry.nullInstance))
                case .safariView: return .safariView(.nullInstance)
                }
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

        enum NextScreen: Equatable {
            case combatantTagsView(CombatantTagsFeature.State)
            case combatantTagEditView(CombatantTagEditFeature.State)
            case creatureEditView(CreatureEditFeature.State)
            case combatantResourcesView(CombatantResourcesFeature.State)
            case runningEncounterLogView(RunningEncounterLogViewState)
            case compendiumItemDetailView(CompendiumEntryDetailFeature.State)
            case safariView(SafariViewState)
        }

        enum Popover: Equatable {
            case healthAction(HealthDialogFeature.State)
            case initiative(NumberEntryFeature.State)
            case rollCheck(DiceCalculator.State)
            case diceAction(ActionResolutionFeature.State)
            case tagDetails(CombatantTag)
            case addLimitedResource(CombatantTrackerEditFeature.State)
        }
    }

    enum Action: NavigationStackSourceAction, Equatable {
        case onAppear
        case combatant(CombatantAction)
        case popover(State.Popover?)
        case alert(AlertState<Self>?)
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

        case setNextScreen(State.NextScreen?)
        case nextScreen(NextScreenAction)
        case setDetailScreen(State.NextScreen?)
        case detailScreen(NextScreenAction)

        static func presentScreen(_ destination: NavigationDestination, _ screen: State.NextScreen?) -> Self {
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
            case combatantTagsView(CombatantTagsFeature.Action)
            case combatantTagEditView(CombatantTagEditFeature.Action)
            case creatureEditView(CreatureEditFeature.Action)
            case combatantResourcesView(CombatantResourcesFeature.Action)
            case runningEncounterLogView
            case compendiumItemDetailView(CompendiumEntryDetailFeature.Action)
            case safariView
        }
    }

    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if let def = state.combatant.definition as? CompendiumCombatantDefinition {
                    state.entry = try? environment.compendium.get(def.item.key)
                }
            case .combatant: break // should be handled by parent
            case .popover(let popover):
                state.popover = popover
            case .alert(let alert):
                state.alert = alert
            case .addLimitedResource(.onDoneTap):
                guard case .addLimitedResource(let editState) = state.popover else { return .none }
                return .run { send in
                    environment.dismissKeyboard()
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
                    return .send(.setNextScreen(.creatureEditView(CreatureEditFeature.State(edit: def))))
                }

                if state.combatant.definition is CompendiumCombatantDefinition {
                    state.alert = AlertState(
                        title: TextState("Detach Combatant to Edit"),
                        message: TextState("This combatant needs to be detached from the compendium to make changes just for this encounter."),
                        primaryButton: .default(
                            TextState("Detach & Edit"),
                            action: .send(.unlinkAndEditCreature)
                        ),
                        secondaryButton: .cancel(
                            TextState("Cancel")
                        )
                    )
                }
            case .saveToCompendium:
                guard let def = state.combatant.definition as? AdHocCombatantDefinition else { return .none }

                let item: CompendiumCombatant
                if def.isUnique {
                    item = Character(id: UUID().tagged(), realm: .init(CompendiumRealm.homebrew.id), level: def.level, stats: def.stats, player: def.player)
                } else {
                    item = Monster(realm: .init(CompendiumRealm.homebrew.id), stats: def.stats, challengeRating: def.stats.challengeRating ?? Fraction(integer: 0))
                }

                let entry = CompendiumEntry(
                    item,
                    origin: .created(def.original),
                    document: .init(CompendiumSourceDocument.homebrew)
                )
                try? environment.compendium.put(entry)
                state.entry = entry
                return .send(.combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: CompendiumCombatantDefinition(item: item, persistent: false)))))
            case .unlinkFromCompendium:
                let currentDefinition = state.combatant.definition

                let original = (currentDefinition as? CompendiumCombatantDefinition).map { CompendiumItemReference(itemTitle: $0.name, itemKey: $0.item.key) }
                let definition = AdHocCombatantDefinition(id: UUID().tagged(), stats: currentDefinition.stats, player: currentDefinition.player, level: currentDefinition.level, original: original)
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
            case .setNextScreen(let next):
                state.presentedScreens[.nextInStack] = next
            case .setDetailScreen(let next):
                state.presentedScreens[.detail] = next
            case .nextScreen(.combatantTagsView(.combatant(let combatant, let combatantAction))):
                guard combatant.id == state.combatant.id else { return .none }
                // bubble-up action
                return .send(.combatant(combatantAction))
            case .nextScreen(.combatantResourcesView(.combatant(let combatantAction))):
                // bubble-up action
                return .send(.combatant(combatantAction))
            case .nextScreen(.combatantTagEditView(.onDoneTap)):
                let tag = state.presentedNextCombatantTagEditView?.tag
                state.nextScreen = nil

                if let tag {
                    return .send(.combatant(.addTag(tag)))
                }
            case .nextScreen(.creatureEditView(.didEdit(let result))):
                if case let .adHoc(definition) = result {
                    return .merge(
                        .send(.setNextScreen(nil)),
                        .send(.combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: definition))))
                    )
                }
                return .none
            case .nextScreen, .detailScreen: break // handled by reducers below
            }
            return .none
        }
        .ifLet(\.presentedNextCombatantTagEditView, action: /Action.nextScreen..Action.NextScreenAction.combatantTagEditView) {
            CombatantTagEditFeature(environment: environment)
        }
        .ifLet(\.rollCheckDialogState, action: /Action.rollCheckDialog) {
            DiceCalculator(environment: environment)
        }
        .ifLet(\.diceActionPopoverState, action: /Action.diceActionPopover) {
            ActionResolutionFeature(environment: environment)
        }
        .ifLet(\.initiativePopoverState, action: /Action.initiativePopover) {
            NumberEntryFeature(environment: environment)
        }
        .ifLet(\.presentedNextCompendiumItemDetailView, action: /Action.nextScreen..Action.NextScreenAction.compendiumItemDetailView) {
            CompendiumEntryDetailFeature(environment: environment)
        }
        .ifLet(\.presentedNextCombatantTagsView, action: /Action.nextScreen..Action.NextScreenAction.combatantTagsView) {
            CombatantTagsFeature(environment: environment)
        }
        .ifLet(\.presentedNextCombatantResourcesView, action: /Action.nextScreen..Action.NextScreenAction.combatantResourcesView) {
            CombatantResourcesFeature(environment: environment)
        }
        .ifLet(\.presentedNextCreatureEditView, action: /Action.nextScreen..Action.NextScreenAction.creatureEditView) {
            CreatureEditFeature()
        }
        .ifLet(\.addLimitedResourceState, action: /Action.addLimitedResource) {
            CombatantTrackerEditFeature(environment: environment)
        }
        .ifLet(\.healthDialogState, action: /Action.healthDialog) {
            HealthDialogFeature(environment: environment)
        }

        CompendiumItemReferenceTextAnnotation.handleTapReducer(
            didTapAction: /Action.didTapCompendiumItemReferenceTextAnnotation,
            requestItem: \.itemRequest,
            internalAction: /Action.setNextScreen..State.NextScreen.compendiumItemDetailView,
            externalAction: /Action.setNextScreen..State.NextScreen.safariView,
            environment: environment
        )
    }
}

extension CombatantDetailFeature.State {
    static let nullInstance = CombatantDetailFeature.State(combatant: Combatant.nullInstance)
}

extension CompendiumItemReferenceTextAnnotation {
    typealias HandleTapReducerEnvironment = EnvironmentWithCompendium & EnvironmentWithCrashReporter

    static func handleTapReducer<State, Action>(
        didTapAction: CasePath<Action, (CompendiumItemReferenceTextAnnotation, AppNavigation)>,
        requestItem: WritableKeyPath<State, ReferenceViewItemRequest?>,
        internalAction: CasePath<Action, CompendiumEntryDetailFeature.State>,
        externalAction: CasePath<Action, SafariViewState>,
        environment env: HandleTapReducerEnvironment
    ) -> some Reducer<State, Action> {
        Reduce { state, action in
            if let (annotation, appNavigation) = didTapAction.extract(from: action) {
                switch env.compendium.resolve(annotation: annotation) {
                case .internal(let reference):
                    if let entry = try? env.compendium.get(reference.itemKey, crashReporter: env.crashReporter) {
                        let detailState = CompendiumEntryDetailFeature.State(entry: entry)
                        switch appNavigation {
                        case .column:
                            state[keyPath: requestItem] = ReferenceViewItemRequest(
                                id: UUID().tagged(),
                                state: ReferenceItem.State(content: .compendiumItem(detailState)),
                                oneOff: true
                            )
                        case .tab: return .send(internalAction.embed(detailState))
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
                    case .tab: return .send(externalAction.embed(externalState))
                    }
                case .notFound: break
                }
            }
            return .none
        }
    }
}
