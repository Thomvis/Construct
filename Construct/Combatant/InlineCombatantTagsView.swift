//
//  InlineCombatantTagsView.swift
//  Construct
//
//  Created by Thomas Visser on 15/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct InlineCombatantTagsView: View {
    var store: Store<CombatantDetailViewState, CombatantDetailViewAction>
    var viewStore: ViewStore<CombatantDetailViewState, CombatantDetailViewAction>

    var body: some View {
        if viewStore.state.combatant.tags.isEmpty {
            Text("No tags").italic()
        } else {
            CollectionView(data: viewStore.state.combatant.tags, id: \.definition.name) { tag in
                TagView(tag: tag, combatant: self.viewStore.state.combatant, runningEncounter: self.viewStore.state.runningEncounter, onDetailTap: {
                    if tag.hasLongNote || tag.duration != nil {
                        self.viewStore.send(.popover(.tagDetails(tag)))
                    } else {
                        self.viewStore.send(.setNextScreen(.combatantTagEditView(CombatantTagEditViewState(mode: .edit, tag: tag, effectContext: self.viewStore.state.runningEncounter.map { EffectContext(source: nil, targets: [self.viewStore.state.combatant], running: $0) }))))
                    }
                }, onRemoveTap: {
                    withAnimation(.default) {
                        self.viewStore.send(.combatant(.removeTag(tag)))
                    }
                })
            }
        }
    }
}

fileprivate struct TagView: View {
    let tag: CombatantTag
    let combatant: Combatant
    let runningEncounter: RunningEncounter?
    let onDetailTap: () -> Void
    let onRemoveTap: () -> Void

    var body: some View {
        Button(action: {
            self.onDetailTap()
        }) {
            HStack {
                HStack {
                    Text(tag.title)
                    if tag.hasLongNote {
                        Image(systemName: "text.bubble").font(.footnote)
                    }
                    if tag.duration != nil {
                        Image(systemName: "stopwatch")
                            .font(.footnote)
                            .foregroundColor(isTagActive ? Color.white : Color(UIColor.systemRed))
                    }
                }
                .padding(.leading, 6)
                .padding([.top, .bottom], 4)

                Button(action: {
                    self.onRemoveTap()
                }) {
                    Image(systemName: "xmark").font(.footnote)
                }
                .padding([.leading, .trailing], 6)
                .background(Color.black.opacity(0.2).padding([.top, .trailing, .bottom], -100))
            }
            .foregroundColor(Color.white)
            .background(isTagActive ? Color(UIColor.purple) : Color.black.opacity(0.2))
            .cornerRadius(4)
        }
    }

    var isTagActive: Bool {
        guard let runningEncounter = runningEncounter else { return true }
        return runningEncounter.isTagValid(tag, combatant)
    }
}
