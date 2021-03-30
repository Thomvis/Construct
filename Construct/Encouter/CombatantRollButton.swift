//
//  CombatantRollButton.swift
//  Construct
//
//  Created by Thomas Visser on 24/03/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct CombatantRollButton: View {
    @EnvironmentObject var env: Environment
    
    let stats: StatBlock
    let rollCheck: (DiceCalculatorState) -> Void

    var body: some View {
        Menu(content: {
            ForEach(Ability.allCases.reversed(), id: \.self) { a in
                if let modifier = stats.savingThrowModifier(a) {
                    Button(action: {
                        rollCheck(DiceCalculatorState.rollingExpression(1.d(20)+modifier.modifier, rollOnAppear: true))
                    }) {
                        Label(
                            "\(a.localizedDisplayName) save: \(env.modifierFormatter.stringWithFallback(for: modifier.modifier))",
                            systemImage: stats.savingThrows[a] != nil
                                ? "circlebadge.fill"
                                : "circlebadge"
                        )
                    }
                } else {
                    Text(a.localizedDisplayName)
                }
            }

            Divider()

            Menu(content: {
                ForEach(Ability.allCases.reversed(), id: \.rawValue) { a in
                    if let modifier = stats.abilityScores?.score(for: a).modifier {
                        Button(action: {
                            rollCheck(DiceCalculatorState.rollingExpression(1.d(20)+modifier.modifier, rollOnAppear: true))
                        }) {
                            Label(title: {
                                Text("\(a.localizedDisplayName): \(env.modifierFormatter.stringWithFallback(for: modifier.modifier))")
                            }, icon: {
                                Image(systemName: "circlebadge")
                            })
                        }
                    } else {
                        Text(a.localizedDisplayName)
                    }
                }

                Divider()

                ForEach(Skill.allCases.reversed(), id: \.rawValue) { s in
                    let title = "\(s.localizedDisplayName) (\(s.ability.localizedAbbreviation.uppercased()))"
                    if let modifier = stats.skillModifier(s) {
                        Button(action: {
                            rollCheck(DiceCalculatorState.rollingExpression(1.d(20)+modifier.modifier, rollOnAppear: true))
                        }) {
                            Label(title: {
                                Text("\(title): \(env.modifierFormatter.stringWithFallback(for: modifier.modifier))")
                            }, icon: {
                                Image(systemName: stats.skills[s] != nil
                                        ? "circlebadge.fill"
                                        : "circlebadge"
                                )
                            })
                        }
                    } else {
                        Text("\(title)")
                    }
                }
            }) {
                Text("Ability Check...")
            }
        }) {
            RoundedButton(action: { }) {
                Label("Roll...", systemImage: "die.face.6")
            }
            .frame(minWidth: 100, maxWidth: 250)
        }
    }
}
