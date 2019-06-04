//
//  RoundedButton.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 07/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

func RoundedButton<Label>(color: Color = Color(UIColor.systemGray4), action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View where Label: View {
    Button(action: action, label: label).buttonStyle(RoundedButtonStyle(color: color))
}

func RoundedButton(color: Color = Color(UIColor.systemGray4), action: @escaping () -> Void, label: () -> SwiftUI.Label<Text, Image>) -> some View {
    Button(action: action) {
        label().labelStyle(VerticalStackLabelStyle())
    }.buttonStyle(RoundedButtonStyle(color: color))
}

private struct RoundedButtonStyle: SwiftUI.ButtonStyle {
    let color: Color

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(Color.accentColor)
            .font(.caption)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground).opacity(configuration.isPressed ? 0.33 : 0).cornerRadius(8))
            .background(color.cornerRadius(8))
    }
}

struct VerticalStackLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
