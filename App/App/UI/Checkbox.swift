//
//  Checkbox.swift
//  Construct
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
            .font(Font.title3.weight(.light))
            .foregroundColor(selected ? Color.accentColor : Color(UIColor.systemGray2))
    }
}
