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
    let store: StoreOf<AppFeature>

    init() {
        store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.diceLog = DiceLogPublisher()
        }
    }

    var body: some Scene {
        WindowGroup {
            WithViewStore(store, observe: \.self) { viewStore in
                ContentView(store: store.scope(state: \.diceRoller, action: AppFeature.Action.diceRoller))
                    .onAppear {
                        viewStore.send(.onLaunch)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                        viewStore.send(.onContinueUserActivity(activity))
                    }
                    .appStoreOverlay(
                        isPresented: viewStore.$showAppStoreOverlay,
                        configuration: {
                            return SKOverlay.AppClipConfiguration(position: .bottom)
                        }
                    )
            }
        }
    }
}

struct AppFeature: Reducer {

    struct State: Equatable {
        var diceRoller = DiceRollerFeature.State()

        @BindingState var showAppStoreOverlay: Bool = false
        var didShowAppStoreOverlay: Bool = false
    }

    enum Action: Equatable, BindableAction {
        case onLaunch
        case onContinueUserActivity(NSUserActivity)
        case diceRoller(DiceRollerFeature.Action)

        case binding(BindingAction<State>)
    }

    @Dependency(\.diceLog) var diceLog

    var body: some ReducerOf<Self> {
        Scope(state: \.diceRoller, action: /Action.diceRoller) {
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
            case .binding: break
            }
            return .none
        }

        BindingReducer()
    }
}
