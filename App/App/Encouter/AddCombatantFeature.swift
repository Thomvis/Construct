import Foundation
import ComposableArchitecture
import Helpers
import GameModels
import Compendium
import MechMuse
import Persistence
import DiceRollerFeature

@Reducer
struct AddCombatantFeature {
    @ObservableState
    struct State: Equatable {
        var compendiumState: CompendiumIndexFeature.State

        var encounter: Encounter {
            didSet {
                updateCombatantsByDefinitionCache()
                updateSuggestedCombatants()
            }
        }
        var dismissAfterQuickCreateAdd = false
        @Presents var creatureEditViewState: CreatureEditFeature.State?

        var combatantsByDefinitionCache: [String: [Combatant]] = [:] // computed from the encounter

        private mutating func updateCombatantsByDefinitionCache() {
            var result: [String: [Combatant]] = [:]
            for combatant in encounter.combatants {
                result[combatant.definition.definitionID, default: []].append(combatant)
            }
            self.combatantsByDefinitionCache = result
        }

        /// Suggestions are built from the encounter. Each non-unique compendium combatant is a suggested combatant
        /// If a combatant is removed from the encounter, it is not removed from the suggestions. (Until a whole new state
        /// is created.)
        private mutating func updateSuggestedCombatants() {
            let newSuggestions = combatantsByDefinitionCache.values.compactMap { combatants in
                combatants.first?.definition as? CompendiumCombatantDefinition
            }.compactMap { definition -> CompendiumEntry? in
                if !definition.isUnique {
                    // FIXME: we don't have all the info here to properly create the entry
                    return CompendiumEntry(
                        definition.item,
                        origin: .created(.init(definition.item)),
                        document: .init(
                            id: CompendiumSourceDocument.unspecifiedCore.id,
                            displayName: CompendiumSourceDocument.unspecifiedCore.displayName
                        )
                    )
                }
                return nil
            }.filter { c in !(compendiumState.suggestions?.contains(where: { $0.key == c.key }) ?? false) }

            compendiumState.suggestions = compendiumState.suggestions.map { $0 + newSuggestions } ?? newSuggestions.nonEmptyArray
        }
    }

    @CasePathable
    enum Action: Equatable {
        case compendiumState(CompendiumIndexFeature.Action)
        case quickCreate
        case quickCreateAndDismissOnAdd
        case creatureEditView(PresentationAction<CreatureEditFeature.Action>)
        case onSelect([Combatant], dismiss: Bool)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .quickCreate:
                state.dismissAfterQuickCreateAdd = false
                state.creatureEditViewState = CreatureEditFeature.State(create: .adHocCombatant)
            case .quickCreateAndDismissOnAdd:
                state.dismissAfterQuickCreateAdd = true
                state.creatureEditViewState = CreatureEditFeature.State(create: .adHocCombatant)
            case let .creatureEditView(.presented(.didAdd(result))):
                state.creatureEditViewState = nil
                let dismiss = state.dismissAfterQuickCreateAdd
                state.dismissAfterQuickCreateAdd = false
                if case let .adHoc(def) = result {
                    return .send(.onSelect([Combatant(adHoc: def)], dismiss: dismiss))
                } else if case let .compendium(entry) = result, let combatant = entry.item as? CompendiumCombatant {
                    return .send(.onSelect([Combatant(compendiumCombatant: combatant)], dismiss: dismiss))
                }
            case .creatureEditView(.dismiss):
                state.creatureEditViewState = nil
                state.dismissAfterQuickCreateAdd = false
            case .creatureEditView:
                break // handled below
            case .compendiumState:
                break
            case .onSelect:
                break // should be handled by parent
            }
            return .none
        }
        .ifLet(\.$creatureEditViewState, action: \.creatureEditView) {
            CreatureEditFeature()
        }
        Scope(state: \.compendiumState, action: \.compendiumState) {
            CompendiumIndexFeature()
        }
    }
}

extension AddCombatantFeature.State {
    static let nullInstance = AddCombatantFeature.State(encounter: Encounter.nullInstance)

    init(
        compendiumState: CompendiumIndexFeature.State = CompendiumIndexFeature.State(
            title: "Add Combatant",
            properties: CompendiumIndexFeature.State.Properties(
                showImport: false,
                showAdd: false,
                typeRestriction: [.monster, .character, .group]
            ),
            results: .initial
        ),
        encounter: Encounter,
        creatureEditViewState: CreatureEditFeature.State? = nil
    ) {
        self.compendiumState = compendiumState
        self.encounter = encounter
        self._creatureEditViewState = .init(wrappedValue: creatureEditViewState)
        updateCombatantsByDefinitionCache()
        updateSuggestedCombatants()
    }
}

extension AddCombatantFeature.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        compendiumState.navigationNodes
    }
}
