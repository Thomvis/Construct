//
//  CreatureEditViewState.swift
//  Construct
//
//  Created by Thomas Visser on 22/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels
import Helpers
import DiceRollerFeature
import Compendium
import MechMuse
import Persistence
import SharedViews

struct CreatureEditFeature: Reducer {
    struct State: Equatable {
        var mode: Mode
        var model: CreatureEditFormModel
        var sections: Set<Section>

        var popover: Popover?
        var sheet: Sheet? = nil
        var notice: Notice? = nil

        // Used to preserve attribution when creating new items (e.g. "Edit a copy")
        var createOrigin: CompendiumEntry.Origin? = .created(nil)
        // Used to preserve attribution when editing existing items
        var originalOrigin: CompendiumEntry.Origin? = nil

        init(create creatureType: CreatureType, sourceDocument: CompendiumFilters.Source = .init(.homebrew)) {
            self.mode = .create(creatureType)
            self.model = CreatureEditFormModel(
                statBlock: StatBlockFormModel(statBlock: .default),
                document: CompendiumDocumentSelectionFeature.State(
                    selectedSource: sourceDocument
                )
            )
            self.sections = creatureType.initialSections
            self.popover = nil

            if case .adHocCombatant = creatureType {
                self.model.statBlock.initiative = Initiative(modifier: Modifier(modifier: 0), advantage: false)
            } else if case .character = creatureType {
                self.model.player = Player(name: nil)
            }
        }

        init(edit monster: Monster, documentId: CompendiumSourceDocument.Id, origin: CompendiumEntry.Origin = .created(nil)) {
            self.mode = .editMonster(monster)
            self.model = CreatureEditFormModel(monster: monster, documentId: documentId)
            self.sections = CreatureType.monster.initialSections.union(self.model.sectionsWithData)
            self.popover = nil
            self.originalOrigin = origin
        }

