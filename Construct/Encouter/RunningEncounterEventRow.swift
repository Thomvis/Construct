//
//  RunningEncounterEventRow.swift
//  Construct
//
//  Created by Thomas Visser on 11/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct RunningEncounterEventRow: View {
    let encounter: Encounter
    let event: RunningEncounterEvent

    // affects the way the event is described
    let context: Combatant?

    var body: some View {
        HStack {
            eventIcon

            VStack(alignment: .leading) {
                eventText
                encounter.combatant(for: event.turn.combatantId).map { combatant in
                    (combatant.discriminatedNameText() + Text("'s turn - Round \(event.turn.round)"))
                        .fixedSize(horizontal: true, vertical: false)
                        .font(.footnote).foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
        }
    }

    @ViewBuilder
    var eventIcon: some View {
        if let hp = event.combatantEvent?.effect.currentHp {
            if hp > 0 {
                Image(systemName: "suit.heart.fill").foregroundColor(Color(UIColor.systemGreen))
            } else if hp < 0 {
                Image(systemName: "suit.heart.fill").foregroundColor(Color(UIColor.systemRed))
            }
        }
    }

    var eventText: Text {
        guard let segments = Self.eventString(encounter: encounter, event: event, context: context) else {
            return Text("")
        }

        return segments.map { segment -> Text in
            switch segment.type {
            case .target: return Text(segment.text).bold()
            case .other: return Text(segment.text)
            }
        }.reduce(Text("")) { $0 + $1 }
    }

    static func eventString(encounter: Encounter, event: RunningEncounterEvent, context: Combatant?) -> [Segment]? {
        if let event = event.combatantEvent {
            let subject = encounter.combatant(for: event.target.id).map { Segment(text: $0.discriminatedName, type: .other) } ?? Segment(text: "Unknown", type: .other)
            if let currentHp = event.effect.currentHp {
                if currentHp > 0 {
                    if event.target.id == context?.id {
                        return [Segment(text: "Healed for ", type: .other), Segment(text: "\(currentHp) hp", type: .other)]
                    } else {
                        return [subject, Segment(text: " was healed for ", type: .other), Segment(text: "\(currentHp) hp", type: .target)]
                    }
                } else {
                    if event.target.id == context?.id {
                        return [Segment(text: "Hit for ", type: .other), Segment(text: "\(currentHp * -1) hp", type: .other)]
                    } else {
                        return [subject, Segment(text: " was hit for ", type: .other), Segment(text: "\(currentHp * -1) hp", type: .target)]
                    }
                }
            }
        }
        return nil
    }

    struct Segment {
        let text: String
        let type: SegmentType

        enum SegmentType {
            case target
            case other
        }
    }
}

extension Array where Element == RunningEncounterEventRow.Segment {
    var string: String {
        map { $0.text }.joined()
    }
}
