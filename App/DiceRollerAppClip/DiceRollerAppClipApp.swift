//
//  DiceRollerAppClipApp.swift
//  DiceRollerAppClip
//
//  Created by Thomas Visser on 20/08/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import SwiftUI
import DiceRollerFeature
import Helpers
import ComposableArchitecture
import StoreKit

@main
struct DiceRollerAppClipApp: App {
    let store: Store<AppState, AppAction>

    init() {
        store = Store(
            initialState: AppState(),
            reducer: appReducer,
            environment: DiceRollerEnvironment(
                mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
                diceLog: DiceLogPublisher(),
                modifierFormatter: apply(NumberFormatter()) { f in
                    f.positivePrefix = f.plusSign
                }
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            WithViewStore(store) { viewStore in
                ContentView(store: store.scope(state: \.diceRoller, action: AppAction.diceRoller))
                    .onAppear {
                        viewStore.send(.onLaunch)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                        viewStore.send(.onContinueUserActivity(activity))
                    }
                    .appStoreOverlay(
                        isPresented: viewStore.binding(\.$showAppStoreOverlay),
                        configuration: {
                            return SKOverlay.AppClipConfiguration(position: .bottom)
                        }
                    )
            }
        }
    }
}

struct AppState: Equatable {
    var diceRoller = DiceRollerViewState()

    @BindableState var showAppStoreOverlay: Bool = false
    var didShowAppStoreOverlay: Bool = false
}

enum AppAction: Equatable, BindableAction {
    case onLaunch
    case onContinueUserActivity(NSUserActivity)
    case diceRoller(DiceRollerViewAction)

    case binding(BindingAction<AppState>)
}

let appReducer: Reducer<AppState, AppAction, DiceRollerEnvironment> = .combine(
    Reducer { state, action, env in
        switch action {
        case .onLaunch:
            // Listen to dice rolls and forward them to the right place
            return env.diceLog.rolls.map { (result, roll) in
                    .diceRoller(.onProcessRollForDiceLog(result, roll))
            }
            .eraseToEffect()
            .cancellable(id: "diceLog", cancelInFlight: true)
        case .onContinueUserActivity(let activity):
            guard let url = activity.webpageURL, let invocation = try? invocationRouter.match(url: url) else {
                print("ERROR: Could not continue user activity")
                break
            }

            state.diceRoller.calculatorState.reset()
            state.diceRoller.calculatorState.expression = invocation.expression
        case .diceRoller(.hideOutcome):
            if !state.didShowAppStoreOverlay {
                state.showAppStoreOverlay = true
                state.didShowAppStoreOverlay = true
            }
        case .diceRoller(let action): break
        case .binding: break
        }
        return .none
    },
    DiceRollerViewState.reducer.pullback(state: \.diceRoller, action: /AppAction.diceRoller)
)
