//
//  ContentView.swift
//  DiceRollerAppClip
//
//  Created by Thomas Visser on 20/08/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import SwiftUI
import DiceRollerFeature
import ComposableArchitecture

struct ContentView: View {
    let store: StoreOf<DiceRollerFeature>

    var body: some View {
        DiceRollerView(store: store)
    }
}
