//
//  SimpleList.swift
//  Construct
//
//  Created by Thomas Visser on 19/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct SimpleList<Elements, ID, Content>: View where Elements: RandomAccessCollection, Content: View, ID: Hashable {

    var data: Elements
    var id: KeyPath<Elements.Element, ID>
    var content: (Elements.Element) -> Content

    var body: some View {
        VStack(spacing: 0) {
            ForEach(data, id: id) { e in
                self.content(e)
                    .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .overlay(Group {
                        if !self.isLast(e) {
                            Divider()
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    })
            }
        }
    }

    func isLast(_ e: Elements.Element) -> Bool {
        data.last?[keyPath: id] == e[keyPath: id]
    }
}
