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

struct CompendiumItemGroupEditView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var store: Store<CompendiumItemGroupEditState, CompendiumItemGroupEditAction>
    @ObservedObject var viewStore: ViewStore<CompendiumItemGroupEditState, CompendiumItemGroupEditAction>

    init(store: Store<CompendiumItemGroupEditState, CompendiumItemGroupEditAction>) {
        self.store = store
        self.viewStore = ViewStore(store)
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

struct CompendiumItemGroupEditState: Equatable {
    var mode: Mode

    var group: CompendiumItemGroup

    var allCharacters: Async<[Character], Error, Environment> = .initial

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

enum CompendiumItemGroupEditAction: Equatable {
    case groupTitle(String)
    case allCharacters(Async<[Character], Error, Environment>.Action)

    case addMember(Character)
    case removeMember(CompendiumItemKey)

    case onAddTap(CompendiumItemGroup)
    case onDoneTap(CompendiumItemGroup)
    case onRemoveTap(CompendiumItemGroup)

    var allCharactersAction: Async<[Character], Error, Environment>.Action? {
        guard case .allCharacters(let a) = self else { return nil }
        return a
    }
}

extension CompendiumItemGroupEditState {
    static var reducer: Reducer<Self, CompendiumItemGroupEditAction, Environment> = Reducer.combine(
        Reducer { state, action, environment in
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
        },
        Async<[Character], Error, Environment>.reducer { env in
            env.compendium.fetchAll(query: nil, types: [.character]).map { entries in
                entries.compactMap { $0.item as? Character }
            }.eraseToAnyPublisher()
        }.pullback(state: \.allCharacters, action: /CompendiumItemGroupEditAction.allCharacters)
    )
}

extension CompendiumItemGroupEditState: NavigationStackItemState {
    var navigationStackItemStateId: String { "CompendiumItemGroupEditView:\(group.id)" }
    var navigationTitle: String {
        if mode.isEdit {
            return ""
        } else {
            return "Add party"
        }
    }
}

extension CompendiumItemGroupEditState {
    static let nullInstance = CompendiumItemGroupEditState(mode: .create, group: CompendiumItemGroup.nullInstance, allCharacters: .initial)
}
