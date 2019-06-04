//
//  CombatantTagEditViewState.swift
//  Construct
//
//  Created by Thomas Visser on 22/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

struct CombatantTagEditViewState: Equatable, NavigationStackItemState {

    var mode: Mode
    var tag: CombatantTag
    var effectContext: EffectContext?

    var popover: Popover?

    var navigationStackItemStateId: String {
        tag.id.uuidString
    }

    var navigationTitle: String {
        mode.isEdit
            ? "Edit \(tag.definition.name)"
            : "Add \(tag.definition.name)"
    }

    struct EffectDurationPopover: Equatable {
        let duration: EffectDuration?
        let context: EffectContext
    }

    enum Popover: Equatable {
        case effectDuration(EffectDurationPopover)
        case numberEntry(NumberEntryViewState)
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

    static let reducer: Reducer<CombatantTagEditViewState, CombatantTagEditViewAction, Environment> = Reducer { state, action, _ in
        switch action {
        case .onNoteTextDidChange(let text):
            state.tag.note = text.nonEmptyString
        case .onDurationDidChange(let duration):
            state.tag.duration = duration
        case .onDoneTap: break // should be handled by parent
        case .popover(let p):
            state.popover = p
        }
        return .none
    }
}

enum CombatantTagEditViewAction: Equatable {
    case onNoteTextDidChange(String)
    case onDurationDidChange(EffectDuration?)
    case onDoneTap

    case popover(CombatantTagEditViewState.Popover?)
}

extension CombatantTagEditViewState {
    static let nullInstance = CombatantTagEditViewState(mode: .create, tag: CombatantTag.nullInstance, effectContext: nil, popover: nil)
}
