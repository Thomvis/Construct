//
//  ReferenceContext.swift
//  Construct
//
//  Created by Thomas Visser on 22/01/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

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
}

extension CampaignBrowseViewState {
    var referenceContext: EncounterReferenceContext? {
        if let state = presentedNextCampaignBrowse {
            return state.referenceContext
        } else if let state = presentedNextEncounter {
            return state.referenceContext
        } else if let state = presentedDetailEncounter {
            return state.referenceContext
        }
        return nil
    }

    var referenceItemRequests: [ReferenceViewItemRequest] {
        if let state = presentedNextCampaignBrowse {
            return state.referenceItemRequests
        } else if let state = presentedNextEncounter {
            return state.referenceItemRequests
        } else if let state = presentedDetailEncounter {
            return state.referenceItemRequests
        }
        return []
    }

    var toReferenceContextAction: ((EncounterReferenceContextAction) -> CampaignBrowseViewAction)? {
        if let state = presentedNextCampaignBrowse {
            return { action in
                if let action = state.toReferenceContextAction?(action) {
                    return .nextScreen(.campaignBrowse(action))
                }
                fatalError()
            }
        } else if let state = presentedNextEncounter {
            return { action in
                .nextScreen(.encounterDetail(state.toReferenceContextAction(action)))
            }
        } else if let state = presentedDetailEncounter {
            return { action in
                .detailScreen(.encounterDetail(state.toReferenceContextAction(action)))
            }
        }

        return nil
    }
}

extension EncounterDetailViewState {
    var referenceContext: EncounterReferenceContext? {
        EncounterReferenceContext(building: building, running: running)
    }

    var referenceItemRequests: [ReferenceViewItemRequest] {
        [combatantDetailReferenceItemRequest, addCombatantReferenceItemRequest].compactMap { $0 }
    }

    var toReferenceContextAction: ((EncounterReferenceContextAction) -> EncounterDetailViewState.Action) {
        return { action in
            switch action {
            case .addCombatant(let a):
                return .addCombatantAction(a, false)
            case .combatantAction(let id, let a):
                return .encounter(.combatant(id, a))
            }
        }
    }
}
