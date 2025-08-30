//
//  RoundedButton.swift
//  
//
//  Created by Thomas Visser on 18/09/2022.
//

import Foundation
import SwiftUI

public func RoundedButton<Label>(color: Color = Color(UIColor.systemGray4), maxHeight: CGFloat? = nil, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View where Label: View {
    Button(action: action, label: label).buttonStyle(RoundedButtonStyle(color: color, maxHeight: maxHeight))
}

public func RoundedButton(color: Color = Color(UIColor.systemGray4), action: @escaping () -> Void, label: () -> SwiftUI.Label<Text, Image>) -> some View {
    Button(action: action) {
        label()
    }.buttonStyle(RoundedButtonStyle(color: color, maxHeight: nil))
}

struct VerticalStackLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

struct RoundedButtonStyle: SwiftUI.ButtonStyle {
    let color: Color
    let maxHeight: CGFloat?

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .labelStyle(VerticalStackLabelStyle())
            .foregroundColor(Color.accentColor)
            .font(.caption)
            .padding(EdgeInsets(top: 10, leading: 4, bottom: 10, trailing: 4))
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .background(Color(UIColor.systemBackground).opacity(configuration.isPressed ? 0.33 : 0).cornerRadius(8))
            .background(color.cornerRadius(8))
    }
}
