//
//  CompendiumItemGroupDetailView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 05/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct CompendiumItemGroupDetailView: View {
    @EnvironmentObject var env: Environment
    let group: CompendiumItemGroup

    var body: some View {
        VStack {
            SectionContainer(title: "Members") {
                if group.members.isEmpty {
                    Text("This party has no members")
                } else {
                    SimpleList(data: group.members, id: \.itemKey) { member in
                        Text(member.itemTitle)
                    }
                }
            }
        }
    }
}

extension AddCombatantState: Identifiable {
    var id: String { "" }
}
