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

struct CombatantDetailViewState: NavigationStackSourceState, Equatable {

    var runningEncounter: RunningEncounter?

    var combatant: Combatant {
        didSet {
            let c = combatant
            presentedNextCombatantTagsView?.update(c)
            presentedNextCombatantResourcesView?.combatant = c
        }
    }

    var popover: Popover?
    var alert: AlertState<CombatantDetailViewAction>?

    var presentedScreens: [NavigationDestination: NextScreen] = [:]

    var navigationStackItemStateId: String {
        combatant.id.rawValue.uuidString
    }

    var navigationTitle: String { combatant.discriminatedName }
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { .inline }

    var itemRequest: ReferenceViewItemRequest?

    var addLimitedResourceState: CombatantTrackerEditViewState? {
        get {
            guard case .addLimitedResource(let s) = popover else { return nil }
            return s
        }
        set {
            if let newValue = newValue {
                popover = .addLimitedResource(newValue)
            }
        }
    }

    var healthDialogState: HealthDialogState? {
        get {
            guard case .healthAction(let s) = popover else { return nil }
            return s
        }
        set {
            if let newValue = newValue {
                popover = .healthAction(newValue)
            }
        }
    }

    var rollCheckDialogState: DiceCalculatorState? {
        get {
            guard case .rollCheck(let s) = popover else { return nil }
            return s
        }
        set {
            if let newValue = newValue {
                popover = .rollCheck(newValue)
            }
        }
    }

    var diceActionPopoverState: DiceActionViewState? {
        get {
            guard case .diceAction(let s) = popover else { return nil }
            return s
        }
        set {
            if let newValue = newValue {
                popover = .diceAction(newValue)
            }
        }
    }

