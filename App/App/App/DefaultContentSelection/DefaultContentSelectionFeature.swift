import Compendium
import ComposableArchitecture
import Foundation
import GameModels
import Helpers
import Persistence

@Reducer
public struct DefaultContentSelectionFeature {
    @ObservableState
    public struct State: Equatable {
        public struct SampleEncounterOption: Equatable {
            var title: String
            var subtitle: String?
            var isEnabled: Bool

            public init(title: String, subtitle: String? = nil, isEnabled: Bool) {
                self.title = title
                self.subtitle = subtitle
                self.isEnabled = isEnabled
            }
        }

        var selection: DefaultContentSelection
        var has2014Document = false
        var has2024Document = false
        var has2014UpdateAvailable = false
        var has2024UpdateAvailable = false
        var isImporting = false
        var error: EquatableError?
        var sampleEncounterOption: SampleEncounterOption?
        var allowsDismissal = false
        var dismissalToken: String?

        var isValidSelection: Bool {
            selection.hasAnySelection
        }

        public init(
            selection: DefaultContentSelection,
            sampleEncounterOption: SampleEncounterOption? = nil,
            allowsDismissal: Bool = false,
            dismissalToken: String? = nil
        ) {
            self.selection = selection
            self.sampleEncounterOption = sampleEncounterOption
            self.allowsDismissal = allowsDismissal
            self.dismissalToken = dismissalToken
        }
    }

    public enum Action: Equatable {
        case onAppear
        case toggle2014
        case toggle2024
        case setSampleEncounterEnabled(Bool)
        case applySelection
        case loadedStatusResponse(Result<Database.DefaultContentDocumentStatus, EquatableError>)
        case applySelectionResponse(Result<DefaultContentSelection, EquatableError>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case applied(DefaultContentSelection, restoreSampleEncounter: Bool)
        }
    }

    @Dependency(\.database) var database

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    do {
                        let status = try database.defaultContentDocumentStatus()
                        await send(.loadedStatusResponse(.success(status)))
                    } catch {
                        await send(.loadedStatusResponse(.failure(error.toEquatableError())))
                    }
                }

            case .toggle2014:
                state.selection.include2014.toggle()

            case .toggle2024:
                state.selection.include2024.toggle()

            case .setSampleEncounterEnabled(let isEnabled):
                state.sampleEncounterOption?.isEnabled = isEnabled

            case .applySelection:
                guard state.selection.hasAnySelection else {
                    state.error = EquatableError(DefaultContentSelectionError.emptySelection)
                    return .none
                }

                state.isImporting = true
                state.error = nil
                return .run { [selection = state.selection] send in
                    do {
                        try await database.applyDefaultContentSelection(selection)
                        await send(.applySelectionResponse(.success(selection)))
                    } catch {
                        await send(.applySelectionResponse(.failure(error.toEquatableError())))
                    }
                }

            case .loadedStatusResponse(.success(let status)):
                state.has2014Document = status.has2014Document
                state.has2024Document = status.has2024Document
                state.has2014UpdateAvailable = status.has2014UpdateAvailable
                state.has2024UpdateAvailable = status.has2024UpdateAvailable

            case .loadedStatusResponse(.failure(let error)):
                state.error = error

            case .applySelectionResponse(.success(let selection)):
                state.isImporting = false
                let restoreSampleEncounter = state.sampleEncounterOption?.isEnabled == true
                return .merge(
                    .send(.onAppear),
                    .send(.delegate(.applied(selection, restoreSampleEncounter: restoreSampleEncounter)))
                )

            case .applySelectionResponse(.failure(let error)):
                state.isImporting = false
                state.error = error

            case .delegate:
                break
            }

            return .none
        }
    }
}

extension DefaultContentSelectionFeature.State.SampleEncounterOption {
    static func loadSampleEncounter(defaultEnabled: Bool) -> Self {
        .init(
            title: "Load sample encounter",
            isEnabled: defaultEnabled
        )
    }
}
