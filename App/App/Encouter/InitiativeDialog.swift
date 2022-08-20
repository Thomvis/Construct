//
//  InitiativePopover.swift
//  Construct
//
//  Created by Thomas Visser on 26/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import SharedViews

struct InitiativePopover: Popover {
    var popoverId: AnyHashable { "InitiativePopover" }

    let action: (InitiativeSettings) -> Void
    func makeBody() -> AnyView {
        return AnyView(InitiativePopoverView(action: action))
    }
}

struct InitiativePopoverView: View {
    let action: (InitiativeSettings) -> Void
    @State var settings: InitiativeSettings = .default

    var body: some View {
        VStack {
            Toggle(isOn: $settings.group) {
                Text("Group creatures")
            }

            Toggle(isOn: $settings.rollForPlayerCharacters) {
                Text("Roll for player characters")
            }
            Toggle(isOn: $settings.overwrite) {
                Text("Overwrite existing initiatives")
            }
            Divider()
            Button(action: { self.action(self.settings) }) {
                Text("Roll")
            }
        }.padding([.leading, .trailing], 4)
    }
}
