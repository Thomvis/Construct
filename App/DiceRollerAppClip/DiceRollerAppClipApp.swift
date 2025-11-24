//
//  DiceRollerAppClipApp.swift
//  DiceRollerAppClip
//
//  Created by Thomas Visser on 20/08/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import SwiftUI
import DiceRollerFeature
import DiceRollerInvocation
import Helpers
import ComposableArchitecture
import StoreKit

@main
struct DiceRollerAppClipApp: App {
    @Bindable var store: StoreOf<AppFeature>

    init() {
        store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.diceLog = DiceLogPublisher()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store.scope(state: \.diceRoller, action: \.diceRoller))
                .task {
                    await store.send(.onLaunch).finish()
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    store.send(.onContinueUserActivity(activity))
                }
                .appStoreOverlay(
                    isPresented: Binding(
                        get: { store.showAppStoreOverlay },
                        set: { store.send(.setShowAppStoreOverlay($0)) }
                    ),
                    configuration: {
                        SKOverlay.AppClipConfiguration(position: .bottom)
                    }
                )
        }
    }
}

@Reducer
struct AppFeature: Reducer {

    @ObservableState
    struct State: Equatable {
        var diceRoller = DiceRollerFeature.State()

        var showAppStoreOverlay: Bool = false
        var didShowAppStoreOverlay: Bool = false
    }

    enum Action: Equatable {
        case onLaunch
        case onContinueUserActivity(NSUserActivity)
        case diceRoller(DiceRollerFeature.Action)

        case setShowAppStoreOverlay(Bool)
    }

    @Dependency(\.diceLog) var diceLog

    var body: some ReducerOf<Self> {
        Scope(state: \.diceRoller, action: \.diceRoller) {
            DiceRollerFeature()
        }

        Reduce<State, Action> { state, action in
            switch action {
            case .onLaunch:
                // Listen to dice rolls and forward them to the right place
                let rolls = diceLog.rolls
                return .run { send in
                    for await (result, roll) in rolls.values {
                        await send(.diceRoller(.onProcessRollForDiceLog(result, roll)))
                    }
                }
                .cancellable(id: "diceLog", cancelInFlight: true)
            case .onContinueUserActivity(let activity):
                guard let url = activity.webpageURL, let invocation = try? diceRollerInvocationRouter.match(url: url) else {
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
            case .diceRoller: break
            case .setShowAppStoreOverlay(let show):
                state.showAppStoreOverlay = show
            }
            return .none
        }
    }
}
