//
//  ActivityButton.swift
//  Construct
//
//  Created by Thomas Visser on 10/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct ActivityButton<Normal, Confirmation>: View where Normal: View, Confirmation: View{

    //                  (direction, state)
    //                  (normal, normal) -> (confirmation, normal) -> (confirmation, confirmation) -> (normal, confirmation) ->
    // normal:          center 1            center 1                a   bottom 1                        center 0             ad
    // confirmation:    center 0            top 1                       center 1                        center 1

    @State var state: ButtonState = .normal
    @State var direction: ButtonState = .normal
    @State var height: CGFloat = 0
    @State var cachedNormal: Normal?

    let normal: Normal
    let confirmation: Confirmation

    let action: () -> Void

    var body: some View {
        PropagateSize(content: Button(action: {
            guard self.direction == .normal && self.state == .normal else { return }
            self.cachedNormal = self.normal
            self.action()

            self.transition(to: .confirmation)
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.cachedNormal = nil
                self.transition(to: .normal)
            }
        }) {
            ZStack {
                (cachedNormal ?? normal)
                    .padding(4)
                    .offset(x: 0, y: direction == .confirmation && state == .confirmation ? height : 0)
                    .opacity(direction == .normal && state == .confirmation ? 0 : 1)
                    .animation(Animation.spring().delay(direction == .normal && state == .normal ? 0.33 : 0.0))

                confirmation
                    .padding(4)
                    .offset(x: 0, y: direction == .confirmation && state == .normal ? -height : 0)
                    .opacity(direction == .normal && state == .normal ? 0 : 1)
                    .animation(.spring())
            }
        }, id: "")
            .clipped()
            .onPreferenceChange(CollectionViewSizeKey<String>.self) { sizes in
                self.height = sizes[""]?.height ?? 0
            }
    }

    func transition(to state: ButtonState) {
        self.direction = state
        withAnimation {
            self.state = state
        }
    }

    enum ButtonState: Hashable {
        case normal
        case confirmation
    }
}
