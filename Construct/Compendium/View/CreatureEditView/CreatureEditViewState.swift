//
//  CreatureEditViewState.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 22/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct CreatureEditViewState: Equatable {
    var mode: Mode
    var model: CreatureEditFormModel
    var sections: Set<Section>

    var popover: Popover?

    init(create creatureType: CreatureType) {
        self.mode = .create(creatureType)
        self.model = CreatureEditFormModel(statBlock: StatBlockFormModel(statBlock: .default))
        self.sections = creatureType.initialSections
        self.popover = nil

        if case .adHocCombatant = creatureType {
            self.model.statBlock.initiative = Initiative(modifier: Modifier(modifier: 0), advantage: false)
        } else if case .character = creatureType {
            self.model.player = Player(name: nil)
        }
    }

    init(edit monster: Monster) {
        self.mode = .editMonster(monster)
        self.model = CreatureEditFormModel(monster: monster)
        self.sections = CreatureType.monster.initialSections.union(self.model.sectionsWithData)
        self.popover = nil
    }

    init(edit character: Character) {
        self.mode = .editCharacter(character)
        self.model = CreatureEditFormModel(character: character)
        self.sections = CreatureType.character.initialSections.union(self.model.sectionsWithData)
        self.popover = nil
    }

    init(edit combatant: AdHocCombatantDefinition) {
        self.mode = .editAdHocCombatant(combatant)
        self.model = CreatureEditFormModel(combatant: combatant)
        self.sections = CreatureType.character.initialSections.union(self.model.sectionsWithData)
        self.popover = nil
    }

    var creatureType: CreatureType {
        switch mode {
        case .create(let t): return t
        case .editMonster: return .monster
        case .editCharacter: return .character
        case .editAdHocCombatant: return .adHocCombatant
        }
    }

    var isValid: Bool {
        model.statBlock.name.nonEmptyString != nil && result != nil
    }

    var canEditName: Bool {
        if case .editMonster = mode {
            return false
        }
        return true
    }

    var addableSections: [Section] {
        Section.allCases.filter { creatureType.compatibleSections.contains($0) && !sections.contains($0) }
    }

    var numberEntryPopover: NumberEntryViewState? {
        get {
            if case .numberEntry(let s) = popover {
                return s
            }
            return nil
        }
        set {
            if let newValue = newValue {
                popover = .numberEntry(newValue)
            }
        }
    }

    var localStateForDeduplication: Self {
        var res = self
        res.popover = popover.map {
            switch $0 {
            case .numberEntry: return .numberEntry(.nullInstance)
            }
        }
        return res
    }

    enum Mode: Equatable {
        case create(CreatureType)
        case editMonster(Monster)
        case editCharacter(Character)
        case editAdHocCombatant(AdHocCombatantDefinition)

        var originalItem: CompendiumItem? {
            switch self {
            case .create: return nil
            case .editMonster(let m): return m
            case .editCharacter(let c): return c
            case .editAdHocCombatant: return nil
            }
        }

        var originalCharacter: Character? {
            originalItem as? Character
        }

        var isEdit: Bool {
            switch self {
            case .create: return false
            case .editMonster, .editCharacter, .editAdHocCombatant: return true
            }
        }
    }

    enum CreatureType: Int {
        case monster
        case character
        case adHocCombatant

        var localizedDisplayName: String {
            switch self {
            case .monster: return CompendiumItemType.monster.localizedDisplayName
            case .character: return CompendiumItemType.character.localizedDisplayName
            case .adHocCombatant: return "Combatant"
            }
        }
    }

    enum Section: Int, CaseIterable, Hashable {
        case basicMonster
        case basicCharacter
        case basicStats
        case abilities
        case initiative
        case player
    }

    enum Popover: Equatable {
        case numberEntry(NumberEntryViewState)
    }
}

struct CreatureEditFormModel: Equatable {
    var statBlock: StatBlockFormModel
    var level: Int?
    var player: Player?
    var challengeRating: Fraction?
    var originalItemForAdHocCombatant: CompendiumItemReference?

    var isPlayer: Bool {
        get {
            player != nil
        }
        set {
            switch (player, newValue) {
            case (nil, true): player = Player(name: nil)
            case (.some, false): player = nil
            default: break
            }
        }
    }

    var playerName: String {
        get { player?.name ?? "" }
        set {
            player?.name = newValue
        }
    }

    var levelOrNilAsZero: Int {
        get {
            if let level = level {
                return level
            }
            return 0
        }
        set {
            if newValue == 0 {
                self.level = nil
            } else {
                self.level = newValue
            }
        }
    }

    var levelOrNilAsZeroString: String {
        if let level = level {
            return "\(level)"
        }

        return "N/A"
    }
}

struct StatBlockFormModel: Equatable {
    fileprivate var statBlock: StatBlock

    var movementModes: [MovementMode]

    private let numberFormatter: NumberFormatter

