//
//  SimpleButton.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 06/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

func SimpleButton<Label>(action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View where Label: View {
    Button(action: action, label: label).buttonStyle(SimpleButtonStyle())
}

func SimpleAccentedButton<Label>(action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View where Label: View {
    Button(action: action, label: { label().foregroundColor(Color.accentColor) }).buttonStyle(SimpleButtonStyle())
}

private struct SimpleButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.66 : 1)
    }
}
