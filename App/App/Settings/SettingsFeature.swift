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
import Sharing

@Reducer
public struct SettingsFeature {

    public init() { }

    @ObservableState
    public struct State: Equatable {
        var destination: Destination?
        @Shared(.entity(Preferences.key)) var preferences = Preferences()
        var mechMuseVerificationState: MechMuseVerificationState = .initial
        var canSendMail: Bool = false
        @Presents var defaultContentSelection: DefaultContentSelectionFeature.State?

        public init(
            destination: Destination? = nil
        ) {
            self.destination = destination
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
        case setDefaultContentSelection(Bool)
        case defaultContentSelection(PresentationAction<DefaultContentSelectionFeature.Action>)
        case setMechMuseEnabled(Bool)
        case setMechMuseApiKey(String)
        case setErrorReportingEnabled(Bool)
        case setAdventureTabMode(Preferences.AdventureTabMode)
        case resetPreferences
        case importDefaultContent
        case sendFeedback
        case rateInAppStore
        case delegate(Delegate)

        // Mech Muse verification
        case verifyMechMuseApiKey
        case mechMuseVerificationResult(Result<String, MechMuseError>)

        public enum Delegate: Equatable {
            case sampleEncounterRestored(Encounter, openInCampaignBrowser: Bool)
        }
    }

    @Dependency(\.mailer) var mailer
    @Dependency(\.appReview) var appReview
    @Dependency(\.database) var database
    @Dependency(\.crashReporter) var crashReporter
    @Dependency(\.mechMuse) var mechMuse
    @Dependency(\.continuousClock) var clock

    private enum CancelID: Hashable {
        case mechMuseVerification
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.canSendMail = mailer.canSendMail()
                return verifyMechMuseIfNeeded(state: &state)

            case .setDestination(let destination):
                state.destination = destination

            case .setDefaultContentSelection(let presented):
                if presented {
                    if let selection = try? database.defaultContentSelectionNeedingImport() {
                        state.defaultContentSelection = .init(
                            selection: selection,
                            restoreSampleEncounter: false,
                            allowsSampleEncounterOnly: true
                        )
                    } else {
                        state.defaultContentSelection = .init(
                            selection: [],
                            restoreSampleEncounter: false,
                            allowsSampleEncounterOnly: true
                        )
                    }
                } else {
                    state.defaultContentSelection = nil
                }

            case .defaultContentSelection(.presented(.delegate(.applied(let appliedSelection)))):
                let defaultDocumentStatus = state.defaultContentSelection?.defaultDocumentStatus.value
                let sampleEncounterRuleset = Self.sampleEncounterRuleset(
                    selection: appliedSelection.selection,
                    defaultDocumentStatus: defaultDocumentStatus
                )
                let shouldOpenInCampaignBrowser = (state.preferences.adventureTabMode ?? .simpleEncounter) == .simpleEncounter
                state.defaultContentSelection = nil
                guard appliedSelection.restoreSampleEncounter else {
                    return .none
                }
                return .run { send in
                    if let encounter = SampleEncounter.restore(
                        database: database,
                        crashReporter: crashReporter,
                        ruleset: sampleEncounterRuleset
                    ) {
                        await send(.delegate(.sampleEncounterRestored(
                            encounter,
                            openInCampaignBrowser: shouldOpenInCampaignBrowser && !encounter.isScratchPad
                        )))
                    }
                }

            case .defaultContentSelection:
                break

            case .setMechMuseEnabled(let enabled):
                state.$preferences.withLock { $0.mechMuse.enabled = enabled }
                return verifyMechMuseIfNeeded(state: &state)

            case .setMechMuseApiKey(let apiKey):
                state.$preferences.withLock { $0.mechMuse.apiKey = apiKey.isEmpty ? nil : apiKey }
                return verifyMechMuseIfNeeded(state: &state)

            case .setErrorReportingEnabled(let enabled):
                state.$preferences.withLock { $0.errorReportingEnabled = enabled }

            case .setAdventureTabMode(let mode):
                state.$preferences.withLock { $0.adventureTabMode = mode }

            case .resetPreferences:
                state.$preferences.withLock { $0 = Preferences() }

            case .importDefaultContent:
                return .run { _ in
                    let selection = try database.suggestedDefaultContentSelection()
                    try await database.applyDefaultContentSelection(selection)
                }

            case .sendFeedback:
                if mailer.canSendMail() {
                    mailer.sendMail(.init())
                }

            case .rateInAppStore:
                return .run { _ in
                    await appReview.rateInAppStore()
                }
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

            case .delegate:
                break
            }
            return .none
        }
        .ifLet(\.$defaultContentSelection, action: \.defaultContentSelection) {
            DefaultContentSelectionFeature()
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

    private static func sampleEncounterRuleset(
        selection: Set<DefaultContentRuleset>,
        defaultDocumentStatus: Database.DefaultContentDocumentStatus?
    ) -> DefaultContentRuleset {
        if selection.contains(.rules2024) {
            return .rules2024
        }
        if selection.contains(.rules2014) {
            return .rules2014
        }
        if defaultDocumentStatus?.importedRulesets.contains(.rules2024) == true {
            return .rules2024
        }
        return .rules2014
    }
}

public extension SettingsFeature.State {
    static let nullInstance = Self()
}
