//
//  CompendiumContainerView.swift
//  Construct
//
//  Created by Thomas Visser on 02/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels

struct CompendiumContainerView: View {
    @EnvironmentObject var environment: Environment
    var store: Store<CompendiumIndexState, CompendiumIndexAction>

    var body: some View {
        NavigationStack {
            CompendiumIndexView(store: store)
        }
    }
}

let compendiumRootReducer: AnyReducer<CompendiumIndexState, CompendiumIndexAction, Environment> = AnyReducer.combine(
    AnyReducer { state, action, env in
        if let monster = action.onSaveMonsterAsNPCButtonMonster {
            return .run { send in
                var stats = monster.stats
                stats.name = "\(stats.name) NPC"
                let character = Character(id: UUID().tagged(), realm: .homebrew, level: nil, stats: stats, player: nil)

                do {
                    // save character
                    let entry = CompendiumEntry(character)
                    try env.compendium.put(entry)

                    // configure view to display the character
                    await send(.query(.onFiltersDidChange(.init(types: [.character]))))
                    await send(.query(.onTextDidChange(nil)))
                    await send(.results(.result(.reload(.all))))
                    await send(.scrollTo(entry.key))
                    await send(.setNextScreen(nil))
                } catch { }
            }
        }
        return .none
    },
    CompendiumIndexState.reducer
)

extension CompendiumIndexAction {
    var onSaveMonsterAsNPCButtonMonster: Monster? {
        switch self {
        case .nextScreen(.compendiumEntry(CompendiumItemDetailViewAction.onSaveMonsterAsNPCButton(let m))),
             .detailScreen(.compendiumEntry(CompendiumItemDetailViewAction.onSaveMonsterAsNPCButton(let m))):
            return m
        case .nextScreen(.compendiumIndex(let a)), .detailScreen(.compendiumIndex(let a)):
            return a.onSaveMonsterAsNPCButtonMonster
        default:
            return nil
        }
    }
}
