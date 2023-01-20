//
//  AnimatingSymbol.swift
//  
//
//  Created by Thomas Visser on 18/01/2023.
//

import Foundation
import SwiftUI

public struct AnimatingSymbol: View {
    let systemName: String
    @State var value: Double = 0.0

    public init(systemName: String) {
        self.systemName = systemName
    }

    public var body: some View {
        Color.clear
            .modifier(Modifier(systemName: systemName, variableValue: value))
            .animation(.linear.repeatForever(autoreverses: false).speed(0.3), value: value)
            .onAppear {
                self.value = 1.0
            }
    }

    struct Modifier: Animatable, ViewModifier {
        let systemName: String
        var animatableData: Double

        init(systemName: String, variableValue: Double) {
            self.systemName = systemName
            animatableData = variableValue
        }

        func body(content: Content) -> some View {
            Image(systemName: systemName, variableValue: animatableData)
        }
    }
}
