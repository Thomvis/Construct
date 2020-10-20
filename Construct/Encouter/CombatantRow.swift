//
//  CombatantRow.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 21/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct CombatantRow: View {
    @EnvironmentObject var env: Environment
    let encounter: Encounter
    let running: RunningEncounter?
    let combatant: Combatant
    let onHealthTap: () -> Void
    let onInitiativeTap: () -> Void

    var body: some View {
        HStack {
            combatant.hp.map { hp in
                SimpleButton(action: {
                    self.onHealthTap()
                }) {
                    HealthFractionView(hp: hp)
                }
            }?.accessibilitySortPriority(.hp)
            combatant.definition.ac.map { ShieldIcon(ac: $0) }?.accessibilitySortPriority(.ac)
            VStack(alignment: .leading) {
                combatant.discriminatedNameText()
                    .fontWeight(combatant.definition.player != nil ? .bold : .regular)
                    .accessibilitySortPriority(.name)

                secondaryText
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .layoutPriority(0.5)
                    .accessibilitySortPriority(.other)
            }.layoutPriority(0.5)
            Spacer()

            if hasExpiredTags {
                Image(systemName: "tag").foregroundColor(Color(UIColor.systemRed))
            }

            SimpleButton(action: {
                self.onInitiativeTap()
            }) {
                combatant.initiative.map {
                    Text("\($0)")
                        .accessibility(label: Text("Initiative: \($0)"))
                }.replaceNilWith {
                    combatant.definition.initiativeModifier.map {
                        Text(env.modifierFormatter.stringWithFallback(for: $0)).italic().opacity(0.6)
                            .accessibility(label: Text("Initiative modifier: \(env.modifierFormatter.stringWithFallback(for: $0))"))
                    }.replaceNilWith {
                        Text("--").italic().opacity(0.6)
                            .accessibility(hidden: true)
                    }
                }
                .background(Circle().foregroundColor(turnIndicatorColor).frame(width: 33, height: 33))
                .frame(minWidth: 44, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 5)
            }.accessibilitySortPriority(.initiative)
        }
        .opacity(combatant.isDead ? 0.33 : 1.0)
        .padding([.top, .bottom], 5)
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
    }

    // Returned text will contain at most two segments (i.e. different pieces of info)
    var secondaryText: Text? {
        var components: [Text] = []

        if !combatant.tags.isEmpty, let string = ListFormatter().string(from: combatant.tags.map { $0.title }) {
            components.append(Text(verbatim: string))
        }

        if !encounter.initiativeOrder.isEmpty && combatant.initiative == nil && running != nil {
            components.append(Text("Pending initiative roll"))
        }

        if let running = running,
            let latestEvent = running.log.last(where: { $0.involves(combatant) }),
            let turnCombatant = encounter.combatant(for: latestEvent.turn.combatantId),
            let eventText = RunningEncounterEventRow.eventString(encounter: encounter, event: latestEvent, context: combatant)?.string
        {
            let turnText = turnCombatant.discriminatedName + ", round \(latestEvent.turn.round)"
            components.append(Text("\(eventText) (turn: \(turnText))"))
        }

        // join
        if var result = components.first {
            for c in components.dropFirst().prefix(1) {
                result = result + Text(" | " ).foregroundColor(Color.accentColor) + c
            }
            return result
        }
        return nil
    }

    var turnIndicatorColor: Color {
        if running?.turn?.combatantId == combatant.id {
            return Color(UIColor.systemGreen)
        } else if let id = running?.turn?.combatantId, encounter.combatant(for: id)?.initiative == combatant.initiative {
            return Color(UIColor.systemGreen).opacity(0.33)
        }
        return Color.clear
    }

    var hasExpiredTags: Bool {
        guard let runningEncounter = running else { return false }
        for t in combatant.tags {
            if !runningEncounter.isTagValid(t, combatant) {
                return true
            }
        }
        return false
    }
}

func ShieldIcon(ac: Int) -> some View {
    ZStack {
        Image(systemName: "shield")
            .font(Font.title.weight(.light))
        Text("\(ac)")
            .font(.caption)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("AC: \(ac)"))
}

struct CombatantRow_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            CombatantRow(
                encounter: Encounter(name: "", combatants: []),
                running: nil,
                combatant: Combatant(adHoc: AdHocCombatantDefinition(
                    id: UUID(),
                    stats: apply(StatBlock.default) {
                        $0.name = "Sarovin"
                    }
                )),
                onHealthTap: { },
                onInitiativeTap: { }
            )
            .environmentObject(Environment(window: UIWindow()))
            .frame(height: 60)
            .previewLayout(.sizeThatFits)

            ShieldIcon(ac: 12).previewLayout(.sizeThatFits)
        }
    }
}

private extension CombatantRow {
    /// The available accessibility elements in the row. Higher numbers are featured first, so the case order matters.
    ///
    /// We're aiming for an order as follows;
    /// `<name>, <hp>, <ac>, <initiative>, <other info>`
    enum AccessibilityElements: Int {
        case other
        case initiative
        case ac
        case hp
        case name
        
        var sortPriority: Double {
            return Double(rawValue)
        }
    }
}

private extension View {
    func accessibilitySortPriority(_ accessibilityElement: CombatantRow.AccessibilityElements) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilitySortPriority(accessibilityElement.sortPriority)
    }
}
