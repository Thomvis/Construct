//
//  AppState.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 14/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct AppState: Equatable {

    var navigation: Navigation?

    var preferences: Preferences

    var showWelcomeSheet = false

    var sceneIsActive = false

    var topNavigationItemState: NavigationStackItemState? {
        guard !showWelcomeSheet else { return nil }
        switch navigation {
        case .tab(let s): return s.topNavigationItemState
        case .column, nil: return nil
        }
    }

    enum Navigation: Equatable {
        case tab(TabNavigationViewState)
        case column(ColumnNavigationViewState)

        var tabState: TabNavigationViewState? {
            get {
                guard case .tab(let s) = self else { return nil }
                return s
            }
            set {
                if let newValue = newValue {
                    self = .tab(newValue)
                }
            }
        }

        var columnState: ColumnNavigationViewState? {
            get {
                guard case .column(let s) = self else { return nil }
                return s
            }
            set {
                if let newValue = newValue {
                    self = .column(newValue)
                }
            }
        }
    }

    enum Action: Equatable {
        case navigation(AppStateNavigationAction)

        case onHorizontalSizeClassChange(UserInterfaceSizeClass)

        case welcomeSheet(Bool)
        case welcomeSheetSampleEncounterTapped
        case welcomeSheetDismissTapped
        case onAppear

        case sceneDidBecomeActive
        case sceneWillResignActive
    }

    static var reducer: Reducer<AppState, Action, Environment> {
        return Reducer.combine(
            Reducer { state, action, env in
                switch action {
                case .navigation: break // handled below
                case .onHorizontalSizeClassChange(let sizeClass):
                    switch (state.navigation, sizeClass) {
                    case (nil, .compact):
                        state.navigation = .tab(TabNavigationViewState())
                    case (.column(let prev), .compact):
                        state.navigation = .tab(prev.tabNavigationViewState)
                    case (nil, .regular):
                        state.navigation = .column(ColumnNavigationViewState())
                    case (.tab(let prev), .regular):
                        state.navigation = .column(prev.columnNavigationViewState)
                    default:
                        break
                    }
                case .welcomeSheet(let show):
                    state.showWelcomeSheet = show
                    if !show {
                        state.preferences.didShowWelcomeSheet = true
                    }
                case .welcomeSheetSampleEncounterTapped:
                    return SampleEncounter.create(with: env)
                        .append(Effect.result { () -> Result<Action?, Never> in
                            // navigate to scratch pad
                            if let encounter: Encounter = try? env.database.keyValueStore.get(Encounter.key(Encounter.scratchPadEncounterId)) {
                                return .success(.navigation(.openEncounter(encounter)))
                            } else {
                                return .success(nil)
                            }
                        }.compactMap { $0 }.append(.welcomeSheet(false))).eraseToEffect()
                case .welcomeSheetDismissTapped:
                    return Effect(value: .welcomeSheet(false))
                case .onAppear:
                    if !state.preferences.didShowWelcomeSheet {
                        state.showWelcomeSheet = true
                    }
                case .sceneDidBecomeActive:
                    state.sceneIsActive = true
                case .sceneWillResignActive:
                    state.sceneIsActive = false
                }
                return .none
            },
            Navigation.reducer.optional().pullback(state: \.navigation, action: /AppState.Action.navigation),
            Reducer { state, action, env in
                if state.sceneIsActive, let edv = state.topNavigationItemState as? EncounterDetailViewState, edv.running != nil {
                    env.isIdleTimerDisabled = true
                } else {
                    env.isIdleTimerDisabled = false
                }
                return .none
            }
        )
    }
}

enum AppStateNavigationAction: Equatable {
    case openEncounter(Encounter)

    case tab(TabNavigationViewAction)
    case column(ColumnNavigationViewAction)
}

