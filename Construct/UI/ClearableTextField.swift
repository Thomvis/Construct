//
//  ClearableTextField.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 03/12/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct ClearableTextField: View {
    let title: String
    @Binding var text: String
    let onCommit: () -> Void
    @State var editing = false

    init(_ title: String, text: Binding<String>, onCommit: @escaping () -> Void = {}) {
        self.title = title
        _text = text
        self.onCommit = onCommit
    }

    var body: some View {
        HStack {
            TextField(title, text: $text, onEditingChanged: { editing in
                self.editing = editing
            }, onCommit: onCommit)

            if !text.isEmpty && editing {
                SimpleButton(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color(UIColor.systemGray))
                }
            }
        }
    }
}
