//
//  Models.swift
//  Construct
//
//  Created by Thomas Visser on 06/06/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Combine
import Tagged
import Dice

public struct Encounter: Equatable, Codable {
    public let id: Id
    public var name: String
    public var combatants: IdentifiedArrayOf<Combatant> {
        didSet {
            updateCombatantDiscriminators()
        }
    }
    public var partyForDifficulty: Party?

    // The id of the running encounter
    public var runningEncounterKey: String?

    public var ensureStableDiscriminators: Bool

    public init(id: UUID = UUID(), name: String, combatants: [Combatant]) {
        self.id = id.tagged()
        self.name = name
        self.combatants = IdentifiedArray(uniqueElements: combatants, id: \.id)
        self.ensureStableDiscriminators = false
        updateCombatantDiscriminators()
    }

    public func filteredCombatants(withInitiative: Bool = false) -> [Combatant] {
        if withInitiative {
            return initiativeOrder
        }
        return self.combatants.filter { $0.initiative == nil }
    }

    public var allOrNoCombatantsHaveInitiative: Bool {
        guard let first = combatants.first else { return true }
        return combatants.dropFirst().first { (first.initiative == nil) != ($0.initiative == nil) } == nil
    }

    public var allCombatantsHaveInitiative: Bool {
        return combatants.first { $0.initiative == nil } == nil
    }

    public var combatantsInDisplayOrder: [Combatant] {
        combatants
            .sorted { a, b in
                guard let ia = a.initiative, let ib = b.initiative else { return false }
                if ia > ib {
                    return true
                } else if ia < ib {
                    return false
                } else {
                    let dsa = a.definition.stats.abilityScores?.dexterity.score ?? 10
                    let dsb = b.definition.stats.abilityScores?.dexterity.score ?? 10
                    if dsa > dsb {
                        return true
                    } else if dsa < dsb {
                        return false
                    } else if let idxa = combatants.firstIndex(where: { $0.id == a.id }),
                        let idxb = combatants.firstIndex(where: { $0.id == b.id}) {
                        // tie-breaker 1
                        return idxa < idxb
                    } else {
                        return a.id.rawValue.uuidString < b.id.rawValue.uuidString // tie-breaker 2
                    }
                }
            }
    }

    public var initiativeOrder: [Combatant] {
        combatantsInDisplayOrder.filter { $0.initiative != nil }
    }

    public func initiative(forGroupingHint hint: String) -> Int? {
        combatants.first { $0.definition.initiativeGroupingHint == hint && $0.initiative != nil }?.initiative
    }

    public var playerControlledCombatants: [Combatant] {
        combatants.filter { $0.definition.player != nil }
    }

    /// Returns nil if the party doesn't yield any entries
    private func encounterDifficultyPartyEntries(for party: Party) -> [EncounterDifficulty.PartyEntry]? {
        if party.combatantBased {
            let partyCombatants: [Combatant] = (party.combatantParty?.filter?.compactMap { id in
                combatants.first { $0.id == id }
            } ?? playerControlledCombatants)
            let entries: [EncounterDifficulty.PartyEntry] = partyCombatants.compactMap { c in c.definition.level.map { .init(level: $0, name: c.name) } }
            return entries.nonEmptyArray
        } else if let simple = party.simplePartyEntries, !simple.isEmpty {
            return simple.flatMap { Array(repeating: .init(level: $0.level, name: nil), count: $0.count) }
        }

        return nil
    }

    public var partyWithEntriesForDifficulty: (Party, [EncounterDifficulty.PartyEntry]) {
        // return entries for configured party, if available
        if let party = partyForDifficulty, let entries = encounterDifficultyPartyEntries(for: party) {
            return (party, entries)
        }

        // falling back to entries for combatants in the encounter
        let defaultCombatantParty = Party.combatant(Party.CombatantParty(filter: nil))
        if let entries = encounterDifficultyPartyEntries(for: defaultCombatantParty) {
            return (defaultCombatantParty, entries)
        }

        // falling back to the default party composition
        let defaultSimpleParty = Party.defaultSimple()
        if let entries = encounterDifficultyPartyEntries(for: defaultSimpleParty) {
            return (defaultSimpleParty, entries)
        }

        assertionFailure("Party.defaultSimple() should always have entries")
        return (defaultSimpleParty, [])
    }

    public func combatant(for id: Combatant.Id) -> Combatant? {
        return combatants.first { $0.id == id }
    }

    public func combatants(with definitionID: String) -> [Combatant] {
        return combatants.filter { $0.definition.definitionID == definitionID }
    }

