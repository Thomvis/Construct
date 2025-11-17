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
import FirebaseCore
import FirebaseCrashlytics
import GameModels

@main
struct ConstructApp: App {

    init() {
        FirebaseApp.configure()
    }

    @SceneBuilder
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Shows the loading view while the environment is loading, then proceeds to the content view
struct RootView: View {
    @State var env: Environment?
    @State var loadingDuration: LoadingDuration = .instant

    var body: some View {
        ZStack {
            if let env, loadingDuration != .short {
                ConstructView(env: env).environmentObject(env)
            } else {
                AppLoadingView(duration: loadingDuration)
                    .task {
                        assert(env == nil)
                        do {
                            try await Task.sleep(until: .now + .milliseconds(100), clock: .suspending)
                            guard env == nil else { return }
                            withAnimation {
                                loadingDuration = .short
                            }
                            try await Task.sleep(until: .now + .seconds(2), clock: .suspending)
                            withAnimation {
                                loadingDuration = .long
                            }
                        } catch { }
                    }
            }
        }
        .task {
            guard env == nil else {
                // I first thought this would never happen, but closing a (Better)SafariView
                // causes this task to fire again
                return
            }

            guard ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] == nil else {
                print("Aborting launch because Construct is launched as a Test Host.")
                return
            }

            do {
                let e = try await Environment.live()
                withAnimation {
                    env = e
                }
            } catch {
                fatalError("Failed loading the environment")
            }
        }
    }

    enum LoadingDuration: Equatable {
        /// if loading completes instantly, we can immediately continue to the content
        case instant
        /// if loading takes a short time, we show an indicator
        /// if loading completes after a short time, we wait a bit longer to prevent a flicker
        case short
        /// if loading completes after a long time, we can immediately continue to the content
        case long
    }
}

struct AppLoadingView: View {
    let duration: RootView.LoadingDuration

    var body: some View {
        ZStack {
            Image("icon").resizable().aspectRatio(contentMode: .fit).frame(width: 300)
                .opacity(duration == .instant ? 1.0 : 0.66)
                .blur(radius: duration == .instant ? 0 : 10)
                .frame(maxHeight: .infinity)
                .ignoresSafeArea()

            if duration != .instant {
                VStack(spacing: 12) {
                    ProgressView()

                    Text("Optimizing content...")
                        .font(.title)
                }
            }
        }
    }
}

struct ConstructView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) var horizontalSizeClass
    @SwiftUI.Environment(\.scenePhase) var scenePhase

    let env: Environment
    let store: StoreOf<AppFeature>

    init(env: Environment) {
        let state = AppFeature.State(
            navigation: nil
        )

        self.env = env
        self.store = Store(
            initialState: state
        ) {
            env.database.keyValueStore.entityChangeObserver(
                initialState: state,
                reducer: AppFeature(environment: env)
            )
        }

        setUpCrashReporter()
    }

    init(env: Environment, store: StoreOf<AppFeature>) {
        self.env = env
        self.store = store

        setUpCrashReporter()
    }

    var body: some View {
        WithViewStore(store, observe: \.self, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication }) { viewStore in
            ZStack {
                IfLetStore(store.scope(state: { $0.navigation?.tabState }, action: { .navigation(.tab($0)) }), then: { store in
                    TabNavigationView(store: store)
                }, else: {
                    IfLetStore(store.scope(state: { $0.navigation?.columnState }, action: {.navigation(.column($0)) })) { store in
                        ColumnNavigationView(store: store)
                    }
                })
            }
            .sheet(isPresented: viewStore.binding(get: { $0.presentation == .welcomeSheet }, send: { _ in
                .dismissPresentation(.welcomeSheet) }
            )) {
                WelcomeView { tap in
                    switch tap {
                    case .sampleEncounter:
                        viewStore.send(.welcomeSheetSampleEncounterTapped)
                    case .dismiss:
                        viewStore.send(.dismissPresentation(.welcomeSheet))
                    }
                }
            }
            .alert(store: store.scope(state: \.$crashReportingPermissionAlert, action: { .alert($0) }))
            .task {
                await viewStore.send(.onLaunch).finish()
            }
            .onAppear {
                if let sizeClass = horizontalSizeClass {
                    viewStore.send(.onHorizontalSizeClassChange(sizeClass))
                }
                viewStore.send(.scene(scenePhase))

                viewStore.send(.onAppear)
            }
            .onChange(of: horizontalSizeClass) { _, sizeClass in
                if let sizeClass = sizeClass {
                    viewStore.send(.onHorizontalSizeClassChange(sizeClass))
                }
            }
            .onChange(of: scenePhase) { _, phase in
                viewStore.send(.scene(phase))
            }
            // Even though onOpenURL and onContinueUserActivity are added here and therefore are not in the view
            // hierarchy from the moment the app launches, they are still being called
            .onOpenURL { url in
                // This is called for universal links
                viewStore.send(.onOpenURL(url))
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                // This is called when launching an advanced App Clip experience (e.g. QR code)
                // while the main app is installed
                guard let url = activity.webpageURL else { return }
                viewStore.send(.onOpenURL(url))
            }
            .task {
                env.storeManager.beginObservingTransactionUpdates()
                await env.storeManager.checkForUnfinishedTransactions()
            }
        }
    }

    private func setUpCrashReporter() {
        if Crashlytics.crashlytics().didCrashDuringPreviousExecution() {
            if let preferences: Preferences = try? env.database.keyValueStore.get(Preferences.key),
                preferences.errorReportingEnabled == true
            {
                // user consent has been given, send reports
                env.crashReporter.registerUserPermission(.send)
                return
            }

            store.send(.requestPresentation(.crashReportingPermissionAlert))
        }
    }
}
