//
//  ActionResolutionView.swift
//  
//
//  Created by Thomas Visser on 08/12/2022.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Helpers
import DiceRollerFeature
import GameModels
import CombineSchedulers
import MechMuse
import OpenAIClient
import Persistence

public struct ActionResolutionView: View {
    public let store: Store<ActionResolutionViewState, ActionResolutionViewAction>

    public init(store: Store<ActionResolutionViewState, ActionResolutionViewAction>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                HStack {
                    Image(systemName: "quote.bubble").opacity(0) // for symmetry

                    Spacer()

                    VStack {
                        Text(viewStore.state.heading).bold()
                        viewStore.state.subheading.map(Text.init)?.italic()
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    if viewStore.state.isMuseEnabled {
                        Button {
                            viewStore.send(.binding(.set(\.$mode, viewStore.state.mode.toggled)), animation: .default)
                        } label: {
                            Image(systemName: viewStore.state.mode.isMuse ? "quote.bubble.fill" : "quote.bubble")
                        }
                    }
                }
                Divider()

                switch viewStore.state.mode {
                case .diceAction:
                    IfLetStore(store.scope(state: \.diceAction, action: ActionResolutionViewAction.diceAction)) { store in
                        DiceActionView(store: store)
                    }
                case .muse:
                    ActionDescriptionView(store: store.scope(state: \.muse, action: ActionResolutionViewAction.muse))
                }

            }
        }
    }
}

struct FeedbackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Feedback?").font(.footnote)
        }
        .buttonStyle(.bordered)
    }
}

#if DEBUG
struct ActionResolutionView_Preview: PreviewProvider {
    static var previews: some View {
        ZStack {
            ActionResolutionView(store: Store(
                initialState: ActionResolutionViewState(
                    creatureStats: StatBlock(
                        name: "Goblin"
                    ),
                    action: apply(ParseableCreatureAction(input: CreatureAction(
                        id: UUID(),
                        name: "Scimitar",
                        description: "Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage."
                    ))) {
                        _ = $0.parseIfNeeded()
                    },
                    preferences: Preferences()
                ),
                reducer: ActionResolutionViewState.reducer,
                environment: StandaloneActionResolutionEnvironment()
            ))
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground).cornerRadius(8))
        }
        .frame(maxHeight: .infinity)
        .background(Color.black)
    }
}

struct StandaloneActionResolutionEnvironment: ActionResolutionEnvironment {
    var modifierFormatter = Helpers.modifierFormatter
    var mainQueue: AnySchedulerOf<DispatchQueue> = DispatchQueue.immediate.eraseToAnyScheduler()
    var diceLog = DiceLogPublisher()
    var mechMuse = MechMuse(
        clientProvider: AsyncThrowingStream([OpenAIClient(apiKey: "")].async),
        describeAction: { client, request, tov in
            try await Task.sleep(for: .seconds(0.5))
            return "Here's a description for prompt: \(request.prompt(toneOfVoice: tov))"
        },
        verifyAPIKey: { client in
            try await Task.sleep(for: .seconds(1))
        }
    )
    var canSendMail: () -> Bool  = { true }
    var sendMail: (FeedbackMailContents) -> Void = { _ in }
}
#endif
