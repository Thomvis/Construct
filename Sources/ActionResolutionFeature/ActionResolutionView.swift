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
import MechMuse
import OpenAI
import Persistence
import SharedViews

public struct ActionResolutionView: View {
    @Bindable public var store: StoreOf<ActionResolutionFeature>

    public init(store: StoreOf<ActionResolutionFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack {
            HStack {
                Image(systemName: "quote.bubble").opacity(0) // for symmetry

                Spacer()

                VStack {
                    Text(store.heading).bold()
                    store.subheading.map(Text.init)?.italic()
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if store.isMuseEnabled {
                    Button {
                        store.send(.setMode(store.mode.toggled), animation: .default)
                    } label: {
                        Image(systemName: store.mode.isMuse ? "quote.bubble.fill" : "quote.bubble")
                    }
                }
            }
            Divider()

            switch store.mode {
            case .diceAction:
                if let diceStore = store.scope(state: \.diceAction, action: \.diceAction) {
                    DiceActionView(store: diceStore)
                }
            case .muse:
                ActionDescriptionView(store: store.scope(state: \.muse, action: \.muse))
            }

        }
        .onAppear {
            store.send(.onAppear)
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
    static func fromAction(name: String, description: String) -> some View {
        ZStack {
            ActionResolutionView(store: Store(
                initialState: ActionResolutionFeature.State(
                    creatureStats: StatBlock(
                        name: "Goblin"
                    ),
                    action: apply(ParseableCreatureAction(input: CreatureAction(
                        id: UUID(),
                        name: name,
                        description: description
                    ))) {
                        _ = $0.parseIfNeeded()
                    }
                )
            ) {
                ActionResolutionFeature()
            })
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground).cornerRadius(8))
        }
        .frame(maxHeight: .infinity)
        .background(Color.black)
    }

    static var previews: some View {
        fromAction(name: "Grapple", description: "Melee Weapon Attack: +4 to hit, reach 5 ft., one creature. Hit: 6 (1d8 + 2) bludgeoning damage, and the target is grappled (escape DC 14). Until this grapple ends, the creature is restrained, and the snake can't constrict another target.")

        fromAction(name: "Sting", description: "Melee Weapon Attack: +5 to hit, reach 5 ft., one creature. Hit: 7 (1d8 + 3) piercing damage, and the target must make a DC 11 Constitution saving throw, taking 9 (2d8) poison damage on a failed save, or half as much damage on a successful one. If the poison damage reduces the target to 0 hit points, the target is stable but poisoned for 1 hour, even after regaining hit points, and is paralyzed while poisoned in this way.")

        fromAction(name: "Dagger", description: "Melee or Ranged Weapon Attack: +4 to hit, reach 5 ft. or range 30/120 ft., one target. Hit: 9 (2d6 + 2) piercing damage in melee or 5 (1d6 + 2) piercing damage at range.")

        fromAction(name: "Versatile", description: "Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 7 (1d8 + 3) bludgeoning damage, or 8 (1d10 + 3) bludgeoning damage if used with two hands to make a melee attack, plus 3 (1d6) fire damage.")
    }
}
#endif
