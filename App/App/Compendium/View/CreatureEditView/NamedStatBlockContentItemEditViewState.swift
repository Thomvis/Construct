//
//  NamedStatBlockContentItemEditViewState.swift
//  Construct
//
//  Created by Thomas Visser on 04/11/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import GameModels
import SwiftUI
import Helpers
import DiceRollerFeature
import Compendium
import MechMuse
import Persistence

struct NamedStatBlockContentItemEditFeature: Reducer {
    struct State: Equatable {
        let intent: Intent
        @BindingState var mode: Mode = .edit
        @BindingState var fields = Fields(name: "", description: "")

        @BindingState var preview: NamedStatBlockContentItem?

        init(editing item: NamedStatBlockContentItem) {
            self.intent = .edit(item)
            self.fields = Fields(name: item.name, description: item.description)

            if item.parsed != nil {
                self.preview = item
            }
        }

        init(newItemOfType type: NamedStatBlockContentItemType) {
            self.intent = .new(type)
        }

        var itemType: NamedStatBlockContentItemType {
            switch intent {
            case .new(let t): return t
            case .edit(let i): return i.type
            }
        }

        var validPreview: NamedStatBlockContentItem? {
            guard preview?.name == fields.name && preview?.description == fields.description else { return nil }
            return preview
        }

        func makeItem() -> NamedStatBlockContentItem {
            switch itemType {
            case .feature:
                return .feature(ParseableCreatureFeature(input: CreatureFeature(
                    id: UUID(),
                    name: fields.name,
                    description: fields.description
                )))
            case .action, .reaction, .legendaryAction:
                return .action(ParseableCreatureAction(input: CreatureAction(
                    id: UUID(),
                    name: fields.name,
                    description: fields.description
                )))
            }
        }

        enum Intent: Equatable {
            case new(NamedStatBlockContentItemType)
            case edit(NamedStatBlockContentItem)
        }

        enum Mode: Equatable {
            case edit
            case preview
        }

        struct Fields: Equatable {
            var name: String
            var description: String
        }

        static let nullInstance = State(newItemOfType: .feature)
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onDoneButtonTap
        case onRemoveButtonTap
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
            .onChange(of: \.mode) { oldValue, newValue in
                Reduce { state, action in
                    if state.mode == .preview, state.preview?.name != state.fields.name || state.preview?.description != state.fields.description {
                        var preview = state.makeItem()
                        preview.parseIfNeeded()
                        return .send(.binding(.set(\.$preview, preview)), animation: .easeInOut)
                    }
                    return .none
                }
            }
    }
}
