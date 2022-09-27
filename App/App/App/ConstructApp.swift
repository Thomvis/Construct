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
        viewStore.send(.onLaunch)

        setUpCrashesUserConfirmationHandler()
    }

    @SceneBuilder
    var body: some Scene {
        WindowGroup {
            ConstructView(store: self.store)
                .environmentObject(env)
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

    private func setUpCrashesUserConfirmationHandler() {
        Crashes.userConfirmationHandler = { (errorReports: [ErrorReport]) in
            if let preferences: Preferences = try? env.database.keyValueStore.get(Preferences.key),
                preferences.errorReportingEnabled == true
            {
                // user consent has been given, send reports
                return false
            }

            viewStore.send(.requestPresentation(.crashReportingPermissionAlert))
            return true
        }
    }
}

struct ConstructView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) var horizontalSizeClass

    @EnvironmentObject var env: Environment
    let store: Store<AppState, AppState.Action>

    var body: some View {
        WithViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication }) { viewStore in
            IfLetStore(store.scope(state: { $0.navigation?.tabState }, action: { .navigation(.tab($0)) }), then: { store in
                TabNavigationView(store: store)
            }, else: {
                IfLetStore(store.scope(state: { $0.navigation?.columnState }, action: {.navigation(.column($0)) })) { store in
                    ColumnNavigationView(store: store)
                }
            })
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
            .alert(store.scope(state: { $0.crashReportingPermissionAlert }), dismiss: .dismissPresentation(.crashReportingPermissionAlert))
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
            .overlay {
                if viewStore.state.showPostLaunchLoadingScreen {
                    ZStack {
                        Image("icon").resizable().aspectRatio(contentMode: .fit).frame(width: 400).opacity(0.66).blur(radius: 10)

                        VStack(spacing: 12) {
                            ProgressView()

                            Text("Optimizing content...")
                                .font(.title)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .transition(.opacity)
                }
            }
        }
    }
}

extension AppState {
    var crashReportingPermissionAlert: AlertState<AppState.Action>? {
        guard presentation == .crashReportingPermissionAlert else { return nil }
        return AlertState(
            title: .init("Construct quit unexpectedly."),
            message: .init("Do you want to send an anonymous crash report so I can fix the issue?"),
            buttons: [
                .cancel(.init("Don't send")),
                .default(.init("Send"), action: .send(.onReceiveCrashReportingUserPermission(.send))),
                .default(.init("Always send"), action: .send(.onReceiveCrashReportingUserPermission(.sendAlways)))
            ])
    }
}
