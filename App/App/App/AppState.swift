//
//  AppState.swift
//  Construct
//
//  Created by Thomas Visser on 14/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture
import DiceRollerFeature
import Helpers
import URLRouting
import GameModels

struct AppState: Equatable {

    var navigation: Navigation?
    var presentation: Presentation?
    var pendingPresentations: [Presentation] = []

    var sceneIsActive = false

    var topNavigationItems: [Any] {
        guard presentation != .welcomeSheet else { return [] }
        switch navigation {
        case .tab(let s): return s.topNavigationItems
        case .column(let s): return s.topNavigationItems
        case nil: return []
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

    enum Presentation: Equatable {
        case welcomeSheet
        case crashReportingPermissionAlert
    }

    enum Action: Equatable {
        case onLaunch
        case navigation(AppStateNavigationAction)

        case onHorizontalSizeClassChange(UserInterfaceSizeClass)

        case requestPresentation(AppState.Presentation)
        case dismissPresentation(AppState.Presentation)

        case onReceiveCrashReportingUserPermission(CrashReporter.UserPermission)

        case welcomeSheetSampleEncounterTapped
        case onAppear

        case scene(ScenePhase)

        case onOpenURL(URL)

        case onProcessRollForDiceLog(DiceLogEntry.Result, RollDescription)
    }

    static var reducer: AnyReducer<AppState, Action, Environment> {
        return AnyReducer.combine(
            AnyReducer { state, action, env in
                switch action {
                case .onLaunch:
                    return .merge(
                        // Listen to dice rolls and forward them to the right place
                        env.diceLog.rolls.map { (result, roll) in
                                .onProcessRollForDiceLog(result, roll)
                        }
                        .eraseToEffect()
                        .cancellable(id: "diceLog", cancelInFlight: true),
                        // kickstart compendium loading to prevent flicker on tab switch (not needed on iPad)
                        .init(value: .navigation(.tab(.compendium(.results(.result(.didShowElementAtIndex(0)))))))
                    )
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
                case .requestPresentation(let p):
                    precondition(p != .welcomeSheet || !env.database.needsPrepareForUse)

                    if state.presentation == nil {
                        state.presentation = p
                    } else {
                        state.pendingPresentations.append(p)
                    }
                case .dismissPresentation(let p):
                    // we can't add this precondition because SwiftUI invokes the isPresented binding
                    // _after_ we hid the sheet by nilling underlying field.
                    // Instead, we ignore the dismiss action
                    // precondition(state.presentation == p)
                    guard state.presentation == p else { break }
                    state.presentation = nil

                    if let next = state.pendingPresentations.first {
                        state.pendingPresentations.removeFirst()
                        // workaround: we need to delay the action to work around
                        // a "Attempt to present X which is already presenting Y" error
                        return .init(value: .requestPresentation(next))
                            .delay(for: 0.1, scheduler: env.mainQueue)
                            .eraseToEffect()
                    }
                case .onReceiveCrashReportingUserPermission(let permission):
                    env.crashReporter.registerUserPermission(permission)
                case .welcomeSheetSampleEncounterTapped:
                    return .run { send in
                        SampleEncounter.create(with: env)

                        if let encounter: Encounter = try? env.database.keyValueStore.get(
                            Encounter.key(Encounter.scratchPadEncounterId),
                            crashReporter: env.crashReporter
                        ) {
                            await send(.navigation(.openEncounter(encounter)))
                        }

                        await send(.dismissPresentation(.welcomeSheet))
                    }
                case .onAppear:
                    if !env.preferences().didShowWelcomeSheet {
                        return .init(value: .requestPresentation(.welcomeSheet))
                    } else if let nodeCount = try? env.campaignBrowser.nodeCount(),
                              nodeCount >= CampaignBrowser.initialSpecialNodeCount+2
                    {
                        // if the user created some campaign nodes
                        env.requestAppStoreReview()
                    }
                case .scene(let phase):
                    state.sceneIsActive = phase == .active
                case .onOpenURL(let url):
                    guard let invocation = try? appInvocationRouter.match(url: url) else { break }
                    if case .diceRoller(let roller) = invocation {
                        // tab
                        state.navigation?.tabState?.selectedTab = .diceRoller
                        state.navigation?.tabState?.diceRoller.calculatorState.mode = .editingExpression
                        state.navigation?.tabState?.diceRoller.calculatorState.reset()
                        state.navigation?.tabState?.diceRoller.calculatorState.expression = roller.expression

                        // column
                        state.navigation?.columnState?.diceCalculator.hidden = false
                        state.navigation?.columnState?.diceCalculator.diceCalculator.mode = .editingExpression
                        state.navigation?.columnState?.diceCalculator.diceCalculator.reset()
                        state.navigation?.columnState?.diceCalculator.diceCalculator.expression = roller.expression
                    }
                case .onProcessRollForDiceLog(let result, let roll):
                    if state.navigation?.tabState != nil {
                        return .send(.navigation(.tab(.diceRoller(.onProcessRollForDiceLog(result, roll)))))
                    } else {
                        return .send(.navigation(.column(.diceCalculator(.onProcessRollForDiceLog(result, roll)))))
                    }
                }
                return .none
            }.onChange(of: { $0.presentation}) { p, state, a, env in
                if p == .welcomeSheet {
                    try? env.updatePreferences {
                        $0.didShowWelcomeSheet = true
                    }
                }
                return .none
            },
            Navigation.reducer.optional().pullback(state: \.navigation, action: /AppState.Action.navigation),
            AnyReducer { state, action, env in
                if state.sceneIsActive, let edv = state.topNavigationItems.compactMap({ $0 as? EncounterDetailViewState }).first, edv.running != nil {
                    env.isIdleTimerDisabled.wrappedValue = true
                } else {
                    env.isIdleTimerDisabled.wrappedValue = false
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
    static let reducer: AnyReducer<Self, AppStateNavigationAction, Environment> = AnyReducer.combine(
        AnyReducer { state, action, env in
            switch (state, action) {
            case (.tab, .openEncounter(let e)):
                let detailState = EncounterDetailViewState(
                    building: e,
                    isMechMuseEnabled: env.preferences().mechMuse.enabled
                )
                return .send(.tab(.campaignBrowser(.setNextScreen(.encounter(detailState)))))
            case (.column, .openEncounter(let e)):
                let detailState = EncounterDetailViewState(
                    building: e,
                    isMechMuseEnabled: env.preferences().mechMuse.enabled
                )
                return .send(AppStateNavigationAction.column(.campaignBrowse(.setNextScreen(.encounter(detailState)))))
            default:
                break
            }
            return .none
        },
        TabNavigationViewState.reducer.optional().pullback(state: \.tabState, action: /AppStateNavigationAction.tab),
        ColumnNavigationViewState.reducer.optional().pullback(state: \.columnState, action: /AppStateNavigationAction.column)
    )
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
                            content: .compendium(
                                ReferenceItemViewState.Content.Compendium(
                                    compendium: compendium
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
                $0.state.content.compendiumState?.compendium
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
