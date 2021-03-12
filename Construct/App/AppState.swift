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

    var navigation: Navigation

    var preferences: Preferences

    var showWelcomeSheet = false

    var sceneIsActive = false

    var topNavigationItemState: NavigationStackItemState? {
        guard !showWelcomeSheet else { return nil }
        switch navigation {
        case .tab(let s): return s.topNavigationItemState
        case .column: return nil
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
            Navigation.reducer.pullback(state: \.navigation, action: /AppState.Action.navigation),
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

    case onHorizontalSizeClassChange(UserInterfaceSizeClass)

    case tab(TabNavigationViewAction)
    case column(ColumnNavigationViewAction)
}

extension AppState.Navigation {
    static let reducer: Reducer<Self, AppStateNavigationAction, Environment> = Reducer.combine(
        Reducer { state, action, env in
            switch (state, action) {
            case (_, .onHorizontalSizeClassChange(.compact)):
                state = .tab(TabNavigationViewState())
            case (_, .onHorizontalSizeClassChange(.regular)):
                state = .column(ColumnNavigationViewState())
            case (.tab, .openEncounter(let e)):
                return Effect(value: .tab(.campaignBrowser(.setNextScreen(.encounter(EncounterDetailViewState(building: e))))))
            case (.column, .openEncounter(let e)):
                return Effect(value: .column(.sidebar(.openEncounter(e))))
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
    var normalizedForDeduplication: AppState {
        var res = self
        switch res.navigation {
        case .column:
            res.navigation = .column(ColumnNavigationViewState.nullInstance)
        case .tab:
            res.navigation = .tab(TabNavigationViewState.nullInstance)
        }
        return res
    }
}
