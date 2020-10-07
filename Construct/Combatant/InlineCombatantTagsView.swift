//
//  InlineCombatantTagsView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 15/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct InlineCombatantTagsView: View {
    var store: Store<CombatantDetailViewState, CombatantDetailViewAction>
    @ObservedObject var viewStore: ViewStore<CombatantDetailViewState, CombatantDetailViewAction>
    var appeared: State<Bool> = State(initialValue: false)

    var body: some View {
        Group {
            if viewStore.state.combatant.tags.isEmpty {
                Text("No tags").italic()
            } else {
                CollectionView(data: viewStore.state.combatant.tags, id: \.id, layout: flowLayout) { tag in
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
                    .stateDrivenNavigationLink(
                        store: store,
                        state: /CombatantDetailViewState.NextScreen.combatantTagEditView,
                        action: /CombatantDetailViewAction.NextScreenAction.combatantTagEditView,
                        isActive: { $0.tag.id == tag.id },
                        destination: CombatantTagEditView.init
                    )
                }
                .onAppear {
                    guard !self.appeared.wrappedValue else { return }
                    self.appeared.wrappedValue = true
                    // BUG: workaround for collection view layout issue
                    // relevant console log: "Bound preference CollectionViewSizeKey<UUID> tried to update multiple times per frame."
                    self.viewStore.send(.combatant(.addTag(CombatantTag.nullInstance)))
                    DispatchQueue.main.async {
                        self.viewStore.send(.combatant(.removeTag(CombatantTag.nullInstance)))
                    }
                }
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

                Button(action: {
                    self.onRemoveTap()
                }) {
                    Image(systemName: "xmark").font(.footnote)
                }
                .padding([.leading, .trailing], 6)
                .frame(maxHeight: 28) // fixme: assumption that text is not this high
                .background(Color.black.opacity(0.2))
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
