//
//  SettingsFeature.swift
//  Construct
//
//  Created by Thomas Visser on 18/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import GameModels
import Compendium
import MechMuse
import Persistence

@Reducer
public struct SettingsFeature: Reducer {

    public init() { }

    @ObservableState
    public struct State: Equatable {
        var destination: Destination?
        var initialPreferences: Preferences?
        var preferences: Preferences = Preferences()
        var mechMuseVerificationState: MechMuseVerificationState = .initial
        var canSendMail: Bool = false

        public init(
            destination: Destination? = nil,
            preferences: Preferences = Preferences()
        ) {
            self.destination = destination
            self.initialPreferences = preferences
            self.preferences = preferences
        }

        public enum Destination: Hashable, Identifiable {
            public var id: Int { hashValue }

            case safariView(String)
            case ogl
            case acknowledgements
            case tipJar
        }

        public enum MechMuseVerificationState: Equatable {
            case initial
            case loading
            case verified(apiKey: String)
            case failed(MechMuseError)

            var isLoading: Bool {
                if case .loading = self { return true }
                return false
            }

            var verifiedApiKey: String? {
                if case .verified(let key) = self { return key }
                return nil
            }

            var error: MechMuseError? {
                if case .failed(let error) = self { return error }
                return nil
            }
        }
    }

    public enum Action: Equatable {
        case onAppear
        case setDestination(State.Destination?)
        case setPreferences(Preferences)
        case setMechMuseEnabled(Bool)
        case setMechMuseApiKey(String)
        case setErrorReportingEnabled(Bool)
        case resetPreferences
        case importDefaultContent
        case sendFeedback
        case rateInAppStore

        // Mech Muse verification
        case verifyMechMuseApiKey
        case mechMuseVerificationResult(Result<String, MechMuseError>)
    }

    @Dependency(\.mailer) var mailer
    @Dependency(\.appReview) var appReview
    @Dependency(\.preferences) var preferencesClient
    @Dependency(\.compendium) var compendium
    @Dependency(\.compendiumMetadata) var compendiumMetadata
    @Dependency(\.mechMuse) var mechMuse
    @Dependency(\.continuousClock) var clock

    private enum CancelID: Hashable {
        case mechMuseVerification
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let prefs = preferencesClient.get()
                state.initialPreferences = prefs
                state.preferences = prefs
                state.canSendMail = mailer.canSendMail()
                return verifyMechMuseIfNeeded(state: &state)

            case .setDestination(let destination):
                state.destination = destination

            case .setPreferences(let preferences):
                state.preferences = preferences
                return persistPreferences(state: state)
                    .merge(with: verifyMechMuseIfNeeded(state: &state))

            case .setMechMuseEnabled(let enabled):
                state.preferences.mechMuse.enabled = enabled
                return persistPreferences(state: state)
                    .merge(with: verifyMechMuseIfNeeded(state: &state))

            case .setMechMuseApiKey(let apiKey):
                state.preferences.mechMuse.apiKey = apiKey.isEmpty ? nil : apiKey
                return persistPreferences(state: state)
                    .merge(with: verifyMechMuseIfNeeded(state: &state))

            case .setErrorReportingEnabled(let enabled):
                state.preferences.errorReportingEnabled = enabled
                return persistPreferences(state: state)

            case .resetPreferences:
                try? preferencesClient.update { prefs in
                    prefs = Preferences()
                }
                state.preferences = Preferences()
                state.initialPreferences = Preferences()

            case .importDefaultContent:
                return .run { _ in
                    let importer = CompendiumImporter(compendium: compendium, metadata: compendiumMetadata)
                    try await importer.importDefaultContent()
                }

            case .sendFeedback:
                if mailer.canSendMail() {
                    mailer.sendMail(.init())
                }

            case .rateInAppStore:
                appReview.rateInAppStore()

            case .verifyMechMuseApiKey:
                guard state.preferences.mechMuse.enabled,
                      let apiKey = state.preferences.mechMuse.apiKey,
                      !apiKey.isEmpty else {
                    state.mechMuseVerificationState = .initial
                    return .cancel(id: CancelID.mechMuseVerification)
                }

                // Already verified with this key
                if state.mechMuseVerificationState.verifiedApiKey == apiKey {
                    return .none
                }

                state.mechMuseVerificationState = .loading

                return .run { send in
                    // Debounce
                    try await clock.sleep(for: .milliseconds(100))

                    do {
                        try await mechMuse.verifyAPIKey(apiKey)
                        await send(.mechMuseVerificationResult(.success(apiKey)))
                    } catch let error as MechMuseError {
                        await send(.mechMuseVerificationResult(.failure(error)))
                    } catch {
                        await send(.mechMuseVerificationResult(.failure(.unspecified)))
                    }
                }
                .cancellable(id: CancelID.mechMuseVerification, cancelInFlight: true)

            case .mechMuseVerificationResult(.success(let apiKey)):
                state.mechMuseVerificationState = .verified(apiKey: apiKey)

            case .mechMuseVerificationResult(.failure(let error)):
                state.mechMuseVerificationState = .failed(error)
            }
            return .none
        }
    }

    private func persistPreferences(state: State) -> Effect<Action> {
        // fixme preferences not consistently saved
        guard state.preferences != state.initialPreferences,
              state.preferences != Preferences() else {
            return .none
        }

        let preferences = state.preferences
        return .run { _ in
            try? preferencesClient.update { prefs in
                prefs = preferences
            }
        }
    }

    private func verifyMechMuseIfNeeded(state: inout State) -> Effect<Action> {
        guard state.preferences.mechMuse.enabled,
              let apiKey = state.preferences.mechMuse.apiKey,
              !apiKey.isEmpty else {
            state.mechMuseVerificationState = .initial
            return .cancel(id: CancelID.mechMuseVerification)
        }

        // Already verified with this key
        if state.mechMuseVerificationState.verifiedApiKey == apiKey {
            return .none
        }

        return .send(.verifyMechMuseApiKey)
    }
}

public extension SettingsFeature.State {
    static let nullInstance = Self()
}

