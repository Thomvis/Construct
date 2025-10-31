//
//  CompendiumItemGroupEditView.swift
//  Construct
//
//  Created by Thomas Visser on 05/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture
import Helpers
import GameModels
import Compendium

struct CompendiumItemGroupEditView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var store: StoreOf<CompendiumItemGroupEditFeature>
    @ObservedObject var viewStore: ViewStoreOf<CompendiumItemGroupEditFeature>

    init(store: StoreOf<CompendiumItemGroupEditFeature>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: \.self)
    }

    var body: some View {
        Form {
            Section {
                ClearableTextField("Name", text: viewStore.binding(get: \.group.title, send: { .groupTitle($0) }))
                    .disableAutocorrection(true)
            }

            Section(header: Text("Members")) {
                if viewStore.state.group.members.isEmpty {
                    Text("This party has no members").italic()
                } else {
                    ForEach(viewStore.state.group.members, id: \.itemKey) { member in
                        HStack {
                            Button(action: {
                                self.viewStore.send(.removeMember(member.itemKey))
                            }) {
                                Image(systemName: "minus.circle")
                            }.accentColor(Color(UIColor.systemRed))

                            Text(member.itemTitle)
                        }
                    }
                    .onDelete(perform: self.onDeleteMembers)
                }
            }

            Section(header: Text("All Characters")) {
                if let characters = viewStore.state.allCharacters.value {
                    if characters.isEmpty {
                        Text("No characters found in the compendium").italic()
                    }

                    ForEach(characters, id: \.key) { character in
                        HStack {
                            Button(action: {
                                self.viewStore.send(.addMember(character))
                            }) {
                                Image(systemName: "plus.circle")
                            }

                            VStack(alignment: .leading) {
                                Text(character.title)
                                Text(character.localizedSummary).font(.footnote).foregroundColor(Color(UIColor.secondaryLabel))
                            }
                        }.disabled(self.viewStore.state.group.contains(character))
                    }
                } else {
                    Text("Loading...")
                }
            }

            if viewStore.state.mode.isEdit {
                Section {
                    Button(action: {
                        self.viewStore.send(.onRemoveTap(self.viewStore.state.group))
                    }) {
                        Text("Remove group")
                            .foregroundColor(Color(UIColor.systemRed))
                    }
                }
            }
        }
        .onAppear {
            self.viewStore.send(.allCharacters(.startLoading))
        }
        .background(Group {
            if viewStore.state.mode.isEdit {
                EmptyView()
                    .navigationBarItems(
                        leading: Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                        },
                        trailing: Button(action: {
                            self.viewStore.send(.onDoneTap(self.viewStore.state.group))
                        }) {
                            Text("Done").bold()
                        }
                        .disabled(!self.viewStore.state.isValid)
                    )
                    .navigationBarBackButtonHidden(true)
            } else {
                EmptyView()
                    .navigationBarItems(
                        leading: Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                        },
                        trailing: Button(action: {
                            self.viewStore.send(.onAddTap(self.viewStore.state.group))
                        }) {
                            Text("Add").bold()
                        }
                        .disabled(!self.viewStore.state.isValid)
                    )
                    .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
            }
        })
    }

    func onDeleteMembers(_ indices: IndexSet) {
        for idx in indices {
            viewStore.send(.removeMember(viewStore.state.group.members[idx].itemKey))
        }
    }
}

struct CompendiumItemGroupEditFeature: Reducer {
    struct State: Equatable {
        var mode: Mode

        var group: CompendiumItemGroup

        typealias AsyncAllCharacers = Async<[Character], EquatableError>
        var allCharacters: AsyncAllCharacers.State = .initial

        var isValid: Bool {
            !group.title.isEmpty && !group.members.isEmpty
        }

        enum Mode: Equatable {
            case create
            case edit

            var isEdit: Bool {
                switch self {
                case .create: return false
                case .edit: return true
                }
            }
        }
    }

    enum Action: Equatable {
        case groupTitle(String)
        case allCharacters(State.AsyncAllCharacers.Action)

        case addMember(Character)
        case removeMember(CompendiumItemKey)

        case onAddTap(CompendiumItemGroup)
        case onDoneTap(CompendiumItemGroup)
        case onRemoveTap(CompendiumItemGroup)

        var allCharactersAction: State.AsyncAllCharacers.Action? {
            guard case .allCharacters(let a) = self else { return nil }
            return a
        }
    }

    @Dependency(\.compendium) var compendium

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .groupTitle(let s):
                state.group.title = s
            case .allCharacters: break // handled below
            case .addMember(let m):
                state.group.members.append(CompendiumItemReference(itemTitle: m.title, itemKey: m.key))
            case .removeMember(let key):
                state.group.members.removeAll { $0.itemKey == key }
            case .onAddTap, .onDoneTap, .onRemoveTap: break // should be handled by parent reducer
            }
            return .none
        }

        Scope(state: \.allCharacters, action: /Action.allCharacters) {
            Async<[Character], EquatableError> {
                try compendium.fetchAll(search: nil, filters: .init(types: [.character]), order: .title, range: nil)
                    .compactMap {
                        $0.item as? Character
                    }
            }
        }
    }
}

extension CompendiumItemGroupEditFeature.State: NavigationStackItemState {
    var navigationStackItemStateId: String { "CompendiumItemGroupEditView:\(group.id)" }
    var navigationTitle: String {
        if mode.isEdit {
            return ""
        } else {
            return "Add party"
        }
    }
}

extension CompendiumItemGroupEditFeature.State {
    static let nullInstance = CompendiumItemGroupEditFeature.State(mode: .create, group: CompendiumItemGroup.nullInstance, allCharacters: .initial)
}
