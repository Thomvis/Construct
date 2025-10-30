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
import CasePaths
import Helpers
import DiceRollerFeature
import GameModels
import ActionResolutionFeature
import Compendium

struct CombatantDetailFeature: Reducer {

    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

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

        var addLimitedResourceState: CombatantTrackerEditViewState? {
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
                case .combatantTagsView: return .combatantTagsView(CombatantTagsViewState.nullInstance)
                case .combatantTagEditView: return .combatantTagEditView(CombatantTagEditViewState.nullInstance)
                case .creatureEditView: return .creatureEditView(CreatureEditFeature.State.nullInstance)
                case .combatantResourcesView: return .combatantResourcesView(CombatantResourcesViewState.nullInstance)
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
                case .addLimitedResource: return .addLimitedResource(CombatantTrackerEditViewState.nullInstance)
                }
            }
            return res
        }

        enum NextScreen: Equatable {
            case combatantTagsView(CombatantTagsViewState)
            case combatantTagEditView(CombatantTagEditViewState)
            case creatureEditView(CreatureEditFeature.State)
            case combatantResourcesView(CombatantResourcesViewState)
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
            case addLimitedResource(CombatantTrackerEditViewState)
        }
    }

    enum Action: NavigationStackSourceAction, Equatable {
        case onAppear
        case combatant(CombatantAction)
        case popover(State.Popover?)
        case alert(AlertState<Self>?)
        case addLimitedResource(CombatantTrackerEditViewAction)
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
            case combatantTagsView(CombatantTagsViewAction)
            case combatantTagEditView(CombatantTagEditViewAction)
            case creatureEditView(CreatureEditFeature.Action)
            case combatantResourcesView(CombatantResourcesViewAction)
            case runningEncounterLogView
            case compendiumItemDetailView(CompendiumEntryDetailFeature.Action)
            case safariView
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            Self.legacyReducer.run(&state, action, environment)
        }
    }

    static let legacyReducer: AnyReducer<State, Action, Environment> = AnyReducer.combine(
        CombatantTagEditViewState.reducer.optional().pullback(state: \.presentedNextCombatantTagEditView, action: /Action.nextScreen..Action.NextScreenAction.combatantTagEditView),
        AnyReducer { env in
            DiceCalculator(environment: env)
        }
        .optional()
        .pullback(
            state: \.rollCheckDialogState,
            action: /Action.rollCheckDialog,
            environment: { $0 }
        ),
        AnyReducer { env in
            ActionResolutionFeature(environment: env)
        }
        .optional()
        .pullback(
            state: \.diceActionPopoverState,
            action: /Action.diceActionPopover,
            environment: { $0 }
        ),
        AnyReducer { env in
            NumberEntryFeature(environment: env)
        }
        .optional()
        .pullback(state: \.initiativePopoverState, action: /Action.initiativePopover, environment: { $0 }),
        AnyReducer { env in
            CompendiumEntryDetailFeature(environment: env)
        }
        .optional()
        .pullback(state: \.presentedNextCompendiumItemDetailView, action: /Action.nextScreen..Action.NextScreenAction.compendiumItemDetailView, environment: { $0 }),
        AnyReducer { state, action, env in
            switch action {
            case .onAppear:
                if let def = state.combatant.definition as? CompendiumCombatantDefinition {
                    state.entry = try? env.compendium.get(def.item.key)
                }
            case .combatant: break // should be handled by parent
            case .popover(let popover):
                state.popover = popover
            case .alert(let alert):
                state.alert = alert
            case .addLimitedResource(.onDoneTap):
                guard case .addLimitedResource(let editState) = state.popover else { return .none }
                return .run { send in
                    env.dismissKeyboard()
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
                    return EffectTask(value: .setNextScreen(.creatureEditView(CreatureEditFeature.State(edit: def))))
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
                try? env.compendium.put(entry)
                state.entry = entry
                return .send(.combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: CompendiumCombatantDefinition(item: item, persistent: false)))))
            case .unlinkFromCompendium:
                let currentDefinition = state.combatant.definition

                let original = (currentDefinition as? CompendiumCombatantDefinition).map { CompendiumItemReference(itemTitle: $0.name, itemKey: $0.item.key) }
                let definition = AdHocCombatantDefinition(id: UUID().tagged(), stats: currentDefinition.stats, player: currentDefinition.player, level: currentDefinition.level, original: original)
                state.entry = nil
                return .send(.combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: definition))))
            case .unlinkAndEditCreature:
                return .concatenate(
                    [
                        .send(.unlinkFromCompendium),
                        .run { send in
                            await Task.yield()
                            await send(.editCreatureConfirmingUnlinkIfNeeded)
                        }
                    ]
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
                    return .concatenate(
                        [
                            .send(.setNextScreen(nil)),
                            .send(.combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: definition))))
                        ]
                    )
                }
                return .none
            case .nextScreen, .detailScreen: break // handled by reducers below
            }
            return .none
        },
        CompendiumItemReferenceTextAnnotation.handleTapReducer(
            didTapAction: /Action.didTapCompendiumItemReferenceTextAnnotation,
            requestItem: \.itemRequest,
            internalAction: /Action.setNextScreen..State.NextScreen.compendiumItemDetailView,
            externalAction: /Action.setNextScreen..State.NextScreen.safariView,
            environment: { $0 }
        ),
        CombatantTagsViewState.reducer.optional().pullback(state: \.presentedNextCombatantTagsView, action: /Action.nextScreen..Action.NextScreenAction.combatantTagsView),
        CombatantResourcesViewState.reducer.optional().pullback(state: \.presentedNextCombatantResourcesView, action: /Action.nextScreen..Action.NextScreenAction.combatantResourcesView),
        AnyReducer { _ in CreatureEditFeature() }
            .optional().pullback(state: \.presentedNextCreatureEditView, action: /Action.nextScreen..Action.NextScreenAction.creatureEditView, environment: { $0 }),
        CombatantTrackerEditViewState.reducer.optional().pullback(state: \.addLimitedResourceState, action: /Action.addLimitedResource),
        AnyReducer { env in
            HealthDialogFeature(environment: env)
        }
        .optional()
        .pullback(state: \.healthDialogState, action: /Action.healthDialog)
    )
}