    init(statBlock: StatBlock) {
        self.statBlock = statBlock

        self.numberFormatter = NumberFormatter()
        numberFormatter.isLenient = true
        numberFormatter.numberStyle = .none

        movementModes = MovementMode.allCases.filter { mode in
            statBlock.movement?[mode] != nil || mode == .walk
        }
    }

    init() {
        self.init(statBlock: .default)
    }

    var name: String {
        get { statBlock.name }
        set { statBlock.name = newValue }
    }

    var ac: String {
        get { numberFormatter.string(for: statBlock.armorClass) ?? "" }
        set { statBlock.armorClass = numberFormatter.number(from: newValue)?.intValue }
    }

    var hp: String {
        get { numberFormatter.string(for: statBlock.hitPoints) ?? "" }
        set { statBlock.hitPoints = numberFormatter.number(from: newValue)?.intValue }
    }

    var abilities: AbilityScores {
        get { statBlock.abilityScores ?? AbilityScores.default }
        set { statBlock.abilityScores = newValue }
    }

    var initiative: Initiative {
        get { statBlock.initiative
            ?? Initiative(modifier: statBlock.abilityScores?.dexterity.modifier ?? Modifier(modifier: 0), advantage: false)
        }
        set { statBlock.initiative = newValue }
    }

    func speed(for mode: MovementMode) -> String {
        statBlock.movement?[mode].flatMap(numberFormatter.string) ?? ""
    }

    mutating func setSpeed(_ speed: String, for mode: MovementMode) {
        guard let val = numberFormatter.number(from: speed)?.intValue else { return }
        if statBlock.movement == nil {
            statBlock.movement = [mode: val]
        } else {
            statBlock.movement?[mode] = val
        }
    }

    func canAddMovementMode() -> Bool {
        MovementMode.allCases.first(where: { !movementModes.contains($0) }) != nil
    }

    mutating func addMovementMode() {
        if let next = MovementMode.allCases.first(where: { !movementModes.contains($0) }) {
            movementModes.append(next)
        }
    }

    mutating func change(mode: MovementMode, to mode2: MovementMode) {
        guard let idx = movementModes.firstIndex(of: mode), mode != mode2 else { return }

        let mode2Idx = movementModes.firstIndex(of: mode2)

        // set current value to new mode
        let valueForMode = statBlock.movement?[mode]
        statBlock.movement?[mode2] = valueForMode
        statBlock.movement?.removeValue(forKey: mode)

        // update mode for row
        movementModes[idx] = mode2

        // remove old row for new mode (if present)
        if let idx = mode2Idx {
            movementModes.remove(at: idx)
        }
    }
}

enum CreatureEditViewAction: Equatable {
    case model(CreatureEditFormModel)
    case popover(CreatureEditViewState.Popover?)
    case numberEntryPopover(NumberEntryViewAction?)
    case addSection(CreatureEditViewState.Section)
    case removeSection(CreatureEditViewState.Section)
    case onAddTap(CreatureEditViewState)
    case onDoneTap(CreatureEditViewState)
    case onRemoveTap(CreatureEditViewState)
}

extension CreatureEditViewState {
    static let reducer: Reducer<Self, CreatureEditViewAction, Environment> = Reducer.combine(
        NumberEntryViewState.reducer.optional().pullback(state: \.numberEntryPopover, action: /CreatureEditViewAction.numberEntryPopover),
        Reducer { state, action, _ in
            switch action {
            case .model(let m): state.model = m
            case .popover(let p): state.popover = p
            case .numberEntryPopover: break // handled above
            case .addSection(let s): state.sections.insert(s)
            case .removeSection(let s): state.sections.remove(s)
            case .onAddTap: break // should be handled by parent
            case .onDoneTap: break // should be handled by parent
            case .onRemoveTap: break // should be handled by parent
            }
            return .none
        }
    )
}

extension CreatureEditViewState: NavigationStackItemState {
    var navigationStackItemStateId: String { "CreatureEditView" }
    var navigationTitle: String {
        switch mode {
        case .create(let type):
            switch type {
            case .monster: return "Add monster"
            case .character: return "Add character"
            case .adHocCombatant: return "Quick add"
            }
        case .editMonster(let m):
            return "Edit \(m.title)"
        case .editCharacter(let c):
            return "Edit \(c.title)"
        case .editAdHocCombatant(let c):
            return "Edit \(c.name)"
        }
    }
}

extension StatBlock {
    static var `default`: StatBlock {
        StatBlock(name: "", size: nil, type: nil, subtype: nil, alignment: nil, armorClass: nil, armor: [], hitPointDice: nil, hitPoints: nil, movement: nil, abilityScores: nil, savingThrows: [:], skills: [:], damageVulnerabilities: nil, damageResistances: nil, damageImmunities: nil, conditionImmunities: nil, senses: nil, languages: nil, challengeRating: nil, features: [], actions: [], reactions: [])
    }
}

