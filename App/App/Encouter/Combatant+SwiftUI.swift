//
//  Combatant+SwiftUI.swift
//  Construct
//
//  Created by Thomas Visser on 27/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import GameModels

public extension Combatant {
    func discriminatedNameText(discriminatorColor: Color = Color(UIColor.secondaryLabel)) -> Text {
        Self.discriminatedNameText(name: name, discriminator: discriminator, discriminatorColor: discriminatorColor)
    }

    static func discriminatedNameText(
        name: String,
        discriminator: Int?,
        discriminatorColor: Color = Color(UIColor.secondaryLabel)
    ) -> Text {
        let n = Text(name)
        let d = discriminator.map {
            Text(" \($0)").foregroundColor(discriminatorColor)
        } ?? Text("")

        return n + d
    }
}
