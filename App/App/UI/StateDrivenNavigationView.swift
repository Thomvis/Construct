//
//  StateDrivenNavigationView.swift
//  Construct
//
//  Created by Thomas Visser on 04/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

func NavigationRowButton<Label>(action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View where Label: View {
    return Button(action: action) {
        HStack {
            label()
            Spacer()
            Image(systemName: "chevron.right").font(Font.body.weight(.semibold)).foregroundColor(Color(UIColor.systemGray3)).scaleEffect(0.8)
        }
    }
    .foregroundColor(Color.primary)
    .buttonStyle(.borderless)
}
