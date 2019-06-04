//
//  Checkbox.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 24/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct Checkbox: View {
    let selected: Bool
    var body: some View {
        Image(systemName: selected ? "checkmark.circle" : "circle")
            .font(Font.title.weight(.light))
            .foregroundColor(Color.accentColor)
    }
}