    var initiativePopoverState: NumberEntryViewState? {
        get {
            guard case .initiative(let s) = popover else { return nil }
            return s
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
            case .creatureEditView: return .creatureEditView(CreatureEditViewState.nullInstance)
            case .combatantResourcesView: return .combatantResourcesView(CombatantResourcesViewState.nullInstance)
            case .runningEncounterLogView: return .runningEncounterLogView(RunningEncounterLogViewState.nullInstance)
            case .compendiumItemDetailView: return .compendiumItemDetailView(.nullInstance)
            case .safariView: return .safariView(.nullInstance)
            }
        }
        res.popover = popover.map {
            switch $0 {
            case .healthAction: return .healthAction(HealthDialogState.nullInstance)
            case .initiative: return .initiative(NumberEntryViewState.nullInstance)
            case .rollCheck: return .rollCheck(DiceCalculatorState.nullInstance)
            case .diceAction: return .diceAction(DiceActionViewState.nullInstance)
            case .tagDetails: return .tagDetails(CombatantTag.nullInstance)
            case .addLimitedResource: return .addLimitedResource(CombatantTrackerEditViewState.nullInstance)
            }
        }
        return res
    }

    static let reducer: Reducer<Self, CombatantDetailViewAction, Environment> = Reducer.combine(
        CombatantTagEditViewState.reducer.optional().pullback(state: \.presentedNextCombatantTagEditView, action: /CombatantDetailViewAction.nextScreen..CombatantDetailViewAction.NextScreenAction.combatantTagEditView),
        DiceCalculatorState.reducer.optional().pullback(state: \.rollCheckDialogState, action: /CombatantDetailViewAction.rollCheckDialog),
        DiceActionViewState.reducer.optional().pullback(state: \.diceActionPopoverState, action: /CombatantDetailViewAction.diceActionPopover),
        NumberEntryViewState.reducer.optional().pullback(state: \.initiativePopoverState, action: /CombatantDetailViewAction.initiativePopover),
        CompendiumEntryDetailViewState.reducer.optional().pullback(state: \.presentedNextCompendiumItemDetailView, action: /CombatantDetailViewAction.nextScreen..CombatantDetailViewAction.NextScreenAction.compendiumItemDetailView),
        Reducer { state, action, env in
            switch action {
            case .combatant: break // should be handled by parent
            case .popover(let p):
                state.popover = p
            case .alert(let a):
                state.alert = a
            case .addLimitedResource(.onDoneTap):
                guard case .addLimitedResource(let s) = state.popover else { return .none }
                return Effect.fireAndForget {
                    env.dismissKeyboard()
                }.append([.popover(nil), .combatant(.addResource(s.resource))]).eraseToEffect()
            case .addLimitedResource: break // handled below
            case .healthDialog: break // handled below
            case .rollCheckDialog: break // handled above
            case .diceActionPopover: break // handled above
            case .initiativePopover: break // handled above
            case .editCreatureConfirmingUnlinkIfNeeded:
                if let def = state.combatant.definition as? AdHocCombatantDefinition {
                    return Effect(value: .setNextScreen(.creatureEditView(CreatureEditViewState(edit: def))))
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
                            TextState("Cancel"),
                            action: nil
                        )
                    )
                }
            case .saveToCompendium:
                guard let def = state.combatant.definition as? AdHocCombatantDefinition, let stats = def.stats else { return .none }

                let item: CompendiumCombatant
                if def.isUnique {
                    item = Character(id: UUID().tagged(), realm: .homebrew, level: def.level, stats: def.stats ?? .default, player: def.player)
                } else {
                    item = Monster(realm: .homebrew, stats: stats, challengeRating: Fraction(integer: 0))
                }

                try? env.compendium.put(CompendiumEntry(item))
                return Effect(value: .combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: CompendiumCombatantDefinition(item: item, persistent: false)))))
            case .unlinkFromCompendium:
                let currentDefinition = state.combatant.definition

                let original = (currentDefinition as? CompendiumCombatantDefinition).map { CompendiumItemReference(itemTitle: $0.name, itemKey: $0.item.key) }
                let def = AdHocCombatantDefinition(id: UUID().tagged(), stats: currentDefinition.stats, player: currentDefinition.player, level: currentDefinition.level, original: original)
                return Effect(value: .combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: def))))
            case .unlinkAndEditCreature:
                return Effect(value: .editCreatureConfirmingUnlinkIfNeeded)
                    .delay(for: 0, scheduler: env.mainQueue)
                    .prepend(.unlinkFromCompendium)
                    .eraseToEffect()
            case .didTapCompendiumItemReferenceTextAnnotation: break // handled by CompendiumItemReferenceTextAnnotation.handleTapReducer
            case .setNextScreen(let s):
                state.presentedScreens[.nextInStack] = s
            case .setDetailScreen(let s):
                state.presentedScreens[.detail] = s
            case .nextScreen(.combatantTagsView(.combatant(let c, let a))):
                guard c.id == state.combatant.id else { return .none }
                // bubble-up action
                return Effect(value: .combatant(a))
            case .nextScreen(.combatantResourcesView(.combatant(let a))):
                // bubble-up action
                return Effect(value: .combatant(a))
            case .nextScreen(.combatantTagEditView(.onDoneTap)):
                let tag = state.presentedNextCombatantTagEditView?.tag
                state.nextScreen = nil

                if let tag = tag {
                    return Effect(value: .combatant(.addTag(tag)))
                }
            case .nextScreen(.creatureEditView(.onDoneTap(let state))):
                guard let def = state.adHocCombatant else { return .none }
                return [.setNextScreen(nil), .combatant(.setDefinition(Combatant.CodableCombatDefinition(definition: def)))].publisher.eraseToEffect()
            case .nextScreen, .detailScreen: break// handled by reducers below
            }
            return .none
        },
        CompendiumItemReferenceTextAnnotation.handleTapReducer(
            didTapAction: /CombatantDetailViewAction.didTapCompendiumItemReferenceTextAnnotation,
            requestItem: \.itemRequest,
            internalAction: /CombatantDetailViewAction.setNextScreen..Self.NextScreen.compendiumItemDetailView,
            externalAction: /CombatantDetailViewAction.setNextScreen..Self.NextScreen.safariView
        ),
        CombatantTagsViewState.reducer.optional().pullback(state: \.presentedNextCombatantTagsView, action: /CombatantDetailViewAction.nextScreen..CombatantDetailViewAction.NextScreenAction.combatantTagsView),
        CombatantResourcesViewState.reducer.optional().pullback(state: \.presentedNextCombatantResourcesView, action: /CombatantDetailViewAction.nextScreen..CombatantDetailViewAction.NextScreenAction.combatantResourcesView),
        CreatureEditViewState.reducer.optional().pullback(state: \.presentedNextCreatureEditView, action: /CombatantDetailViewAction.nextScreen..CombatantDetailViewAction.NextScreenAction.creatureEditView),
        CombatantTrackerEditViewState.reducer.optional().pullback(state: \.addLimitedResourceState, action: /CombatantDetailViewAction.addLimitedResource),
        HealthDialogState.reducer.optional().pullback(state: \.healthDialogState, action: /CombatantDetailViewAction.healthDialog)
    )

    enum NextScreen: Equatable {
        case combatantTagsView(CombatantTagsViewState)
        case combatantTagEditView(CombatantTagEditViewState)
        case creatureEditView(CreatureEditViewState)
        case combatantResourcesView(CombatantResourcesViewState)
        case runningEncounterLogView(RunningEncounterLogViewState)
        case compendiumItemDetailView(CompendiumEntryDetailViewState)
        case safariView(SafariViewState)
    }

    enum Popover: Equatable {
        case healthAction(HealthDialogState)
        case initiative(NumberEntryViewState)
        case rollCheck(DiceCalculatorState)
        case diceAction(DiceActionViewState)
        case tagDetails(CombatantTag)
        case addLimitedResource(CombatantTrackerEditViewState)
    }

}

