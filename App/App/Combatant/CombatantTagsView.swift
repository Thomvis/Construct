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

    @Bindable var store: StoreOf<CombatantTagsFeature>

    var body: some View {
        VStack(spacing: 0) {
            List {
                let sections = store.activeSections
                // Active tags
                ForEach(sections, id: \.id) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.tagGroups, id: \.tag.id) { group in
                            NavigationRowButton(action: {
                                store.send(.setDestination(.tagEdit(CombatantTagEditFeature.State(mode: .edit, tag: group.tag, effectContext: store.effectContext))))
                            }) {
                                HStack {
                                    Text(group.tag.title)

                                    Spacer()

                                    SimpleAccentedButton(action: {
                                        store.send(.removeTag(CombatantTagsFeature.State.TagId(group.tag), section), animation: .default)
                                    }) {
                                        Image(systemName: "minus.circle").font(Font.title.weight(.light))
                                            .foregroundColor(Color.white)
                                    }
                                }
                                .foregroundColor(Color.white)
                            }
                        }.onDelete { indices in
                            for idx in indices {
                                store.send(.removeTag(CombatantTagsFeature.State.TagId(section.tagGroups[idx].tag), section))
                            }
                        }
                    }
                    .listRowBackground(Color(UIColor.systemPurple))
                    .listRowSeparatorTint(Color.white.opacity(0.33))
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
                                        let tag = CombatantTag(
                                            id: UUID().tagged(),
                                            definition: definition,
                                            note: nil,
                                            sourceCombatantId: store.effectContext?.source?.id
                                        )
                                        store.send(.setDestination(.tagEdit(CombatantTagEditFeature.State(mode: .create, tag: tag, effectContext: store.effectContext))))
                                    }) {
                                        HStack {
                                            Text(definition.name)

                                            Spacer()

                                            HStack(spacing: 6) {
                                                let section = store.allCombatantsSection
                                                let groups = section?.tagGroups.filter { $0.tag.definition == definition } ?? []

                                                if !groups.isEmpty {
                                                    SimpleAccentedButton(action: {
                                                        if let group = groups.first, let section = section { // will be true because !group.isEmpty
                                                            store.send(.removeTag(CombatantTagsFeature.State.TagId(group.tag), section), animation: .default)
                                                        }
                                                    }) {
                                                        Image(systemName: "minus.circle")
                                                            .font(Font.title.weight(.light))
                                                            .accentColor(Color(UIColor.systemRed))
                                                    }
                                                    .disabled(groups.count > 1)
                                                } else {
                                                    SimpleAccentedButton(action: {
                                                        let tag = CombatantTag(id: UUID().tagged(), definition: definition, note: nil, sourceCombatantId: store.effectContext?.source?.id)
                                                        store.send(.addTag(tag), animation: .default)
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
        .navigationDestination(
            item: $store.scope(state: \.destination, action: \.destination)
        ) { destinationStore in
            switch destinationStore.case {
            case let .tagEdit(store):
                CombatantTagEditView(store: store)
            }
        }
        .navigationBarTitle(Text(store.navigationTitle), displayMode: .inline)
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
