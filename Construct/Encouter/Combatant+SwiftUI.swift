//
//  Combatant+SwiftUI.swift
//  Construct
//
//  Created by Thomas Visser on 27/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

extension Combatant {
    func discriminatedNameText(discriminatorColor: Color = Color.secondaryLabel) -> Text {
        let n = Text(name)
        let d = discriminator.map {
            Text(" \($0)").foregroundColor(discriminatorColor)
        } ?? Text("")

        return (n + d).strikethrough(isDead, color: Color.systemRed)
    }

    var discriminatedName: String {
        if let discriminator = discriminator {
            return "\(name) \(discriminator)"
        }
        return name
    }
}