typealias CombatantDetailViewState = CombatantDetailFeature.State
typealias CombatantDetailViewAction = CombatantDetailFeature.Action

extension CombatantDetailFeature.State {
    static let nullInstance = CombatantDetailFeature.State(combatant: Combatant.nullInstance)

    static var reducer: AnyReducer<Self, CombatantDetailFeature.Action, Environment> {
        CombatantDetailFeature.legacyReducer
    }
}

extension CompendiumItemReferenceTextAnnotation {
    typealias HandleTapReducerEnvironment = EnvironmentWithCompendium & EnvironmentWithCrashReporter

    static func handleTapReducer<State, Action, Environment>(
        didTapAction: CasePath<Action, (CompendiumItemReferenceTextAnnotation, AppNavigation)>,
        requestItem: WritableKeyPath<State, ReferenceViewItemRequest?>,
        internalAction: CasePath<Action, CompendiumEntryDetailFeature.State>,
        externalAction: CasePath<Action, SafariViewState>,
        environment: @escaping (Environment) -> HandleTapReducerEnvironment
    ) -> AnyReducer<State, Action, Environment> {
        AnyReducer { (state, action, env: HandleTapReducerEnvironment) in
            if let (annotation, appNavigation) = didTapAction.extract(from: action) {
                switch env.compendium.resolve(annotation: annotation) {
                case .internal(let reference):
                    if let entry = try? env.compendium.get(reference.itemKey, crashReporter: env.crashReporter) {
                        let detailState = CompendiumEntryDetailFeature.State(entry: entry)
                        switch appNavigation {
                        case .column:
                            state[keyPath: requestItem] = ReferenceViewItemRequest(
                                id: UUID().tagged(),
                                state: ReferenceItemViewState(content: .compendiumItem(detailState)),
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
                            state: ReferenceItemViewState(content: .safari(externalState)),
                            oneOff: true
                        )
                    case .tab: return .send(externalAction.embed(externalState))
                    }
                case .notFound: break
                }
            }
            return .none
        }.pullback(state: \.self, action: /Action.self, environment: environment)
    }
}