    public mutating func rollInitiative<G>(settings: InitiativeSettings, rng: inout G) where G: RandomNumberGenerator{
        // will be nil if grouping is disabled
        var groupCache: [AnyHashable: Int]?

        if settings.group {
            // build up cache if we're not overwriting
            groupCache = settings.overwrite ? [:] : combatants.reduce(into: Dictionary<AnyHashable, Int>()) { acc, combatant in
                if let initiative = combatant.initiative {
                    acc[combatant.definition.initiativeGroupingHint] = initiative
                }
            }
        }

        for combatant in combatants {
            if combatant.definition.player != nil && !settings.rollForPlayerCharacters { continue }
            if combatant.initiative != nil && !settings.overwrite { continue }

            if let initiative = groupCache?[combatant.definition.initiativeGroupingHint] {
                combatants[id: combatant.id]?.initiative = initiative
            } else if let modifier = combatant.definition.initiativeModifier {
                // TODO: extract expression to "Rules"
                let initiative = (1.d(20) + modifier).roll(rng: &rng).total
                combatants[id: combatant.id]?.initiative = initiative
                groupCache?[combatant.definition.initiativeGroupingHint] = initiative
            }
        }
    }

    var _isUpdatingCombatantDiscriminators = false
    mutating private func updateCombatantDiscriminators() {
        guard !_isUpdatingCombatantDiscriminators else { return }
        _isUpdatingCombatantDiscriminators = true

        if ensureStableDiscriminators {
            for combatant in combatants {
                guard combatant.discriminator == nil else { continue }

                let set = combatants.filter { $0.definition.definitionID == combatant.definition.definitionID }
                guard set.count > 1 else { continue }

                let max = set.compactMap { $0.discriminator }.max() ?? 0
                combatants[id: combatant.id]?.discriminator = max + 1
            }
        } else {
            for combatant in combatants {
                let set = combatants.filter { $0.definition.definitionID == combatant.definition.definitionID }
                if set.count > 1 {
                    combatants[id: combatant.id]?.discriminator = set.firstIndex { $0.id == combatant.id }.map { $0 + 1 }
                } else {
                    combatants[id: combatant.id]?.discriminator = nil
                }
            }
        }

        _isUpdatingCombatantDiscriminators = false
    }

    public typealias Id = Tagged<Encounter, UUID>

    public struct Party: Codable, Equatable { // should be enum, but struct gives us auto-codable
        public var simplePartyEntries: [SimplePartyEntry]?
        public var combatantParty: CombatantParty?
        public var combatantBased: Bool

        public static func simple(_ entries: [SimplePartyEntry]?) -> Self {
            Party(simplePartyEntries: entries, combatantParty: nil, combatantBased: false)
        }

        public static func combatant(_ party: CombatantParty) -> Self {
            Party(simplePartyEntries: nil, combatantParty: party, combatantBased: true)
        }

        public static func defaultSimple() -> Self {
            simple([Encounter.Party.SimplePartyEntry(level: 2, count: 3)])
        }

        public struct CombatantParty: Codable, Equatable {
            var _filter: [Combatant.Id]? // if nil, all player controlled combatants are in the party
            public var filter: [Combatant.Id]? {
                get { _filter }
                set { _filter = newValue }
            }

            public init(filter: [Combatant.Id]?) {
                self.filter = filter
            }
        }

        public struct SimplePartyEntry: Codable, Identifiable, Equatable {
            public let id: Id
            public var level: Int
            public var count: Int

            public init(level: Int, count: Int) {
                self.id = UUID().tagged()
                self.level = level
                self.count = count
            }

            public typealias Id = Tagged<SimplePartyEntry, UUID>
        }
    }
}

public struct InitiativeSettings: Equatable {
    public var group: Bool
    public var rollForPlayerCharacters: Bool
    public var overwrite: Bool

    public init(group: Bool, rollForPlayerCharacters: Bool, overwrite: Bool) {
        self.group = group
        self.rollForPlayerCharacters = rollForPlayerCharacters
        self.overwrite = overwrite
    }

    public static let `default` = InitiativeSettings(group: true, rollForPlayerCharacters: false, overwrite: false)
}

public extension Encounter {
    static let scratchPadEncounterId: Encounter.Id = UUID(uuidString: "641EA02F-1B8A-4A0B-9AD7-7D7068A4C014")!.tagged()

    var isScratchPad: Bool {
        id == Self.scratchPadEncounterId
    }
}

extension Encounter {
    public static let nullInstance = Encounter(name: "", combatants: [])
}