enum CombatantDetailViewAction: NavigationStackSourceAction, Equatable {
    case combatant(CombatantAction)
    case popover(CombatantDetailViewState.Popover?)
    case alert(AlertState<Self>?)
    case addLimitedResource(CombatantTrackerEditViewAction)
    case healthDialog(HealthDialogAction)
    case rollCheckDialog(DiceCalculatorAction)
    case diceActionPopover(DiceActionViewAction)
    case initiativePopover(NumberEntryViewAction)
    case editCreatureConfirmingUnlinkIfNeeded
    case saveToCompendium
    case unlinkFromCompendium
    case unlinkAndEditCreature

    case didTapCompendiumItemReferenceTextAnnotation(CompendiumItemReferenceTextAnnotation, AppNavigation)

    case setNextScreen(CombatantDetailViewState.NextScreen?)
    case nextScreen(NextScreenAction)
    case setDetailScreen(CombatantDetailViewState.NextScreen?)
    case detailScreen(NextScreenAction)

    static func presentScreen(_ destination: NavigationDestination, _ screen: CombatantDetailViewState.NextScreen?) -> Self {
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
        case creatureEditView(CreatureEditViewAction)
        case combatantResourcesView(CombatantResourcesViewAction)
        case runningEncounterLogView
        case compendiumItemDetailView(CompendiumItemDetailViewAction)
        case safariView
    }

}

extension CombatantDetailViewState {
    static let nullInstance = CombatantDetailViewState(combatant: Combatant.nullInstance)
}

extension CompendiumItemReferenceTextAnnotation {
    static func handleTapReducer<State, Action>(
        didTapAction: CasePath<Action, (CompendiumItemReferenceTextAnnotation, AppNavigation)>,
        requestItem: WritableKeyPath<State, ReferenceViewItemRequest?>,
        internalAction: CasePath<Action, CompendiumEntryDetailViewState>,
        externalAction: CasePath<Action, SafariViewState>
    ) -> Reducer<State, Action, Environment> {
        Reducer { state, action, env in
            if let (annotation, appNavigation) = didTapAction.extract(from: action) {
                switch env.compendium.resolve(annotation: annotation) {
                case .internal(let ref):
                    if let entry = try? env.compendium.get(ref.itemKey) {
                        let detailState = CompendiumEntryDetailViewState(entry: entry)
                        switch appNavigation {
                        case .column:
                            state[keyPath: requestItem] = ReferenceViewItemRequest(
                                id: UUID().tagged(),
                                state: ReferenceItemViewState(content: .compendiumItem(detailState)),
                                oneOff: true
                            )
                        case .tab: return Effect(value: internalAction.embed(detailState))
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
                    case .tab: return Effect(value: externalAction.embed(externalState))
                    }
                case .notFound: break
                }
            }
            return .none
        }
    }
}
