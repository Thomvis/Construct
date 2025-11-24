//
//  CombatantTagEditViewState.swift
//  Construct
//
//  Created by Thomas Visser on 22/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Helpers
import GameModels

struct CombatantTagEditFeature: Reducer {

    struct State: Equatable, NavigationStackItemState {
        var mode: Mode
        var tag: CombatantTag
        var effectContext: EffectContext?

        var popover: Popover?

        var navigationStackItemStateId: String {
            tag.id.rawValue.uuidString
        }

        var navigationTitle: String {
            mode.isEdit
                ? "Edit \(tag.definition.name)"
                : "Add \(tag.definition.name)"
        }

        var numberEntryPopover: NumberEntryFeature.State? {
            get {
                guard case .numberEntry(let s) = popover else { return nil }
                return s
            }
            set {
                if let newValue = newValue {
                    popover = .numberEntry(newValue)
                }
            }
        }

        struct EffectDurationPopover: Equatable {
            let duration: EffectDuration?
            let context: EffectContext
        }

        enum Popover: Equatable {
            case effectDuration(EffectDurationPopover)
            case numberEntry(NumberEntryFeature.State)
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

        static let nullInstance = State(mode: .create, tag: CombatantTag.nullInstance, effectContext: nil, popover: nil)
    }

    @CasePathable
    enum Action: Equatable {
        case onNoteTextDidChange(String)
        case onDurationDidChange(EffectDuration?)
        case onDoneTap

        case popover(State.Popover?)
        case numberEntryPopover(NumberEntryFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onNoteTextDidChange(let text):
                state.tag.note = text.nonEmptyString
            case .onDurationDidChange(let duration):
                state.tag.duration = duration
            case .onDoneTap: break // should be handled by parent
            case .popover(let p):
                state.popover = p
            case .numberEntryPopover: break // handled above
            }
            return .none
        }
        .ifLet(\.numberEntryPopover, action: \.numberEntryPopover) {
            NumberEntryFeature()
        }
    }
}

extension CombatantTagEditFeature.State: NavigationTreeNode {}
