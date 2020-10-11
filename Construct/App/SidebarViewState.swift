//
//  SidebarViewState.swift
//  Construct
//
//  Created by Thomas Visser on 29/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import CasePaths

struct SidebarViewState: Equatable, NavigationStackSourceState {

    var presentedScreens: [NavigationDestination: NextScreen] = [:]

    var selectedCompendiumIndexState: CompendiumIndexState? {
        get {
            if case .compendium(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set {
            if let newValue = newValue {
                presentedScreens[.detail] = .compendium(newValue)
            }
        }
    }

    enum NextScreen: NavigationStackItemState, NavigationStackItemStateConvertible, Equatable {
        case compendium(CompendiumIndexState)

        var navigationStackItemState: NavigationStackItemState {
            switch self {
            case .compendium(let s): return s
            }
        }
    }

}

enum SidebarViewAction: NavigationStackSourceAction, Equatable {
    case setNextScreen(SidebarViewState.NextScreen?)
    indirect case nextScreen(NextScreenAction)
    case setDetailScreen(SidebarViewState.NextScreen?)
    indirect case detailScreen(NextScreenAction)

    static func presentScreen(_ destination: NavigationDestination, _ screen: SidebarViewState.NextScreen?) -> Self {
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
        case compendium(CompendiumIndexAction)
    }
}

extension SidebarViewState: NavigationStackItemState {
    var navigationStackItemStateId: String { "sidebar" }
    var navigationTitle: String { "Construct" }
}

extension SidebarViewState {
    static let reducer: Reducer<Self, SidebarViewAction, Environment> = Reducer.combine(
        CompendiumIndexState.reducer.optional().pullback(state: \.selectedCompendiumIndexState, action: /SidebarViewAction.detailScreen..SidebarViewAction.NextScreenAction.compendium),
        Reducer { state, action, env in
            switch action {
            case .setNextScreen(let s):
                state.presentedScreens[.nextInStack] = s
            case .nextScreen: break // handled above
            case .setDetailScreen(let s):
                state.presentedScreens[.detail] = s
            case .detailScreen: break // handled above
            }
            return .none
        }
    )
}
