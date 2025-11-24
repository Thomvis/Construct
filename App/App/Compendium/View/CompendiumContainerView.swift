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
    var store: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>

    var body: some View {
        NavigationStack {
            CompendiumIndexView(store: store)
        }
    }
}

struct CompendiumRootFeature: Reducer {
    typealias State = CompendiumIndexFeature.State
    typealias Action = CompendiumIndexFeature.Action

    @Dependency(\.compendium) var compendium

    var body: some ReducerOf<Self> {
        Reduce { state, action in
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
                        try compendium.put(entry)

                        // configure view to display the character
                        await send(.query(.onFiltersDidChange(.init(types: [.character]))))
                        await send(.query(.onTextDidChange(nil)))
                        await send(.results(.result(.reload(.all))))
                        await send(.scrollTo(entry.key))
                        await send(.setDestination(nil))
                    } catch { }
                }
            }
            return .none
        }
        CompendiumIndexFeature()
    }
}


extension CompendiumIndexFeature.Action {
    var onSaveMonsterAsNPCButtonMonster: Monster? {
        switch self {
        case .destination(.presented(.itemDetail(.onSaveMonsterAsNPCButton(let m)))):
            return m
        default:
            return nil
        }
    }
}
