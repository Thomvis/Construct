//
//  ReferenceItemViewState.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import CasePaths

struct ReferenceItemViewState: Equatable {

    var content: Content = .home(Content.Home(presentedScreens: [:]))

    var home: Content.Home? {
        get {
            guard case .home(let s) = content else { return nil }
            return s
        }
        set {
            if let newValue = newValue {
                content = .home(newValue)
            }
        }
    }

    enum Content: Equatable {
        case home(Home)

        struct Home: Equatable, NavigationStackSourceState {

            var navigationStackItemStateId: String = "home"
            var navigationTitle: String = "home"

            var presentedScreens: [NavigationDestination: NextScreen]

            var nextCompendium: CompendiumIndexState? {
                get { nextScreen?.navigationStackItemState as? CompendiumIndexState }
                set {
                    if let newValue = newValue {
                        nextScreen = .compendium(newValue)
                    }
                }
            }

            enum NextScreen: Equatable, NavigationStackItemStateConvertible, NavigationStackItemState {
                case compendium(CompendiumIndexState)

                var navigationStackItemState: NavigationStackItemState {
                    switch self {
                    case .compendium(let s): return s
                    }
                }
            }
        }
    }
}

enum ReferenceItemViewAction: Equatable {
    case contentHome(Home)

    enum Home: Equatable, NavigationStackSourceAction {
        case setNextScreen(ReferenceItemViewState.Content.Home.NextScreen?)
        indirect case nextScreen(NextScreenAction)
        case setDetailScreen(ReferenceItemViewState.Content.Home.NextScreen?)
        indirect case detailScreen(NextScreenAction)

        static func presentScreen(_ destination: NavigationDestination, _ screen: ReferenceItemViewState.Content.Home.NextScreen?) -> Self {
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
}

extension ReferenceItemViewState {
    static let nullInstance = ReferenceItemViewState()

    static let reducer: Reducer<Self, ReferenceItemViewAction, Environment> = Reducer.combine(
        ReferenceItemViewState.Content.Home.reducer.optional().pullback(state: \.home, action: /ReferenceItemViewAction.contentHome)
    )
}

extension ReferenceItemViewState.Content.Home {
    static let reducer: Reducer<Self, ReferenceItemViewAction.Home, Environment> = Reducer.combine(
        CompendiumIndexState.reducer.optional().pullback(state: \.nextCompendium, action: /ReferenceItemViewAction.Home.nextScreen..ReferenceItemViewAction.Home.NextScreenAction.compendium),
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
