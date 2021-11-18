//
//  StatBlockView.swift
//  Construct
//
//  Created by Thomas Visser on 23/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct StatBlockView: View {
    static let urlSchema = "construct-stat-block"

    @EnvironmentObject var env: Environment
    @ScaledMetric(relativeTo: .body)
    private var rollIconSize: CGFloat = 20

    let stats: StatBlock
    var onTap: ((TapTarget) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(stats.name).font(.title).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                    Text(stats.subheading).italic().lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if onTap != nil {
                    Menu(content: {
                        rollButtonMenu()
                    }) {
                        Label(title: {
                            Text("Roll...")
                        }, icon: {
                            Image("tabbar_d20")
                                .resizable().aspectRatio(contentMode: .fit)
                                .frame(height: rollIconSize)
                        })
                        .padding(8)
                    }
                }
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
                        CreatureFeatureView(feature: feature)
                    }
                }
            }

            if !stats.actions.isEmpty {
                Divider()

                Text("Actions").font(.title)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(stats.actions, id: \.name) { action in
                        CreatureActionView(action: action)
                    }
                }
            }

            if !stats.reactions.isEmpty {
                Divider()

                Text("Reactions").font(.title)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(stats.reactions, id: \.name) { reaction in
                        CreatureActionView(action: reaction)
                    }
                }
            }

            if let legendary = stats.legendary {
                Divider()

                Text("Legendary Actions").font(.title)

                VStack(alignment: .leading, spacing: 12) {

                    if let description = legendary.description {
                        Text(description).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(legendary.actions, id: \.name) { action in
                        CreatureActionView(action: action)
                    }
                }
            }

        }.environment(\.openURL, OpenURLAction { url in
            guard url.scheme == Self.urlSchema,
                  let host = url.host,
                  let target = try? TapTarget(urlEncoded: host)
            else {
                return .systemAction
            }

            onTap?(target)
            return .handled
        })
    }

    @ViewBuilder
    func rollButtonMenu() -> some View {
        Menu(content: {
            ForEach(Ability.allCases, id: \.self) { a in
                if let modifier = stats.savingThrowModifier(a) {
                    Button(action: {
                        onTap?(.rollCheck(1.d(20)+modifier.modifier))
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
        }) {
            Text("Saving throw...")
        }

        Divider()

        ForEach(Skill.allCases, id: \.rawValue) { s in
            let title = "\(s.localizedDisplayName) (\(s.ability.localizedAbbreviation.uppercased()))"
            if let modifier = stats.skillModifier(s) {
                Button(action: {
                    onTap?(.rollCheck(1.d(20)+modifier.modifier))
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
    }

    static func line(title: String, content: Text) -> some View {
        return Text("\(title) ").bold() + content
    }

    static func line(title: String, text: String) -> some View {
        return line(title: title, content: Text(text))
    }

    static func process(attributedString result: inout AttributedString) {
        for run in result.runs {
            let target: StatBlockView.TapTarget?
            if let diceExpression = run.construct.diceExpression {
                target = .rollCheck(diceExpression)
            } else if let ref = run.construct.compendiumItemReference {
                target = .rollCheck(1.d(100)) // FIXME
            } else {
                target = nil
            }

            if let target = target, let url = Self.link(for: target) {
                result[run.range].underlinedLink = url

                // clear original attribute
                result[run.range].construct.diceExpression = nil
            }
        }
    }

    static func link(for target: TapTarget) -> URL? {
        guard let urlEncoded = target.urlEncoded else { return nil }

        var urlComponents = URLComponents()
        urlComponents.scheme = StatBlockView.urlSchema
        urlComponents.host = urlEncoded

        return urlComponents.url
    }

    enum TapTarget: Codable {
        case ability(Ability)
        case action(CreatureAction, CreatureActionParser.Action)
        case rollCheck(DiceExpression)
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
        .foregroundColor(onTap != nil ? Color.accentColor : Color.primary)
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
        guard let movement = movement, movement.count > 0 else { return nil }
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

struct CreatureFeatureView: View {
    let feature: ParseableCreatureFeature

    var body: some View {
        (Text("\(feature.name). ").bold().italic() + Text(description))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    var description: AttributedString {
        var result = feature.attributedDescription
        StatBlockView.process(attributedString: &result)
        return result
    }
}

struct CreatureActionView: View {
    let action: ParseableCreatureAction

    var body: some View {
        text.lineLimit(nil).fixedSize(horizontal: false, vertical: true)
    }

    var text: Text {
        var description = action.attributedDescription
        StatBlockView.process(attributedString: &description)

        if let parsedAction = action.result?.value?.action {
            var title = AttributedString("\(action.name)")
            title.underlinedLink = StatBlockView.link(for: .action(action.input, parsedAction))
            title.attachment = NSTextAttachment(image: UIImage(systemName: "bolt.fill")!)

            return Text("\(Image(systemName: "bolt.fill")) \(title). ").bold().italic().foregroundColor(Color.accentColor) + Text(description)
        } else {
            return Text("\(action.name). ").bold().italic() + Text(description)
        }
    }

}

extension StatBlockView.TapTarget {
    init?(urlEncoded string: String) throws {
        guard let data = Data(base64Encoded: string) else {
            return nil
        }
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    var urlEncoded: String? {
        return try? JSONEncoder().encode(self).base64EncodedString()
    }
}