extension AbilityScores {
    static var `default`: AbilityScores {
        AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10)
    }
}

extension CreatureEditViewState.CreatureType {
    var requiredSections: Set<CreatureEditViewState.Section> {
        switch self {
        case .monster: return [.basicMonster]
        case .character: return [.basicCharacter, .player]
        case .adHocCombatant: return [.basicCharacter, .player]
        }
    }

    var initialSections: Set<CreatureEditViewState.Section> {
        switch self {
        case .monster, .character: return requiredSections
        case .adHocCombatant: return [.basicCharacter, .basicStats, .initiative, .player]
        }
    }

    var compatibleSections: Set<CreatureEditViewState.Section> {
        switch self {
        case .monster: return [.basicMonster, .basicStats, .abilities, .initiative]
        case .character: return [.basicCharacter, .basicStats, .abilities, .initiative, .player]
        case .adHocCombatant: return [.basicCharacter, .basicStats, .abilities, .initiative, .player]
        }
    }
}

extension CreatureEditViewState.Section {
    var localizedHeader: String? {
        switch self {
        case .basicMonster: return nil
        case .basicCharacter: return nil
        case .basicStats: return localizedName
        case .abilities: return localizedName
        case .initiative: return localizedName
        case .player: return nil
        }
    }

    var localizedName: String {
        switch self {
        case .basicMonster: return ""
        case .basicCharacter: return ""
        case .basicStats: return "AC / HP / Speed"
        case .abilities: return "Abilities"
        case .initiative: return "Initiative"
        case .player: return ""
        }
    }
}

extension CreatureEditViewState {
    var result: Any? { // todo: do not use Any
        switch mode {
        case .create(let type):
            switch type {
            case .monster: return monster
            case .character: return character
            case .adHocCombatant: return adHocCombatant
            }
        case .editMonster(var m):
            m.stats = statBlock
            if let cr = model.challengeRating {
                m.challengeRating = cr
            }
            return m
        case .editCharacter(var c):
            c.stats = statBlock
            c.level = model.level
            c.player = model.player
            return c
        case .editAdHocCombatant(var c):
            c.stats = statBlock
            c.level = model.level
            c.player = model.player
            return c
        }
    }

    var compendiumItem: CompendiumItem? {
        result as? CompendiumItem
    }

    var originalItem: CompendiumItem? {
        mode.originalItem
    }

    var monster: Monster? {
        guard let cr = model.challengeRating else { return nil }
        return Monster(realm: mode.originalItem?.realm ?? .homebrew, stats: statBlock, challengeRating: cr)
    }

    var character: Character? {
        let player = sections.contains(.player) ? model.player : nil
        return Character(id: mode.originalCharacter?.id ?? UUID().tagged(), realm: mode.originalItem?.realm ?? .homebrew, level: model.level, stats: statBlock, player: player)
    }

    var adHocCombatant: AdHocCombatantDefinition? {
        return AdHocCombatantDefinition(id: UUID().tagged(), stats: statBlock, player: model.player, level: model.level, original: model.originalItemForAdHocCombatant)
    }

    var statBlock: StatBlock {
        var result = model.statBlock.statBlock

        // remove info from removed sections
        if !sections.contains(.abilities) { result.abilityScores = nil }
        if !sections.contains(.initiative) { result.initiative = nil }
        if !sections.contains(.basicStats) {
            result.hitPoints = nil
            result.hitPointDice = nil
            result.armorClass = nil
            result.movement = nil
        }

        return result
    }
}

extension CompendiumItemType {
    var creatureType: CreatureEditViewState.CreatureType? {
        switch self {
        case .monster: return .monster
        case .character: return .character
        case .spell: return nil
        case .group: return nil
        }
    }
}

extension CreatureEditFormModel {
    init(monster: Monster) {
        self.statBlock = StatBlockFormModel(statBlock: monster.stats)
        self.challengeRating = monster.challengeRating
    }

    init(character: Character) {
        self.statBlock = StatBlockFormModel(statBlock: character.stats)
        self.level = character.level
        self.player = character.player
    }

    init(combatant: AdHocCombatantDefinition) {
        self.statBlock = StatBlockFormModel(statBlock: combatant.stats ?? .default)
        self.level = combatant.level
        self.player = combatant.player
        self.originalItemForAdHocCombatant = combatant.original
    }

    var sectionsWithData: Set<CreatureEditViewState.Section> {
        var result = Set<CreatureEditViewState.Section>()

        if statBlock.statBlock.armorClass != nil || statBlock.statBlock.hitPoints != nil || statBlock.statBlock.movement != nil {
            result.insert(.basicStats)
        }

        if statBlock.statBlock.abilityScores != nil {
            result.insert(.abilities)
        }

        return result
    }
}

extension CreatureEditViewState {
    static let nullInstance = CreatureEditViewState(create: .monster)
}
