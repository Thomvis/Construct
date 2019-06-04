//
//  StatBlockView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 23/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct StatBlockView: View {
    @EnvironmentObject var env: Environment

    let stats: StatBlock
    var onTap: ((TapTarget) -> Void)? = nil

    @State var parsedActions: [CreatureAction: CreatureActionParser.Action] = [:]
    
    var body: some View {
        VStack(alignment: .leading) {
            Group {
                Text(stats.name).font(.title).lineLimit(nil)
                Text(stats.subheading).italic().lineLimit(nil)
            }

            Group {
                if stats.armorClass != nil || stats.hitPointsSummary != nil || stats.speed != nil {
                    Divider()
                }

                stats.armorClass.map { Self.line(title: "Armor Class", text: "\($0)") }
                stats.hitPointsSummary.map { Self.line(title: "Hit Points", text: "\($0)") }
                stats.speed.map { Self.line(title: "Speed", text: $0) }
            }

            stats.abilityScores.map { abilityScores in
                Group {
                    Divider()

                    AbilityScoresView(scores: abilityScores, onTap: { a in
                        self.onTap?(.ability(a))
                    })
                }
            }

            // Tertiary info
            Group {
                if stats.hasTertiaryInfo {
                    Divider()
                }

                if !stats.savingThrows.isEmpty {
                    Self.line(title: "Saving Throws", text: stats.savingThrowsSummary(env))
                }

                if !stats.skills.isEmpty {
                    Self.line(title: "Skills", text: stats.skillsSummary(env))
                }

                stats.damageVulnerabilities.map { Self.line(title: "Damage Vulnerabilities", text: $0) }
                stats.damageResistances.map { Self.line(title: "Damage Resitances", text: $0) }
                stats.damageImmunities.map { Self.line(title: "Damage Immunities", text: $0) }
                stats.conditionImmunities.map { Self.line(title: "Condition Immunities", text: $0) }

                stats.senses.map { Self.line(title: "Senses", text: $0) }
                stats.languages.map { Self.line(title: "Languages", text: $0) }

                stats.challengeRating.map { Self.line(title: "Challenge Rating", text: $0.rawValue) }
            }

            if !stats.features.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(stats.features, id: \.name) { feature in
                        self.view(for: feature).onTapGesture {
                            // no-op
                        }
                    }
                }
            }

            if !stats.actions.isEmpty {
                Divider()

                Text("Actions").font(.title)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(stats.actions, id: \.name) { action in
                        self.view(for: action)
                    }
                }
            }
        }.onAppear {
            // parse actions
            stats.actions.compactMap { action in
                CreatureActionParser.parse(action.description).map { (action, $0) }
            }.forEach { parsedAction in
                self.parsedActions[parsedAction.0] = parsedAction.1
            }
        }
    }

    func view(for feature: CreatureFeature) -> some View {
        return (Text("\(feature.name). ").bold().italic() + Text(feature.description)).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
    }

    func view(for action: CreatureAction) -> some View {
        return Group {
            if let parsedAction = self.parsedActions[action] {
                SimpleButton(action: {
                    self.onTap?(.action(action, parsedAction))
                }, label: {
                    (Text(Image(systemName: "bolt.fill")).foregroundColor(Color.accentColor) + Text(" \(action.name). ").bold().italic().foregroundColor(Color.accentColor) + Text(action.description)).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                })
            } else {
                (Text(" \(action.name). ").bold().italic() + Text(action.description)).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    static func line(title: String, content: Text) -> some View {
        return Text("\(title) ").bold() + content
    }

    static func line(title: String, text: String) -> some View {
        return line(title: title, content: Text(text))
    }

    enum TapTarget {
        case ability(Ability)
        case action(CreatureAction, CreatureActionParser.Action)
    }
}

private struct AbilityScoresView: View {
    @EnvironmentObject var env: Environment
    let scores: AbilityScores
    var onTap: ((Ability) -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ForEach(abilityRows, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { ability in
                        SimpleButton(action: {
                            self.onTap?(ability)
                        }) {
                            VStack {
                                Text(ability.localizedAbbreviation.uppercased()).bold()
                                Text(self.scores.valueString(for: ability, env: self.env))
                            }
                            .frame(width: 80)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    var abilityRows: [[Ability]] {
        let columnCount = Ability.allCases.count / 2
        let res = stride(from: 0, to: Ability.allCases.count, by: columnCount).map {
            return Array(Ability.allCases[$0..<($0+columnCount)])
        }
        return res
    }
}

private extension StatBlock {
    var subheading: String {
        let type = [
            size?.localizedDisplayName,
            self.type?.nonEmptyString,
            (subtype?.nonEmptyString).map { "(\($0))"}
        ].compactMap { $0 }.joined(separator: " ").nonEmptyString

        let alignment = self.alignment?.localizedDisplayName
        return [type, alignment].compactMap { $0 }.joined(separator: ", ")
    }

    var hitPointsSummary: String? {
        return [
            hitPoints.map { "\($0)"},
            (hitPointDice?.description).map { "(\($0))" }
        ].compactMap { $0 }.joined(separator: " ").nonEmptyString
    }

    var speed: String? {
        guard let movement = movement else { return nil }
        if movement.count == 1, let walkingSpeed = movement[.walk] {
            return "\(walkingSpeed) ft."
        }

        let movements = MovementMode.allCases.compactMap { m in movement[m].map { s in "\(m.localizedDisplayName) \(s) ft." } }
        return movements.joined(separator: ", ")
    }

    func savingThrowsSummary(_ env: Environment) -> String {
        Ability.allCases.compactMap { k in savingThrows[k].map { v in "\(k.localizedAbbreviation.uppercased()) \(env.modifierFormatter.string(for: v.modifier) ?? "-")" } }.joined(separator: ", ")
    }

    func skillsSummary(_ env: Environment) -> String {
        Skill.allCases.compactMap { k in skills[k].map { v in "\(k.localizedDisplayName) \(env.modifierFormatter.string(for: v.modifier) ?? "-")" } }.joined(separator: ", ")
    }

    var hasTertiaryInfo: Bool {
        !savingThrows.isEmpty || !skills.isEmpty || damageVulnerabilities != nil || damageResistances != nil || damageImmunities != nil || conditionImmunities != nil || senses != nil || languages != nil || challengeRating != nil
    }
}

private extension AbilityScores {
    func valueString(for ability: Ability, env: Environment) -> String {
        let score = self.score(for: ability)
        guard let modifierString = env.modifierFormatter.string(for: score.modifier.modifier) else {
            return "\(score.score)"
        }
        return "\(score.score) (\(modifierString))"
    }
}
