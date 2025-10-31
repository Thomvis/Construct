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
    var store: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>

    var body: some View {
        NavigationStack {
            CompendiumIndexView(store: store)
        }
    }
}

let compendiumRootReducer: AnyReducer<CompendiumIndexFeature.State, CompendiumIndexFeature.Action, Environment> = AnyReducer.combine(
    AnyReducer { state, action, env in
        if let monster = action.onSaveMonsterAsNPCButtonMonster {
            return .run { send in
                var stats = monster.stats
                stats.name = "\(stats.name) NPC"
                let character = Character(id: UUID().tagged(), realm: .init(CompendiumRealm.homebrew.id), level: nil, stats: stats, player: nil)

                do {
                    // save character
                    let entry = CompendiumEntry(
                        character,
                        origin: .created(CompendiumItemReference(monster)),
                        document: .init(
                            id: CompendiumSourceDocument.homebrew.id,
                            displayName: CompendiumSourceDocument.homebrew.displayName
                        )
                    )
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
    AnyReducer { env in
        CompendiumIndexFeature(environment: env)
    }
    .pullback(state: \.self, action: /CompendiumIndexFeature.Action.self, environment: { $0 })
)

extension CompendiumIndexFeature.Action {
    var onSaveMonsterAsNPCButtonMonster: Monster? {
        switch self {
        case .nextScreen(.compendiumEntry(CompendiumEntryDetailFeature.Action.onSaveMonsterAsNPCButton(let m))),
             .detailScreen(.compendiumEntry(CompendiumEntryDetailFeature.Action.onSaveMonsterAsNPCButton(let m))):
            return m
        case .nextScreen(.compendiumIndex(let a)), .detailScreen(.compendiumIndex(let a)):
            return a.onSaveMonsterAsNPCButtonMonster
        default:
            return nil
        }
    }
}
