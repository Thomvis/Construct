import ComposableArchitecture
import Compendium

@Reducer
struct WelcomeFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var page: Page.State? = .benefits
    }

    enum Action: Equatable {
        case alert(PresentationAction<Alert>)
        case didTapNext
        case didTapBack
        case didTapContinue
        case didTapSkip
        case page(PresentationAction<Page.Action>)
        case delegate(Delegate)

        enum Alert: Equatable {
            case confirmSkip
        }
    }
    
    @Reducer
    enum Page {
        case benefits
        case contentImport(DefaultContentSelectionFeature)
    }

    enum Delegate: Equatable {
        case dismissWelcomeSheet
        case openSampleEncounter(Set<DefaultContentRuleset>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .didTapNext:
                if case .contentImport = state.page {
                    return .none
                }
                state.page = .contentImport(Self.contentImportPageState)
                return .none
            case .didTapBack:
                state.page = .benefits
                return .none
            case .didTapContinue:
                return .send(.page(.presented(.contentImport(.applySelection))))
            case .didTapSkip:
                state.alert = AlertState {
                    TextState("Skip content import?")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                    ButtonState(action: .send(.confirmSkip)) {
                        TextState("Continue")
                    }
                } message: {
                    TextState("You can import Basic Rules content later from Settings.")
                }
                return .none
            case .alert(.presented(.confirmSkip)):
                state.alert = nil
                return .run { send in
                    // Work-around: without the sleep, the alert re-appears
                    // during the dismissal.
                    try await Task.sleep(nanoseconds: 0)
                    await send(.delegate(.dismissWelcomeSheet))
                }
            case .alert(.dismiss):
                state.alert = nil
                return .none
            case .page(.presented(.contentImport(.delegate(.applied(let appliedSelection))))):
                if appliedSelection.restoreSampleEncounter {
                    return .send(.delegate(.openSampleEncounter(
                        appliedSelection.selection
                    )))
                } else {
                    return .send(.delegate(.dismissWelcomeSheet))
                }
            case .page:
                return .none
            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$page, action: \.page)
    }

    static var contentImportPageState: DefaultContentSelectionFeature.State {
        .init(
            restoreSampleEncounter: true
        )
    }

    static func sampleEncounterRuleset(selection: Set<DefaultContentRuleset>) -> DefaultContentRuleset {
        if selection.contains(.rules2024) {
            return .rules2024
        }
        return .rules2014
    }
}

extension WelcomeFeature.Page.State: Equatable { }
extension WelcomeFeature.Page.Action: Equatable { }
