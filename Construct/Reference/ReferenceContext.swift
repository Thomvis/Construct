//
//  ReferenceContext.swift
//  Construct
//
//  Created by Thomas Visser on 22/01/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

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
}

extension CampaignBrowseViewState {
    var referenceContext: EncounterReferenceContext? {
        if let state = presentedNextCatalogBrowse {
            return state.referenceContext
        } else if let state = presentedNextEncounter {
            return state.referenceContext
        } else if let state = presentedDetailEncounter {
            return state.referenceContext
        }
        return nil
    }

    var toReferenceContextAction: ((EncounterReferenceContextAction) -> CampaignBrowseViewAction)? {
        if let state = presentedNextCatalogBrowse {
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

    var toReferenceContextAction: ((EncounterReferenceContextAction) -> EncounterDetailViewState.Action) {
        return { action in
            switch action {
            case .addCombatant(let a):
                return .addCombatantAction(a, false)
            }
        }
    }
}
