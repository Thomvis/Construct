import Compendium
import ComposableArchitecture
import Foundation
import GameModels
import Helpers
import Persistence

@Reducer
public struct DefaultContentSelectionFeature {
    public typealias AsyncApplySelection = Async<Set<DefaultContentRuleset>, EquatableError>
    public typealias AsyncDefaultDocumentStatus = Async<Database.DefaultContentDocumentStatus, EquatableError>

    @ObservableState
    public struct State: Equatable {
        var selection: Set<DefaultContentRuleset> = []
        var applySelection: AsyncApplySelection.State
        var defaultDocumentStatus: AsyncDefaultDocumentStatus.State

        var allowsSampleEncounterOnly = false
        var restoreSampleEncounter: Bool?
        var allowsDismissal = false
        var dismissalToken: String?

        var isValidSelection: Bool {
            !selection.isEmpty || allowsSampleEncounterOnly && restoreSampleEncounter == true
        }

        public init(
            selection: Set<DefaultContentRuleset>,
            restoreSampleEncounter: Bool? = nil,
            allowsSampleEncounterOnly: Bool = false,
            allowsDismissal: Bool = false,
            dismissalToken: String? = nil
        ) {
            @Dependency(\.uuid) var uuid
            self.selection = selection
            self.applySelection = .init(identifier: uuid())
            self.defaultDocumentStatus = .init(identifier: uuid())
            self.allowsSampleEncounterOnly = allowsSampleEncounterOnly
            self.restoreSampleEncounter = restoreSampleEncounter
            self.allowsDismissal = allowsDismissal
            self.dismissalToken = dismissalToken
        }
    }

    public enum Action: Equatable {
        case onAppear
        case toggleRuleset(DefaultContentRuleset)
        case setSampleEncounterEnabled(Bool)
        case applySelection
        case defaultDocumentStatus(AsyncDefaultDocumentStatus.Action)
        case applySelectionResponse(Result<Set<DefaultContentRuleset>, EquatableError>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case applied(Applied)

            public struct Applied: Equatable {
                public var selection: Set<DefaultContentRuleset>
                public var restoreSampleEncounter: Bool

                public init(
                    selection: Set<DefaultContentRuleset>,
                    restoreSampleEncounter: Bool
                ) {
                    self.selection = selection
                    self.restoreSampleEncounter = restoreSampleEncounter
                }
            }
        }
    }

    @Dependency(\.database) var database

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.defaultDocumentStatus(.startLoading))

            case .toggleRuleset(let ruleset):
                if state.selection.contains(ruleset) {
                    state.selection.remove(ruleset)
                } else {
                    state.selection.insert(ruleset)
                }

            case .setSampleEncounterEnabled(let isEnabled):
                state.restoreSampleEncounter = isEnabled

            case .applySelection:
                guard state.isValidSelection else {
                    state.applySelection.result = .failure(.init(DefaultContentSelectionError.emptySelection))
                    return .none
                }

                guard !state.selection.isEmpty else {
                    return .send(.delegate(.applied(.init(
                        selection: state.selection,
                        restoreSampleEncounter: state.restoreSampleEncounter == true
                    ))))
                }

                state.applySelection.isLoading = true
                state.applySelection.result = nil
                return .run { [selection = state.selection] send in
                    do {
                        try await database.applyDefaultContentSelection(selection)
                        await send(.applySelectionResponse(.success(selection)))
                    } catch {
                        await send(.applySelectionResponse(.failure(error.toEquatableError())))
                    }
                }

            case .applySelectionResponse(.success(let selection)):
                state.applySelection.isLoading = false
                state.applySelection.result = .success(selection)
                return .send(.delegate(.applied(.init(
                    selection: selection,
                    restoreSampleEncounter: state.restoreSampleEncounter == true
                ))))

            case .applySelectionResponse(.failure(let error)):
                state.applySelection.isLoading = false
                state.applySelection.result = .failure(error)

            case .delegate:
                break

            case .defaultDocumentStatus:
                break
            }

            return .none
        }
        Scope(state: \.defaultDocumentStatus, action: \.defaultDocumentStatus) {
            AsyncDefaultDocumentStatus {
                do {
                    return try database.defaultContentDocumentStatus()
                } catch {
                    throw error.toEquatableError()
                }
            }
        }
    }
}
