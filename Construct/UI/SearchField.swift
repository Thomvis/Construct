//
//  SearchField.swift
//  Construct
//
//  Created by Thomas Visser on 23/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct SearchField<Accessory>: View where Accessory: View {

    @Binding var text: String
    @State var focus = false

    var accessory: Accessory

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(Color.systemGray)
            TextField("Search...", text: $text, onEditingChanged: { began in
                self.focus = began
            })
            if !text.isEmpty && focus {
                SimpleButton(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color.systemGray)
                }
            } else {
                accessory
            }
        }
    }
}

struct BorderedSearchField<Accessory>: View where Accessory: View {

    let searchField: SearchField<Accessory>

    init(text: Binding<String>, accessory: Accessory) {
        self.searchField = SearchField(text: text, accessory: accessory)
    }

    var body: some View {
        searchField
        .padding(8)
        .background(Color.systemGray3.cornerRadius(4))
    }

}
