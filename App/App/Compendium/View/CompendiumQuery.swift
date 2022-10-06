//
//  CompendiumQuery.swift
//  Construct
//
//  Created by Thomas Visser on 02/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers
import GameModels

extension CompendiumIndexState {

    struct Query: Equatable {
        var text: String?
        var filters: Filters?
        var order: Order?

        struct Filters: Equatable {
            var types: [CompendiumItemType]?

            var minMonsterChallengeRating: Fraction? = nil
            var maxMonsterChallengeRating: Fraction? = nil

            enum Property: CaseIterable, Equatable {
                case itemType
                case minMonsterCR
                case maxMonsterCR
            }

            var test: ((CompendiumItem) -> Bool)? {
                guard minMonsterChallengeRating != nil || maxMonsterChallengeRating != nil else { return nil }

                return { item in
                    if let minCr = self.minMonsterChallengeRating {
                        if let monster = item as? Monster, let cr = monster.stats.challengeRating, cr >= minCr {
                            // continue
                        } else {
                            return false
                        }
                    }

                    if let maxCr = self.maxMonsterChallengeRating {
                        if let monster = item as? Monster, let cr = monster.stats.challengeRating, cr <= maxCr {
                            // continue
                        } else {
                            return false
                        }
                    }

                    return true
                }
            }
        }

        enum Order: Int, Equatable {
            case monsterChallengeRating
            case spellLevel
            case title

            var descriptor: Helpers.SortDescriptor<CompendiumItem> {
                switch self {
                case .monsterChallengeRating:
                    return SortDescriptor { lhs, rhs in
                        guard let lhsMonster = lhs as? Monster, let rhsMonster = rhs as? Monster else { return .orderedSame }
                        if lhsMonster.challengeRating.double < rhsMonster.challengeRating.double {
                            return .orderedAscending
                        } else if lhsMonster.challengeRating.double > rhsMonster.challengeRating.double {
                            return .orderedDescending
                        }
                        return .orderedSame
                    }.combined(with: Order.title.descriptor)
                case .spellLevel:
                    return SortDescriptor { lhs, rhs in
                        guard let lhsSpell = lhs as? Spell, let rhsSpell = rhs as? Spell else { return .orderedSame }
                        if (lhsSpell.level ?? 0) < (rhsSpell.level ?? 0) {
                            return .orderedAscending
                        } else if (lhsSpell.level ?? 0) > (rhsSpell.level ?? 0) {
                            return .orderedDescending
                        }
                        return .orderedSame
                    }.combined(with: Order.title.descriptor)
                case .title:
                    return SortDescriptor(\.title)
                }
            }
        }
    }
}