        init(edit character: Character, documentId: CompendiumSourceDocument.Id, origin: CompendiumEntry.Origin = .created(nil)) {
            self.mode = .editCharacter(character)
            self.model = CreatureEditFormModel(character: character, documentId: documentId)
            self.sections = CreatureType.character.initialSections.union(self.model.sectionsWithData)
            self.popover = nil
            self.originalOrigin = origin
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

        var maximumAbilityScore: Int {
            creatureType == .character ? 20 : 30
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

        var numberEntryPopover: NumberEntryFeature.State? {
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

        var actionEditor: NamedStatBlockContentItemEditViewState? {
            get {
                if case .actionEditor(let s) = sheet {
                    return s
                }
                return nil
            }
            set {
                if let newValue = newValue {
                    sheet = .actionEditor(newValue)
                }
            }
        }

        var creatureGenerationSheet: MechMuseCreatureGenerationFeature.State? {
            get {
                if case .creatureGeneration(let s) = sheet {
                    return s
                }
                return nil
            }
            set {
                if let newValue = newValue {
                    sheet = .creatureGeneration(newValue)
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
            res.sheet = sheet.map {
                switch $0 {
                case .actionEditor: return .actionEditor(.nullInstance)
                case .creatureGeneration: return .creatureGeneration(.nullInstance)
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

        enum CreatureType: Int, CaseIterable {
            case monster
            case character
            case adHocCombatant

            var localizedDisplayName: String {
                switch self {
                case .monster: return CompendiumItemType.monster.localizedDisplayName
                case .character: return CompendiumItemType.character.localizedDisplayName
                case .adHocCombatant: return "combatant"
                }
            }
        }

        enum Section: CaseIterable, Hashable, Identifiable {
            case basicMonster
            case basicCharacter
            case basicStats
            case abilities
            case skillsAndSaves
            case initiative
            case namedContentItems(NamedStatBlockContentItemType)
            case player

            static var allCases: [CreatureEditFeature.State.Section] =
                [.basicMonster, .basicCharacter, .basicStats, .abilities, .skillsAndSaves, .initiative]
                + allNamedContentItemCases
                + [.player]

            static var allNamedContentItemCases: [CreatureEditFeature.State.Section] =
                NamedStatBlockContentItemType.allCases.map { .namedContentItems($0) }

            var id: String {
                switch self {
                case .basicMonster: return "bm"
                case .basicCharacter: return "bc"
                case .basicStats: return "bs"
                case .abilities: return "abs"
                case .skillsAndSaves: return "ss"
                case .initiative: return "init"
                case .namedContentItems(let t): return "nci_\(t.rawValue)"
                case .player: return "pl"
                }
            }
        }

        enum Popover: Equatable {
            case numberEntry(NumberEntryFeature.State)
        }

        enum Sheet: Equatable, Identifiable {
            case actionEditor(NamedStatBlockContentItemEditViewState)
            case creatureGeneration(MechMuseCreatureGenerationFeature.State)

            var id: String {
                switch self {
                case .actionEditor: return "actionEditor"
                case .creatureGeneration: return "creatureGenerator"
                }
            }
        }
    }
    
    enum Action: Equatable {
        case setCreateModeCreatureType(State.CreatureType)
        case model(CreatureEditFormModel)
        case popover(State.Popover?)
        case numberEntryPopover(NumberEntryFeature.Action)
        case sheet(State.Sheet?)
        case creatureActionEditSheet(CreatureActionEditViewAction)
        case creatureGenerationSheet(MechMuseCreatureGenerationFeature.Action)
        case documentSelection(CompendiumDocumentSelectionFeature.Action)
        case onNamedContentItemTap(NamedStatBlockContentItemType, UUID)
        case onNamedContentItemRemove(NamedStatBlockContentItemType, IndexSet)
        case onNamedContentItemMove(NamedStatBlockContentItemType, IndexSet, Int)
        case addSection(State.Section)
        case removeSection(State.Section)
        case onCreatureGenerationButtonTap
        case onAddTap(State)
        case onDoneTap(State)
        case onRemoveTap(State)
        case didAdd(CreatureEditResult)
        case didEdit(CreatureEditResult)
        case dismissNotice
    }
    
    @Dependency(\.modifierFormatter) var modifierFormatter
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.diceLog) var diceLog
    @Dependency(\.compendiumMetadata) var compendiumMetadata
    @Dependency(\.mechMuse) var mechMuse
    @Dependency(\.compendium) var compendium
    @Dependency(\.database) var database

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .setCreateModeCreatureType(let type):
                if case .create = state.mode {
                    state.mode = .create(type)
                    state.sections = type.initialSections.union(state.model.sectionsWithData)
                }
            case .model(let m): state.model = m
            case .popover(let p): state.popover = p
            case .numberEntryPopover: break // handled below
            case .sheet(let s): state.sheet = s
            case .creatureActionEditSheet(.onDoneButtonTap):
                guard case let .actionEditor(editorState) = state.sheet else { break }
                switch editorState.intent {
                case .new:
                    var item = editorState.makeItem()
                    item.parseIfNeeded()
                    state.model.statBlock[itemsOfType: editorState.itemType].append(item)
                case .edit(let i):
                    state.model.statBlock[itemsOfType: editorState.itemType][id: i.id]?.name = editorState.fields.name
                    state.model.statBlock[itemsOfType: editorState.itemType][id: i.id]?.description = editorState.fields.description
                    state.model.statBlock[itemsOfType: editorState.itemType][id: i.id]?.parseIfNeeded()
                }

                state.sheet = nil
                state.sections.insert(.namedContentItems(editorState.itemType))
            case .creatureActionEditSheet(.onRemoveButtonTap):
                guard case let .actionEditor(editorState) = state.sheet, case let .edit(i) = editorState.intent else { break }
                state.model.statBlock[itemsOfType: editorState.itemType].remove(id: i.id)
                state.sheet = nil
            case .documentSelection: break // handled below
            case .onNamedContentItemTap(let t, let id):
                if let item = state.model.statBlock[itemsOfType: t][id: id] {
                    state.sheet = .actionEditor(NamedStatBlockContentItemEditViewState(editing: item))
                }
            case .onNamedContentItemRemove(let t, let indices):
                state.model.statBlock[itemsOfType: t].remove(atOffsets: indices)
            case .onNamedContentItemMove(let t, let indices, let offset):
                state.model.statBlock[itemsOfType: t].move(fromOffsets: indices, toOffset: offset)
            case .onCreatureGenerationButtonTap:
                state.sheet = .creatureGeneration(.init(base: state.model.statBlock.statBlock))
            case .creatureGenerationSheet(.onGenerationResultAccepted(let result)):
                state.model.statBlock.statBlock = result
                state.sheet = nil
            case .creatureActionEditSheet: break // handled below
            case .creatureGenerationSheet: break // handled below
            case .addSection(let s): state.sections.insert(s)
            case .removeSection(let s): state.sections.remove(s)
            case .onAddTap:
                // Create flows
                switch state.creatureType {
                case .adHocCombatant:
                    if let def = state.adHocCombatant {
                        return .send(.didAdd(.adHoc(def)))
                    }
                    return .none
                case .monster, .character:
                    guard let item = state.compendiumItem else { return .none }

                    // Check for key collision in compendium
                    let key = item.key
                    let exists = (try? compendium.contains(key)) ?? false
                    if exists {
                        state.notice = .error("An item named \"\(item.title)\" already exists in \"\(state.document.displayName)\". Please choose another name.")
                        return .none
                    }

                    let entry = CompendiumEntry(item, origin: state.createOrigin ?? .created(nil), document: .init(state.document))
                    _ = try? compendium.put(entry)
                    return .send(.didAdd(.compendium(entry)))
                }

            case .onDoneTap:
                // Edit flows
                switch state.mode {
                case .editAdHocCombatant:
                    if let def = state.adHocCombatant {
                        return .send(.didEdit(.adHoc(def)))
                    }
                    return .none
                case .editMonster, .editCharacter:
                    guard let item = state.compendiumItem else { return .none }

                    // If key changed and collides with another item, block and show notice
                    if let orig = state.originalItem, orig.key != item.key {
                        let collision = (try? compendium.contains(item.key)) ?? false
                        if collision {
                            state.notice = .error("An item named \"\(item.title)\" already exists in \"\(state.document.displayName)\". Please choose another name.")
                            return .none
                        }
                    }

                    // Remove old key if it changed
                    if let orig = state.originalItem, orig.key != item.key {
                        _ = try? database.keyValueStore.remove(orig.key)
                    }

                    let entry = CompendiumEntry(item, origin: state.originalOrigin ?? .created(nil), document: .init(state.document))
                    _ = try? compendium.put(entry)
                    return .send(.didEdit(.compendium(entry)))

                case .create:
                    return .none
                }
            case .onRemoveTap: break // should be handled by parent
            case .didAdd: break // bubbled up
            case .didEdit: break // bubbled up
            case .dismissNotice:
                state.notice = nil
            }
            return .none
        }
        .ifLet(\.numberEntryPopover, action: /Action.numberEntryPopover) {
            NumberEntryFeature(environment: NumberEntryEnvironment(
                modifierFormatter: modifierFormatter,
                mainQueue: mainQueue,
                diceLog: diceLog
            ))
        }
        .ifLet(\.actionEditor, action: /Action.creatureActionEditSheet) {
            CreatureActionEditFeature()
        }
        .ifLet(\.creatureGenerationSheet, action: /Action.creatureGenerationSheet) {
            MechMuseCreatureGenerationFeature()
        }
        Scope(state: \.model.document, action: /Action.documentSelection) {
            CompendiumDocumentSelectionFeature()
        }
    }
}

struct CreatureEditFormModel: Equatable {
    var statBlock: StatBlockFormModel

    var player: Player?
    var originalItemForAdHocCombatant: CompendiumItemReference?
    var document: CompendiumDocumentSelectionFeature.State

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
            if let level = statBlock.level {
                return level
            }
            return 0
        }
        set {
            if newValue == 0 {
                self.statBlock.level = nil
            } else {
                self.statBlock.statBlock.level = newValue
            }
        }
    }

    var levelOrNilAsZeroString: String {
        if let level = statBlock.level {
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

    var size: CreatureSize? {
        get { statBlock.size }
        set { statBlock.size = newValue }
    }

    var type: MonsterType? {
        get { statBlock.type?.result?.value }
        set { statBlock.type = newValue.map(ParseableMonsterType.init(from:)) }
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
        if let val = numberFormatter.number(from: speed)?.intValue {
            if statBlock.movement == nil {
                statBlock.movement = [mode: val]
            } else {
                statBlock.movement?[mode] = val
            }
        } else {
            statBlock.movement?[mode] = nil
            if statBlock.movement?.isEmpty == true {
                statBlock.movement = nil
            }
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

    subscript(itemsOfType type: NamedStatBlockContentItemType) -> IdentifiedArrayOf<NamedStatBlockContentItem> {
        get { statBlock[itemsOfType: type] }
        set { statBlock[itemsOfType: type] = newValue }
    }

    var skillProficiencies: [Proficiency<Skill>] {
        Skill.allCases.compactMap { s in
            statBlock.skills[s].map { (s, $0) }
        }.map { s, p in
            Proficiency(
                stat: s,
                modifier: statBlock.skillModifier(s),
                proficiency: p
            )
        }
    }

    /// Passing nil as the modifier makes it use the proficiency bonus
    mutating func setProficiency(_ proficiency: StatBlock.Proficiency, for skill: Skill) {
        statBlock.skills[skill] = proficiency
    }

    mutating func removeProficiency(for skill: Skill) {
        statBlock.skills.removeValue(forKey: skill)
    }

    mutating func removeAllSkillProficiencies() {
        statBlock.skills.removeAll()
    }

    var savingThrowProficiencies: [Proficiency<Ability>] {
        Ability.allCases.compactMap { s in
            statBlock.savingThrows[s].map { (s, $0) }
        }.map { s, p in
            Proficiency(
                stat: s,
                modifier: statBlock.savingThrowModifier(s),
                proficiency: p
            )
        }
    }

    /// Passing nil as the modifier makes it use the proficiency bonus
    mutating func setProficiency(_ proficiency: StatBlock.Proficiency, for save: Ability) {
        statBlock.savingThrows[save] = proficiency
    }

    mutating func removeProficiency(for save: Ability) {
        statBlock.savingThrows.removeValue(forKey: save)
    }

    mutating func removeAllSavingThrowProficiencies() {
        statBlock.savingThrows.removeAll()
    }

    var difficultyDescription: String {
        if let cr = statBlock.challengeRating {
            return "CR \(cr.rawValue)"
        } else if let level = statBlock.level {
            return "level \(level)"
        }
        return "unknown"
    }

    var proficiencyBonusModifier: String {
        modifierFormatter.stringWithFallback(for: statBlock.proficiencyBonus.modifier)
    }

    var level: Int? {
        get { statBlock.level }
        set { statBlock.level = newValue }
    }

    var challengeRating: Fraction? {
        get { statBlock.challengeRating }
        set { statBlock.challengeRating = newValue }
    }

    // todo: rename
    struct Proficiency<Stat: Hashable> {
        let stat: Stat
        let modifier: Modifier
        let proficiency: StatBlock.Proficiency
    }
}

private struct NumberEntryEnvironment: NumberEntryViewEnvironment {
    let modifierFormatter: NumberFormatter
    let mainQueue: AnySchedulerOf<DispatchQueue>
    let diceLog: DiceLogPublisher

    init(modifierFormatter: NumberFormatter, mainQueue: AnySchedulerOf<DispatchQueue>, diceLog: DiceLogPublisher) {
        self.modifierFormatter = modifierFormatter
        self.mainQueue = mainQueue
        self.diceLog = diceLog
    }
}


extension CreatureEditFeature.State: NavigationStackItemState {
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

extension AbilityScores {
    static var `default`: AbilityScores {
        AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10)
    }
}

extension CreatureEditFeature.State.CreatureType {
    var requiredSections: Set<CreatureEditFeature.State.Section> {
        switch self {
        case .monster: return [.basicMonster]
        case .character: return [.basicCharacter, .player]
        case .adHocCombatant: return [.basicCharacter, .player]
        }
    }

    var initialSections: Set<CreatureEditFeature.State.Section> {
        switch self {
        case .monster, .character: return requiredSections
        case .adHocCombatant: return [.basicCharacter, .basicStats, .initiative, .player]
        }
    }

    var compatibleSections: Set<CreatureEditFeature.State.Section> {
        switch self {
        case .monster: return Set(
            [.basicMonster, .basicStats, .abilities, .skillsAndSaves, .initiative]
            + CreatureEditFeature.State.Section.allNamedContentItemCases
        )
        case .character: return Set(
            [.basicCharacter, .basicStats, .abilities, .skillsAndSaves, .initiative]
            + CreatureEditFeature.State.Section.allNamedContentItemCases
            + [.player]
        )
        case .adHocCombatant: return Set(
            [.basicCharacter, .basicStats, .abilities, .skillsAndSaves, .initiative]
            + CreatureEditFeature.State.Section.allNamedContentItemCases
            + [.player]
        )
        }
    }
}

extension CreatureEditFeature.State.Section {
    var localizedHeader: String? {
        switch self {
        case .basicMonster: return nil
        case .basicCharacter: return nil
        case .basicStats: return localizedName
        case .abilities: return localizedName
        case .skillsAndSaves: return localizedName
        case .initiative: return localizedName
        case .namedContentItems: return localizedName
        case .player: return nil
        }
    }

    var localizedName: String {
        switch self {
        case .basicMonster: return ""
        case .basicCharacter: return ""
        case .basicStats: return "AC / HP / Movement"
        case .abilities: return "Ability Scores"
        case .skillsAndSaves: return "Skills / Saves"
        case .initiative: return "Initiative"
        case .namedContentItems(.feature): return "Features & Traits"
        case .namedContentItems(.action): return "Actions"
        case .namedContentItems(.reaction): return "Reactions"
        case .namedContentItems(.legendaryAction): return "Legendary Actions"
        case .player: return ""
        }
    }
}

extension CreatureEditFeature.State {
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
            if let cr = model.statBlock.challengeRating {
                m.challengeRating = cr
            }
            return m
        case .editCharacter(var c):
            c.stats = statBlock
            c.level = model.statBlock.level
            c.player = model.player
            return c
        case .editAdHocCombatant(var c):
            c.stats = statBlock
            c.level = model.statBlock.level
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
        guard let cr = model.statBlock.challengeRating else { return nil }
        let realm: CompendiumItemKey.Realm
        if let selectedSource = model.document.selectedSource {
            realm = .init(selectedSource.realm)
        } else {
            realm = mode.originalItem?.realm ?? .init(CompendiumRealm.homebrew.id)
        }
        return Monster(realm: realm, stats: statBlock, challengeRating: cr)
    }

    var character: Character? {
        let player = sections.contains(.player) ? model.player : nil
        let realm: CompendiumItemKey.Realm
        if let selectedSource = model.document.selectedSource {
            realm = .init(selectedSource.realm)
        } else {
            realm = mode.originalItem?.realm ?? .init(CompendiumRealm.homebrew.id)
        }
        return Character(id: mode.originalCharacter?.id ?? UUID().tagged(), realm: realm, level: model.statBlock.level, stats: statBlock, player: player)
    }

    var adHocCombatant: AdHocCombatantDefinition? {
        return AdHocCombatantDefinition(id: UUID().tagged(), stats: statBlock, player: model.player, level: model.statBlock.level, original: model.originalItemForAdHocCombatant)
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
        if !sections.contains(.skillsAndSaves) {
            result.skills = [:]
            result.savingThrows = [:]
        }
        for case .namedContentItems(let type) in Section.allNamedContentItemCases {
            if !sections.contains(.namedContentItems(type)) {
                result[itemsOfType: type] = []
            }
        }

        return result
    }

    var document: CompendiumSourceDocument {
        if let doc = model.document.currentDocument {
            return doc
        }

        return .homebrew
    }
}

extension CompendiumItemType {
    var creatureType: CreatureEditFeature.State.CreatureType? {
        switch self {
        case .monster: return .monster
        case .character: return .character
        case .spell: return nil
        case .group: return nil
        }
    }
}

extension CreatureEditFormModel {
    init(monster: Monster, documentId: CompendiumSourceDocument.Id = CompendiumSourceDocument.homebrew.id) {
        self.statBlock = StatBlockFormModel(statBlock: monster.stats)
        self.document = CompendiumDocumentSelectionFeature.State(
            selectedSource: CompendiumFilters.Source(realm: monster.realm.value, document: documentId)
        )
    }

    init(character: Character, documentId: CompendiumSourceDocument.Id = CompendiumSourceDocument.homebrew.id) {
        self.statBlock = StatBlockFormModel(statBlock: character.stats)
        self.player = character.player
        self.document = CompendiumDocumentSelectionFeature.State(
            selectedSource: CompendiumFilters.Source(realm: character.realm.value, document: documentId)
        )
    }

    init(combatant: AdHocCombatantDefinition) {
        self.statBlock = StatBlockFormModel(statBlock: combatant.stats)
        self.player = combatant.player
        self.originalItemForAdHocCombatant = combatant.original
        self.document = CompendiumDocumentSelectionFeature.State(
            selectedSource: CompendiumFilters.Source(.homebrew)
        )
    }

    var sectionsWithData: Set<CreatureEditFeature.State.Section> {
        var result = Set<CreatureEditFeature.State.Section>()

        if statBlock.statBlock.armorClass != nil || statBlock.statBlock.hitPoints != nil || statBlock.statBlock.movement != nil {
            result.insert(.basicStats)
        }

        if statBlock.statBlock.abilityScores != nil {
            result.insert(.abilities)
        }

        if !statBlock.statBlock.skills.isEmpty || !statBlock.statBlock.savingThrows.isEmpty {
            result.insert(.skillsAndSaves)
        }

        if statBlock.statBlock.initiative != nil {
            result.insert(.initiative)
        }

        for type in NamedStatBlockContentItemType.allCases {
            if !statBlock.statBlock[itemsOfType: type].isEmpty {
                result.insert(.namedContentItems(type))
            }
        }

        return result
    }
}

extension CreatureEditFeature.State {
    static let nullInstance = CreatureEditFeature.State(create: .monster)
}

enum CreatureEditResult: Equatable {
    case compendium(CompendiumEntry)
    case adHoc(AdHocCombatantDefinition)
}
