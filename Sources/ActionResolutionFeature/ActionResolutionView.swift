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
                    }

                    Spacer()

                    Button {
                        viewStore.send(.binding(.set(\.$mode, viewStore.state.mode.toggled)), animation: .default)
                    } label: {
                        Image(systemName: viewStore.state.mode.isMuse ? "quote.bubble.fill" : "quote.bubble")
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

struct BetaLabel: View {
    var body: some View {
        Text("BETA")
            .font(.footnote)
            .foregroundColor(Color.white)
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .background(Color(UIColor.systemGray).cornerRadius(4))
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
                    }
                ),
                reducer: ActionResolutionViewState.reducer,
                environment: StandaloneActionResolutionEnvironment()
            ))
            .padding(12)
            .background(Color.white.cornerRadius(8))
        }
        .frame(maxHeight: .infinity)
        .background(Color.black)
    }
}

struct StandaloneActionResolutionEnvironment: ActionResolutionEnvironment {
    var modifierFormatter = Helpers.modifierFormatter
    var mainQueue: AnySchedulerOf<DispatchQueue> = DispatchQueue.immediate.eraseToAnyScheduler()
    var diceLog = DiceLogPublisher()
    var mechMuse = MechMuse { client, request, tov in
        try await Task.sleep(for: .seconds(1))
        return "Here's a description for prompt: \(request.prompt(toneOfVoice: tov))"
    }
}
#endif