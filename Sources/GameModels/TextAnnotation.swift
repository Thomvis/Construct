//
//  TextAnnotation.swift
//  Construct
//
//  Created by Thomas Visser on 22/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers
import Dice

public enum TextAnnotation: Codable, Hashable {
    case diceExpression(DiceExpression)
    case reference(Reference)

    public enum Reference: Codable, Hashable {
        case compendiumItem(CompendiumItemReferenceTextAnnotation)
    }
}

/**
 Represents a piece of text that is believed to refer to a compendium item
 */
public struct CompendiumItemReferenceTextAnnotation: Codable, Hashable {
    public let text: String
    public let type: CompendiumItemType?

    public var resolvedTo: CompendiumItemReference?

    public init(text: String, type: CompendiumItemType?, resolvedTo: CompendiumItemReference? = nil) {
        self.text = text
        self.type = type
        self.resolvedTo = resolvedTo
    }
}

extension AttributedString {
    mutating func apply(_ located: Located<TextAnnotation>) {
        let start = index(startIndex, offsetByCharacters: located.range.startIndex)
        let end = index(startIndex, offsetByCharacters: located.range.endIndex)
        switch located.value {
        case .diceExpression(let d): self[start..<end].construct.diceExpression = d
        case .reference(.compendiumItem(let i)): self[start..<end].construct.compendiumItemReference = i
        }
    }
}