extension AppState.Navigation {
    static let reducer: Reducer<Self, AppStateNavigationAction, Environment> = Reducer.combine(
        Reducer { state, action, env in
            switch (state, action) {
            case (.tab, .openEncounter(let e)):
                return Effect(value: .tab(.campaignBrowser(.setNextScreen(.encounter(EncounterDetailViewState(building: e))))))
            case (.column, .openEncounter(let e)):
                return Effect(value: AppStateNavigationAction.column(.campaignBrowse(.setNextScreen(.encounter(EncounterDetailViewState(building: e))))))
            default:
                break
            }
            return .none
        },
        TabNavigationViewState.reducer.optional().pullback(state: \.tabState, action: /AppStateNavigationAction.tab),
        ColumnNavigationViewState.reducer.optional().pullback(state: \.columnState, action: /AppStateNavigationAction.column)
    )
}

protocol Popover {
    // if popoverId changes, it is considered a new popover
    var popoverId: AnyHashable { get }
    func makeBody() -> AnyView
}

enum AppNavigation: Equatable {
    case tab
    case column
}

struct AppNavigationEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppNavigation = .tab
}

extension EnvironmentValues {
    var appNavigation: AppNavigation {
        get { self[AppNavigationEnvironmentKey.self] }
        set { self[AppNavigationEnvironmentKey.self] = newValue }
    }
}

extension AppState {
    var localStateForDeduplication: AppState {
        var res = self
        switch res.navigation {
        case .column:
            res.navigation = .column(ColumnNavigationViewState.nullInstance)
        case .tab:
            res.navigation = .tab(TabNavigationViewState.nullInstance)
        case nil:
            res.navigation = nil
        }
        return res
    }
}

extension TabNavigationViewState {
    var columnNavigationViewState: ColumnNavigationViewState {
        let def = ColumnNavigationViewState()
        return ColumnNavigationViewState(
            campaignBrowse: campaignBrowser,
            referenceView: ReferenceViewState(
                items: [
                    ReferenceViewState.Item(
                        state: ReferenceItemViewState(
                            content: .home(
                                ReferenceItemViewState.Content.Home(
                                    presentedScreens: compendium.presentedNextCompendiumIndex.map { [.nextInStack: .compendium($0)] } ?? [:]
                                )
                            )
                        )
                    )
                ]
            ),
            diceCalculator: FloatingDiceRollerViewState(
                hidden: false,
                diceCalculator: apply(def.diceCalculator.diceCalculator) {
                    $0.expression = diceRoller.calculatorState.expression
                    $0.result = diceRoller.calculatorState.result
                    $0.previousExpressions = diceRoller.calculatorState.previousExpressions
                    $0.entryContext = diceRoller.calculatorState.entryContext
                }
            )
        )
    }
}

extension ColumnNavigationViewState {
    var tabNavigationViewState: TabNavigationViewState {
        let def = TabNavigationViewState()

        let activeCompendiumReferenceItemTab = referenceView.items
            .first(where: { $0.id == referenceView.selectedItemId })
            .flatMap {
                $0.state.content.homeState?.presentedNextCompendium
            }

        let selectedTab: TabNavigationViewState.Tabs = {
            if diceCalculator.diceCalculator.mode == .editingExpression {
                return .diceRoller
            }

            if campaignBrowse.topNavigationItems().contains(where: { $0 is EncounterDetailViewState }) {
                return .campaign
            }

            if activeCompendiumReferenceItemTab != nil {
                return .compendium
            }

            return def.selectedTab
        }()

        return TabNavigationViewState(
            selectedTab: selectedTab,
            campaignBrowser: campaignBrowse,
            compendium: apply(def.compendium) {
                if activeCompendiumReferenceItemTab != nil {
                    $0.presentedNextCompendiumIndex = activeCompendiumReferenceItemTab
                }
            },
            diceRoller: apply(def.diceRoller) {
                $0.calculatorState.expression = diceCalculator.diceCalculator.expression
                $0.calculatorState.result = diceCalculator.diceCalculator.result
                $0.calculatorState.previousExpressions = diceCalculator.diceCalculator.previousExpressions
                $0.calculatorState.entryContext = diceCalculator.diceCalculator.entryContext
            }
        )
    }
}
