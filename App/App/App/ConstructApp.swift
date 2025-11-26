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
import GameModels
import Persistence
import MechMuse
import DiceRollerFeature
import CombineSchedulers
import Helpers

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
    @State var dependencies: BaseDependencies?
    @State var loadingDuration: LoadingDuration = .instant

    var body: some View {
        ZStack {
            if let dependencies, loadingDuration != .short {
                ConstructView(dependencies: dependencies)
            } else {
                AppLoadingView(duration: loadingDuration)
                    .task {
                        assert(dependencies == nil)
                        do {
                            try await Task.sleep(until: .now + .milliseconds(100), clock: .suspending)
                            guard dependencies == nil else { return }
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
            guard dependencies == nil else {
                // I first thought this would never happen, but closing a (Better)SafariView
                // causes this task to fire again
                return
            }

            guard ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] == nil else {
                print("Aborting launch because Construct is launched as a Test Host.")
                return
            }

            do {
                let deps = try await BaseDependencies.live()
                withAnimation {
                    dependencies = deps
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

    let dependencies: BaseDependencies

    @Bindable var store: StoreOf<AppFeature>

    @ViewBuilder
    private var navigationView: some View {
        if let tabStore = store.scope(state: \.navigation?.tab, action: \.navigation.tab) {
            TabNavigationView(store: tabStore)
        } else if let columnStore = store.scope(state: \.navigation?.column, action: \.navigation.column) {
            ColumnNavigationView(store: columnStore)
        }
    }

    private var welcomeSheetBinding: Binding<Bool> {
        Binding(
            get: { store.presentation == .welcomeSheet },
            set: { isPresented in
                if !isPresented {
                    store.send(.dismissPresentation(.welcomeSheet))
                }
            }
        )
    }

    init(dependencies: BaseDependencies) {
        let state = AppFeature.State(
            navigation: nil
        )

        self.dependencies = dependencies
        self.store = Store(
            initialState: state
        ) {
            dependencies.database.keyValueStore.entityChangeObserver(
                initialState: state,
                reducer: AppFeature()
            )
        } withDependencies: { deps in
            deps.database = dependencies.database
            deps.modifierFormatter = dependencies.modifierFormatter
            deps.ordinalFormatter = dependencies.ordinalFormatter
        }
    }

    /// Initializer for testing with a pre-built store
    init(dependencies: BaseDependencies, store: StoreOf<AppFeature>) {
        self.dependencies = dependencies
        self.store = store
    }

    var body: some View {
        ZStack {
            navigationView
        }
        .sheet(isPresented: welcomeSheetBinding) {
            WelcomeView { tap in
                switch tap {
                case .sampleEncounter:
                    store.send(.welcomeSheetSampleEncounterTapped)
                case .dismiss:
                    store.send(.dismissPresentation(.welcomeSheet))
                }
            }
        }
        .alert(store: store.scope(state: \.$crashReportingPermissionAlert, action: \.alert))
        .task {
            await store.send(.onLaunch).finish()
        }
        .onAppear {
            if let sizeClass = horizontalSizeClass {
                store.send(.onHorizontalSizeClassChange(sizeClass))
            }
            store.send(.scene(scenePhase))

            store.send(.onAppear)
        }
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if let sizeClass = sizeClass {
                store.send(.onHorizontalSizeClassChange(sizeClass))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            store.send(.scene(phase))
        }
        // Even though onOpenURL and onContinueUserActivity are added here and therefore are not in the view
        // hierarchy from the moment the app launches, they are still being called
        .onOpenURL { url in
            // This is called for universal links
            store.send(.onOpenURL(url))
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            // This is called when launching an advanced App Clip experience (e.g. QR code)
            // while the main app is installed
            guard let url = activity.webpageURL else { return }
            store.send(.onOpenURL(url))
        }
        .environmentObject(dependencies.modifierFormatter)
        .environmentObject(dependencies.ordinalFormatter)
    }
}

/// A container for the dependencies that are needed at the base view
struct BaseDependencies {
    let database: Database
    let modifierFormatter = ModifierFormatter()
    let ordinalFormatter = OrdinalFormatter()

    static func live() async throws -> Self {
        try await Self(
            database: Database.live()
        )
    }
}
