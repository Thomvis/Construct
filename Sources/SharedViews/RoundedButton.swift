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

public struct RoundedButtonLabel<Label>: View where Label: View {
    let color: Color
    let maxHeight: CGFloat?
    let label: () -> Label

    public init(
        color: Color = Color(UIColor.systemGray4),
        maxHeight: CGFloat? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.color = color
        self.maxHeight = maxHeight
        self.label = label
    }

    public var body: some View {
        label()
            .modifier(RoundedButtonBase(color: color, maxHeight: maxHeight))
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

struct RoundedButtonStyle: SwiftUI.ButtonStyle {
    let color: Color
    let maxHeight: CGFloat?

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .modifier(RoundedButtonBase(color: color, maxHeight: maxHeight, isPressed: configuration.isPressed))
    }
}

private struct RoundedButtonBase: ViewModifier {
    let color: Color
    let maxHeight: CGFloat?
    let isPressed: Bool

    init(color: Color, maxHeight: CGFloat?, isPressed: Bool = false) {
        self.color = color
        self.maxHeight = maxHeight
        self.isPressed = isPressed
    }

    func body(content: Content) -> some View {
        content
            .labelStyle(VerticalStackLabelStyle())
            .foregroundColor(Color.accentColor)
            .font(.caption)
            .padding(EdgeInsets(top: 10, leading: 4, bottom: 10, trailing: 4))
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .background(Color(UIColor.systemBackground).opacity(isPressed ? 0.33 : 0).cornerRadius(8))
            .background(color.cornerRadius(8))
    }
}
