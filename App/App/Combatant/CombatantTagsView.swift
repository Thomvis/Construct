//
//  CombatantTagsView.swift
//  Construct
//
//  Created by Thomas Visser on 21/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Tagged
import Helpers
import SharedViews
import GameModels

struct CombatantTagsView: View {
    @SwiftUI.Environment(\.sheetPresentationMode) var sheetPresentationMode: SheetPresentationMode?

    var store: Store<CombatantTagsFeature.State, CombatantTagsFeature.Action>
    @ObservedObject var viewStore: ViewStore<CombatantTagsFeature.State, CombatantTagsFeature.Action>

    init(store: Store<CombatantTagsFeature.State, CombatantTagsFeature.Action>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: \.self)
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                // Active tags
                with(viewStore.state.activeSections) { sections in
                    ForEach(sections, id: \.id) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.tagGroups, id: \.tag.id) { group in
                                NavigationRowButton(action: {
                                                                self.viewStore.send(.setDestination(.tagEdit(CombatantTagEditFeature.State(mode: .edit, tag: group.tag, effectContext: self.viewStore.state.effectContext))))
                                }) {
                                    HStack {
                                        Text(group.tag.title)

                                        Spacer()

                                        SimpleAccentedButton(action: {
                                            self.viewStore.send(.removeTag(CombatantTagsFeature.State.TagId(group.tag), section), animation: .default)
                                        }) {
                                            Image(systemName: "minus.circle").font(Font.title.weight(.light))
                                                .foregroundColor(Color.white)
                                        }
                                    }
                                    .foregroundColor(Color.white)
                                }
                            }.onDelete { indices in
                                for idx in indices {
                                    self.viewStore.send(.removeTag(CombatantTagsFeature.State.TagId(section.tagGroups[idx].tag), section))
                                }
                            }
                        }
                        .listRowBackground(Color(UIColor.systemPurple))
                        .listRowSeparatorTint(Color.white.opacity(0.33))
                    }
                }

                // All definitions
                ForEach(CombatantTagDefinition.Category.allCases, id: \.self) { category in
                    Group {
                        if CombatantTagDefinition.all(in: category).isEmpty {
                            EmptyView()
                        } else {
                            Section(header: Text(category.title)) {
                                ForEach(CombatantTagDefinition.all(in: category), id: \.name) { definition in
                                    NavigationRowButton(action: {
                                        let tag = CombatantTag(id: UUID().tagged(), definition: definition, note: nil, sourceCombatantId: self.viewStore.state.effectContext?.source?.id)
                                                                self.viewStore.send(.setDestination(.tagEdit(CombatantTagEditFeature.State(mode: .create, tag: tag, effectContext: self.viewStore.state.effectContext))))
                                    }) {
                                        HStack {
                                            Text(definition.name)

                                            Spacer()

                                            HStack(spacing: 6) {
                                                with(self.viewStore.state.allCombatantsSection) { section in
                                                    with(section?.tagGroups.filter { $0.tag.definition == definition } ?? []) { groups in
                                                        if !groups.isEmpty {
                                                            SimpleAccentedButton(action: {
                                                                if let group = groups.first, let section = section { // will be true because !group.isEmpty
                                                                    self.viewStore.send(.removeTag(CombatantTagsFeature.State.TagId(group.tag), section), animation: .default)
                                                                }
                                                            }) {
                                                                Image(systemName: "minus.circle")
                                                                    .font(Font.title.weight(.light))
                                                                    .accentColor(Color(UIColor.systemRed))
                                                            }
                                                            .disabled(groups.count > 1)
                                                        } else {
                                                            SimpleAccentedButton(action: {
                                                                let tag = CombatantTag(id: UUID().tagged(), definition: definition, note: nil, sourceCombatantId: self.viewStore.state.effectContext?.source?.id)
                                                                self.viewStore.send(.addTag(tag), animation: .default)
                                                            }) {
                                                                Image(systemName: "plus.circle").font(Font.title.weight(.light))
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(
            store: store.scope(state: \.$destination, action: { .destination($0) }),
            state: /CombatantTagsFeature.Destination.State.tagEdit,
            action: CombatantTagsFeature.Destination.Action.tagEdit
        ) { store in
            CombatantTagEditView(store: store)
        }
        .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
        .navigationBarItems(trailing: Group {
            if self.sheetPresentationMode != nil {
                Button(action: {
                    self.sheetPresentationMode?.dismiss()
                }) {
                    Text("Done").bold()
                }
            }
        })
    }
}
