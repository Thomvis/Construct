//
//  CombatantTagPopover.swift
//  Construct
//
//  Created by Thomas Visser on 15/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import SharedViews
import GameModels

struct CombatantTagPopover: View, Popover {
    var popoverId: AnyHashable { "CombatantTagPopover" }

    let running: RunningEncounter?
    let combatant: Combatant
    let tag: CombatantTag
    let onEditTap: () -> Void

    var body: some View {
        VStack {
            HStack {
                Text(tag.definition.name).bold() + Text(" (\(tag.definition.category.title))").italic()
                Spacer()
                Button(action: {
                    self.onEditTap()
                }) {
                    Text("Edit")
                }
            }
            Divider()

            VStack {
                tag.note.map {
                    Text("“\($0)”")
                        .padding(20)
                        .frame(minHeight: 120)
                }

                durationDescription.map {
                    Text(isTagActive ? "Expires " : "Expired ") + Text($0)
                }
            }
            .frame(minHeight: 120)
        }
    }

    var durationDescription: String? {
        guard let running = running, let currentRound = running.turn?.round, let turn = running.tagExpiresAt(tag, combatant), let turnCombatant = running.current.combatants[id: turn.combatantId] else { return nil }

        let roundString: String
        switch turn.round - currentRound {
        case ...(-2): roundString = "\(abs(turn.round - currentRound)) rounds ago"
        case -1: roundString = "last round"
        case 0: roundString = "this round"
        case 1: roundString = "next round"
        case 2...: roundString = "\(turn.round - currentRound) rounds from now"
        default: roundString = "round \(turn.round)"
        }

        return "\(turnCombatant.discriminatedName)'s turn, \(roundString)"
    }

    var isTagActive: Bool {
        guard let running = running else { return true }
        return running.isTagValid(tag, combatant)
    }

    func makeBody() -> AnyView {
        AnyView(self)
    }
}
