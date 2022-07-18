//
//  Colors.swift
//  Construct
//
//  Created by Thomas Visser on 07/07/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

// From https://github.com/onmyway133/easyswiftui/blob/master/Sources/EasySwiftUI/Extensions/Color.swift

#if os(iOS)
public extension Color {

    // MARK: - Text Colors
    static let lightText = Color(UIColor.lightText)
    static let darkText = Color(UIColor.darkText)
    static let placeholderText = Color(UIColor.placeholderText)

    // MARK: - Label Colors
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    static let quaternaryLabel = Color(UIColor.quaternaryLabel)

    // MARK: - Background Colors
    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)

    // MARK: - Fill Colors
    static let systemFill = Color(UIColor.systemFill)
    static let secondarySystemFill = Color(UIColor.secondarySystemFill)
    static let tertiarySystemFill = Color(UIColor.tertiarySystemFill)
    static let quaternarySystemFill = Color(UIColor.quaternarySystemFill)

    // MARK: - Grouped Background Colors
    static let systemGroupedBackground = Color(UIColor.systemGroupedBackground)
    static let secondarySystemGroupedBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground = Color(UIColor.tertiarySystemGroupedBackground)

    // MARK: - Gray Colors
    static let systemGray = Color(UIColor.systemGray)
    static let systemGray2 = Color(UIColor.systemGray2)
    static let systemGray3 = Color(UIColor.systemGray3)
    static let systemGray4 = Color(UIColor.systemGray4)
    static let systemGray5 = Color(UIColor.systemGray5)
    static let systemGray6 = Color(UIColor.systemGray6)

    // MARK: - Other Colors
    static let separator = Color(UIColor.separator)
    static let opaqueSeparator = Color(UIColor.opaqueSeparator)
    static let link = Color(UIColor.link)

    // MARK: System Colors
    static let systemBlue = Color(UIColor.systemBlue)
    static let systemPurple = Color(UIColor.systemPurple)
    static let systemGreen = Color(UIColor.systemGreen)
    static let systemYellow = Color(UIColor.systemYellow)
    static let systemOrange = Color(UIColor.systemOrange)
    static let systemPink = Color(UIColor.systemPink)
    static let systemRed = Color(UIColor.systemRed)
    static let systemTeal = Color(UIColor.systemTeal)
    static let systemIndigo = Color(UIColor.systemIndigo)
}
#elseif os(macOS)
public extension Color {
    
    static func dynamic(dark: Int, light: Int) -> Color {
        let match = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua])
        return match == .darkAqua ? Color(hex: dark) : Color(hex: light)
    }

    init(hex: Int, alpha: Double = 1) {
        let components = (
            R: Double((hex >> 16) & 0xff) / 255,
            G: Double((hex >> 08) & 0xff) / 255,
            B: Double((hex >> 00) & 0xff) / 255
        )

        self.init(
            .sRGB,
            red: components.R,
            green: components.G,
            blue: components.B,
            opacity: alpha
        )
    }

    // MARK: - Text Colors
    static let placeholderText = Color(NSColor.placeholderTextColor)

    // MARK: - Label Colors
    static let label = Color(NSColor.labelColor)
    static let secondaryLabel = Color(NSColor.secondaryLabelColor)
    static let tertiaryLabel = Color(NSColor.tertiaryLabelColor)
    static let quaternaryLabel = Color(NSColor.quaternaryLabelColor)

    // MARK: - Background Colors
    static let systemBackground = Color(NSColor.windowBackgroundColor)
    static let secondarySystemBackground = Color(NSColor.windowBackgroundColor)
    static let tertiarySystemBackground = Color(NSColor.windowBackgroundColor)

    // MARK: - Gray Colors
    static let systemGray = Color(NSColor.systemGray)
    static let systemGray2 = Color.dynamic(dark: 0x636366, light: 0xAEAEB2)
    static let systemGray3 = Color.dynamic(dark: 0x48484A, light: 0xC7C7CC)
    static let systemGray4 = Color.dynamic(dark: 0x3A3A3C, light: 0xD1D1D6)
    static let systemGray5 = Color.dynamic(dark: 0x2C2C2E, light: 0xE5E5EA)
    static let systemGray6 = Color.dynamic(dark: 0x1C1C1E, light: 0xF2F2F7)

    // MARK: - Other Colors
    static let separator = Color(NSColor.separatorColor)
    static let link = Color(NSColor.linkColor)

    // MARK: System Colors
    static let systemBlue = Color(NSColor.systemBlue)
    static let systemPurple = Color(NSColor.systemPurple)
    static let systemGreen = Color(NSColor.systemGreen)
    static let systemYellow = Color(NSColor.systemYellow)
    static let systemOrange = Color(NSColor.systemOrange)
    static let systemPink = Color(NSColor.systemPink)
    static let systemRed = Color(NSColor.systemRed)
    static let systemTeal = Color(NSColor.systemTeal)
    static let systemIndigo = Color(NSColor.systemIndigo)
}
#endif
