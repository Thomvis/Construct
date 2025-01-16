//
//  MenuPickerField.swift
//  
//
//  Created by Thomas Visser on 06/09/2023.
//

import Foundation
import SwiftUI

public struct MenuPickerField<Value, MenuBody>: View where Value: Hashable, MenuBody: View {
    let title: String
    let selection: Binding<Value?>
    @ViewBuilder let menuBody: () -> MenuBody

    @Environment(\.isEnabled) var isEnabled: Bool

    public init(
        title: String,
        selection: Binding<Value?>,
        @ViewBuilder menuBody: @escaping () -> MenuBody
    ) {
        self.title = title
        self.selection = selection
        self.menuBody = menuBody
    }

    public var body: some View {
        LabeledContent {
            Picker(title, selection: selection) {
                if selection.wrappedValue == nil {
                    Text("Select").tag(Optional<Value>.none)

                    Divider()
                }

                menuBody()
            }
            .truncationMode(.middle)
        } label: {
            Text(title)
                .foregroundStyle(isEnabled ? .primary : .secondary)
        }
        .animation(nil, value: selection.wrappedValue)
        .frame(minHeight: 35)
    }
}
