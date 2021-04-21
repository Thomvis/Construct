//
//  Construct.swift
//  Construct
//
//  Created by Thomas Visser on 04/06/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import SwiftUI
import Combine
import ComposableArchitecture
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes

@main
struct ConstructApp: App {
    @SwiftUI.Environment(\.scenePhase) var scenePhase

    let env: Environment
    let store: Store<AppState, AppState.Action>
    let viewStore: ViewStore<AppState, AppState.Action>

    init() {
        AppCenter.start(withAppSecret: "72078370-4844-4ec2-a850-22a22dee0233", services: [
            Analytics.self, Crashes.self
        ])

        self.env = try! Environment.live()

        let state = AppState(
            navigation: nil,
            preferences: (try? env.database.keyValueStore.get(Preferences.key)) ?? Preferences()
        )

        self.store = Store(
            initialState: state,
            reducer: env.database.keyValueStore.entityChangeObserver(initialState: state, reducer: AppState.reducer),
            environment: env
        )
        self.viewStore = ViewStore(store)
    }

    @SceneBuilder
    var body: some Scene {
        WindowGroup {
            ConstructView(store: self.store)
                .environmentObject(env)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                viewStore.send(.sceneDidBecomeActive)
            case .inactive:
                viewStore.send(.sceneWillResignActive)
            case .background:
                break
            @unknown default:
                break
            }
        }
    }
}

struct ConstructView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) var horizontalSizeClass
//    @State var toggleNavigation = false

    @EnvironmentObject var env: Environment
    let store: Store<AppState, AppState.Action>

    var body: some View {
        WithViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication }) { viewStore in
            IfLetStore(store.scope(state: { $0.navigation?.tabState }, action: { .navigation(.tab($0)) }), then: { store in
                TabNavigationView(store: store)
            }, else: IfLetStore(store.scope(state: { $0.navigation?.columnState }, action: {.navigation(.column($0)) })) { store in
                ColumnNavigationView(store: store)
            })
            .sheet(isPresented: viewStore.binding(get: { $0.showWelcomeSheet }, send: { _ in .welcomeSheet(false) })) {
                WelcomeView { tap in
                    switch tap {
                    case .sampleEncounter:
                        viewStore.send(.welcomeSheetSampleEncounterTapped)
                    case .dismiss:
                        viewStore.send(.welcomeSheetDismissTapped)
                    }
                }
            }
            .onAppear {
                if let sizeClass = horizontalSizeClass {
                    viewStore.send(.onHorizontalSizeClassChange(sizeClass))
                }
                viewStore.send(.onAppear)
            }
            .onChange(of: horizontalSizeClass) { sizeClass in
                if let sizeClass = sizeClass {
                    viewStore.send(.onHorizontalSizeClassChange(sizeClass))
                }
            }
//            .overlay(ZStack {
//                Button(action: {
//                    self.toggleNavigation.toggle()
//                    let oppositeSizeClass: UserInterfaceSizeClass = horizontalSizeClass == .regular ? .compact : .regular
//                    viewStore.send(.onHorizontalSizeClassChange(toggleNavigation ? oppositeSizeClass : horizontalSizeClass!))
//                }) {
//                    Text("Toggle navigation")
//                }
//            })
        }
    }
}
