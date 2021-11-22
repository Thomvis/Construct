//
//  ParseableCreatureAction.swift
//  Construct
//
//  Created by Thomas Visser on 16/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

typealias ParseableCreatureAction = Parseable<CreatureAction, ParsedCreatureAction, CreatureActionDomainParser>

extension ParseableCreatureAction {
    var name: String { input.name }
    var description: String { input.description }

    var attributedName: AttributedString {
        guard let parsed = result?.value else { return AttributedString(name) }

        var result = AttributedString(name)
        for annotation in parsed.nameAnnotations {
            result.apply(annotation)
        }
        return result
    }

    var attributedDescription: AttributedString {
        guard let parsed = result?.value else { return AttributedString(description) }

        var result = AttributedString(description)
        for annotation in parsed.descriptionAnnotations {
            result.apply(annotation)
        }
        return result
    }
}


struct CreatureActionDomainParser: DomainParser {
    static let version: String = "1"

    static func parse(input: CreatureAction) -> ParsedCreatureAction? {
        return ParsedCreatureAction(
            limitedUse: CreatureFeatureDomainParser.limitedUseInNameParser().run(input.name.lowercased()),
            action: CreatureActionParser.parse(input.description),
            otherDescriptionAnnotations: DiceExpressionParser.matches(in: input.description).map {
                $0.map { TextAnnotation.diceExpression($0) }
            }
        )
    }
}

struct ParsedCreatureAction: Codable, Hashable {

    /**
     Parsed from `name`. Range is scoped to `name`.
     */
    let limitedUse: Located<LimitedUse>?

    // TODO: action could contain some annotations
    let action: CreatureActionParser.Action?
    let otherDescriptionAnnotations: [Located<TextAnnotation>]?

    var nameAnnotations: [Located<TextAnnotation>] {
        limitedUse.flatMap { llu in
            guard case .turnStart = llu.value.recharge else { return nil }
            return [llu.map { _ in TextAnnotation.diceExpression(1.d(6)) }]
        } ?? []
    }

    var descriptionAnnotations: [Located<TextAnnotation>] {
        otherDescriptionAnnotations ?? []
    }

    /**
     Returns nil if all parameters are nil
     */
    init?(limitedUse: Located<LimitedUse>?, action: CreatureActionParser.Action?, otherDescriptionAnnotations: [Located<TextAnnotation>]?) {
        guard limitedUse != nil || action != nil || otherDescriptionAnnotations?.nonEmptyArray != nil else { return nil }

        self.limitedUse = limitedUse
        self.action = action
        self.otherDescriptionAnnotations = otherDescriptionAnnotations
    }

}
