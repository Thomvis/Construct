//
//  HealthFractionView.swift
//  Construct
//
//  Created by Thomas Visser on 08/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import GameModels

struct HealthFractionView: View {
    var hp: Hp
    @State var anim: Double = -1

    var body: some View {
        VStack(spacing: 0) {
            Text("-").modifier(EffectiveModifier(anim: $anim, number: Double(hp.effective))).animation(.easeOut(duration: 0.66), value: hp.effective)
            Divider()
            Text("\(hp.maximum)").foregroundColor(Color(UIColor.secondaryLabel))
        }
        .background(Rectangle().cornerRadius(4).foregroundColor(colorForDirection.opacity(0.33)).animation(.easeInOut(duration: 0.33), value: hp.effective))
        .font(.footnote)
        .frame(width: 25)
        .accessibilityElement(children: .ignore)
        .accessibility(label: Text(hp.accessibilityText))
    }

    var colorForDirection: Color {
        guard anim >= 0 else { return Color.clear }

        let ed = Double(hp.effective)
        if anim < ed {
            return Color(UIColor.systemGreen)
        } else if anim > ed {
            return Color(UIColor.systemRed)
        } else {
            return Color.clear
        }
    }

    struct EffectiveModifier: AnimatableModifier {
        @Binding var anim: Double
        var number: Double

        var animatableData: Double {
            get { number }
            set {
                let a = $anim
                DispatchQueue.main.async { a.wrappedValue = newValue }

                number = newValue
            }
        }

        func body(content: Content) -> some View {
            return Text("\(Int(round(number)))").fontWeight(.medium).animation(nil)
        }

    }
}
