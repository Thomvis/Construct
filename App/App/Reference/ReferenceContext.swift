//
//  ReferenceContext.swift
//  Construct
//
//  Created by Thomas Visser on 22/01/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels

struct ReferenceContext: Equatable {
    /// Non-nil if there is an EncounterDetailView open
    var encounterDetailView: EncounterReferenceContext?

    /// The compendium entries that are open in the reference view
    /// Upon forwarding the context to each reference item,
    /// the compendium entry of the reference item itself is filtered out.
    var openCompendiumEntries: [CompendiumEntry]

    static let empty = ReferenceContext(encounterDetailView: nil, openCompendiumEntries: [])
}

/// Context for ReferenceView
struct EncounterReferenceContext: Equatable {
    let building: Encounter
    let running: RunningEncounter?

    var encounter: Encounter {
        running?.current ?? building
    }
}

enum EncounterReferenceContextAction: Equatable {
    case addCombatant(AddCombatantView.Action)
    case combatantAction(Combatant.Id, CombatantAction)

    case didDismiss(TabbedDocumentViewContentItem.Id)
}

extension CampaignBrowseViewFeature.State {
    var referenceContext: EncounterReferenceContext? {
        guard let destination else { return nil }
        switch destination {
        case .campaignBrowse(let state):
            return state.referenceContext
        case .encounter(let state):
            return state.referenceContext
        }
    }

    var referenceItemRequests: [ReferenceViewItemRequest] {
        guard let destination else { return [] }
        switch destination {
        case .campaignBrowse(let state):
            return state.referenceItemRequests
        case .encounter(let state):
            return state.referenceItemRequests
        }
    }

    var toReferenceContextAction: ((EncounterReferenceContextAction) -> CampaignBrowseViewFeature.Action)? {
        guard let destination else { return nil }
        switch destination {
        case .campaignBrowse(let state):
            return { action in
                if let action = state.toReferenceContextAction?(action) {
                    return .destination(.presented(.campaignBrowse(action)))
                }
                fatalError()
            }
        case .encounter(let state):
            return { action in
                .destination(.presented(.encounterDetail(state.toReferenceContextAction(action))))
            }
        }
    }
}

extension EncounterDetailFeature.State {
    var referenceContext: EncounterReferenceContext? {
        EncounterReferenceContext(building: building, running: running)
    }

    var referenceItemRequests: [ReferenceViewItemRequest] {
        [combatantDetailReferenceItemRequest, addCombatantReferenceItemRequest].compactMap { $0 }
    }

    var toReferenceContextAction: ((EncounterReferenceContextAction) -> EncounterDetailFeature.Action) {
        return { action in
            switch action {
            case .addCombatant(let a):
                return .addCombatantAction(a, false)
            case .combatantAction(let id, let a):
                return .encounter(.combatant(id, a))
            case .didDismiss(let id):
                return .didDismissReferenceItem(id)
            }
        }
    }
}

extension ReferenceViewFeature.State {
    var referenceItemRequests: [ReferenceViewItemRequest] {
        items.flatMap { $0.state.referenceItemRequests }
    }
}

extension ReferenceItem.State {
    // TODO: ensure all content types have their requests properly handled
    var referenceItemRequests: [ReferenceViewItemRequest] {
        switch content {
        case .compendium(let s):
            return s.compendium.referenceItemRequests
        case .combatantDetail(let s):
            return s.detailState.itemRequest.nonNilArray
        case .addCombatant: return []
        case .compendiumItem(let s):
            return s.itemRequest.nonNilArray
        case .safari: return []
        }
    }
}

extension CompendiumIndexFeature.State {
    var referenceItemRequests: [ReferenceViewItemRequest] {
        switch destination {
        case .itemDetail(let detail):
            return detail.itemRequest.nonNilArray
        case .compendiumIndex(let state):
            return state.referenceItemRequests
        case nil:
            return []
        }
    }
}
