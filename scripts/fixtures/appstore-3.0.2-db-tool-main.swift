import Foundation
import Compendium
import Dice
import GameModels
import Helpers
import Persistence
import Tagged

func uuid(_ value: String) -> UUID {
    guard let uuid = UUID(uuidString: value) else {
        fatalError("Invalid UUID: \(value)")
    }
    return uuid
}

func staleDefaultContentVersions() throws -> DefaultContentVersions {
    try JSONDecoder().decode(
        DefaultContentVersions.self,
        from: Data(#"{"monsters":"fixture-needs-import","spells":"fixture-needs-import"}"#.utf8)
    )
}

func hitPoints(current: Int, maximum: Int, temporary: Int = 0) -> Hp {
    var hp = Hp(fullHealth: maximum)
    hp.current = current
    hp.temporary = temporary
    return hp
}

let outputPath = CommandLine.arguments.dropFirst().first ?? "Sources/TestSupport/Resources/appstore-3.0.2-rich.sqlite"

if FileManager.default.fileExists(atPath: outputPath) {
    try FileManager.default.removeItem(atPath: outputPath)
}

let database = try await Database(path: outputPath, importDefaultContent: true)
let store = database.keyValueStore

try store.put(staleDefaultContentVersions())
try await database.prepareForUse()

let legacyHomebrewDocument = CompendiumSourceDocument(
    id: "upgrade-lab",
    displayName: "Upgrade Lab Homebrew",
    realmId: CompendiumRealm.homebrew.id
)
try store.put(CompendiumRealm.homebrew)
try store.put(CompendiumSourceDocument.homebrew)
try store.put(legacyHomebrewDocument)

let myrmidonStats = StatBlock(
    name: "Clockwork Myrmidon",
    size: .medium,
    type: "construct",
    subtype: "clockwork",
    alignment: .unaligned,
    armorClass: 16,
    hitPointDice: 6.d(8) + 12,
    hitPoints: 39,
    movement: [.walk: 30],
    abilityScores: AbilityScores(
        strength: 16,
        dexterity: 12,
        constitution: 15,
        intelligence: 8,
        wisdom: 11,
        charisma: 6
    ),
    savingThrows: [.constitution: 4],
    skills: [.perception: 2],
    damageResistances: "poison; bludgeoning from nonmagical attacks",
    conditionImmunities: "charmed, exhaustion, poisoned",
    senses: "darkvision 60 ft., passive Perception 12",
    languages: "understands Common but can't speak",
    challengeRating: Fraction(numenator: 2, denominator: 1),
    features: [
        CreatureFeature(
            id: uuid("10000000-0000-0000-0000-000000000001"),
            name: "Wound Spring",
            description: "At the start of its turn, the myrmidon regains 3 hit points if it has at least 1 hit point."
        )
    ],
    actions: [
        CreatureAction(
            id: uuid("10000000-0000-0000-0000-000000000002"),
            name: "Gearblade",
            description: "Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 8 (1d10 + 3) slashing damage."
        )
    ],
    reactions: [
        CreatureAction(
            id: uuid("10000000-0000-0000-0000-000000000003"),
            name: "Parry",
            description: "The myrmidon adds 2 to its AC against one melee attack that would hit it."
        )
    ]
)
let myrmidon = Monster(
    realm: .init(CompendiumRealm.homebrew.id),
    stats: myrmidonStats,
    challengeRating: Fraction(numenator: 2, denominator: 1)
)
let myrmidonReference = CompendiumItemReference(itemTitle: myrmidon.title, itemKey: myrmidon.key)
try store.put(CompendiumEntry(
    myrmidon,
    origin: .created(nil),
    document: .init(legacyHomebrewDocument)
))

let characterStats = StatBlock(
    name: "Mira Vale",
    size: .medium,
    type: "humanoid",
    subtype: "human",
    alignment: .neutralGood,
    armorClass: 14,
    hitPointDice: 5.d(8) + 5,
    hitPoints: 33,
    movement: [.walk: 30],
    abilityScores: AbilityScores(
        strength: 9,
        dexterity: 16,
        constitution: 12,
        intelligence: 14,
        wisdom: 11,
        charisma: 15
    ),
    skills: [.arcana: 5, .persuasion: 5],
    senses: "passive Perception 10",
    languages: "Common, Draconic",
    features: [
        CreatureFeature(
            id: uuid("10000000-0000-0000-0000-000000000004"),
            name: "Spellbook",
            description: "Mira keeps cramped field notes on every monster she survives."
        )
    ],
    actions: [
        CreatureAction(
            id: uuid("10000000-0000-0000-0000-000000000005"),
            name: "Dagger",
            description: "Melee or Ranged Weapon Attack: +5 to hit. Hit: 5 (1d4 + 3) piercing damage."
        )
    ]
)
let mira = Character(
    id: uuid("10000000-0000-0000-0000-000000000101").tagged(),
    realm: .init(CompendiumRealm.homebrew.id),
    level: 5,
    stats: characterStats,
    player: Player(name: "Tess")
)
let miraReference = CompendiumItemReference(itemTitle: mira.title, itemKey: mira.key)
try store.put(CompendiumEntry(
    mira,
    origin: .created(nil),
    document: .init(legacyHomebrewDocument)
))

let spell = Spell(
    realm: .init(CompendiumRealm.homebrew.id),
    name: "Searing Ledger",
    level: 2,
    castingTime: "1 action",
    range: "60 feet",
    components: [.verbal, .somatic, .material],
    ritual: false,
    duration: "Instantaneous",
    school: "Evocation",
    concentration: false,
    description: ParseableSpellDescription(input: "A blazing page strikes a creature for 3d6 fire damage."),
    higherLevelDescription: "When cast using a spell slot of 3rd level or higher, the damage increases by 1d6 for each slot level above 2nd.",
    classes: ["Wizard"],
    material: "a singed receipt"
)
try store.put(CompendiumEntry(
    spell,
    origin: .created(nil),
    document: .init(legacyHomebrewDocument)
))

let party = CompendiumItemGroup(
    id: uuid("10000000-0000-0000-0000-000000000201").tagged(),
    title: "The Ledger Keepers",
    members: [miraReference]
)
let partyReference = CompendiumItemReference(itemTitle: party.title, itemKey: party.key)
try store.put(CompendiumEntry(
    party,
    origin: .created(nil),
    document: .init(legacyHomebrewDocument)
))

var myrmidonCombatant = Combatant(
    id: uuid("10000000-0000-0000-0000-000000000301").tagged(),
    compendiumCombatant: myrmidon,
    party: nil,
    persistent: false
)
myrmidonCombatant.initiative = 14
myrmidonCombatant.hp = hitPoints(current: 23, maximum: 39, temporary: 4)
myrmidonCombatant.resources = [
    CombatantResource(
        id: uuid("10000000-0000-0000-0000-000000000401").tagged(),
        title: "Overdrive",
        slots: [true, false, false]
    )
]

var miraCombatant = Combatant(
    id: uuid("10000000-0000-0000-0000-000000000302").tagged(),
    compendiumCombatant: mira,
    party: partyReference,
    persistent: true
)
miraCombatant.initiative = 17
miraCombatant.hp = hitPoints(current: 29, maximum: 33)
miraCombatant.resources = [
    CombatantResource(
        id: uuid("10000000-0000-0000-0000-000000000402").tagged(),
        title: "Arcane Recovery",
        slots: [true]
    )
]

var adHocStats = StatBlock.default
adHocStats.name = "Festival Pyromancer"
adHocStats.armorClass = 12
adHocStats.hitPoints = 18
adHocStats.abilityScores = AbilityScores(
    strength: 8,
    dexterity: 14,
    constitution: 10,
    intelligence: 12,
    wisdom: 10,
    charisma: 16
)
var pyromancer = Combatant(
    id: uuid("10000000-0000-0000-0000-000000000303").tagged(),
    adHoc: AdHocCombatantDefinition(
        id: uuid("10000000-0000-0000-0000-000000000304").tagged(),
        stats: adHocStats,
        player: nil,
        level: nil,
        original: myrmidonReference
    )
)
pyromancer.initiative = 11
pyromancer.hp = hitPoints(current: 7, maximum: 18)

var encounter = Encounter(
    id: uuid("10000000-0000-0000-0000-000000000501"),
    name: "Upgrade Fixture Encounter",
    combatants: [miraCombatant, myrmidonCombatant, pyromancer]
)
encounter.ensureStableDiscriminators = true
encounter.partyForDifficulty = .combatant(.init(filter: [miraCombatant.id]))

let running = RunningEncounter(
    id: uuid("10000000-0000-0000-0000-000000000502").tagged(),
    base: encounter,
    current: encounter,
    turn: .init(round: 2, combatantId: myrmidonCombatant.id),
    log: [
        RunningEncounterEvent(
            id: uuid("10000000-0000-0000-0000-000000000601").tagged(),
            turn: .init(round: 1, combatantId: miraCombatant.id),
            combatantEvent: .init(
                target: .init(id: myrmidonCombatant.id, name: myrmidonCombatant.name, discriminator: myrmidonCombatant.discriminator),
                source: .init(id: miraCombatant.id, name: miraCombatant.name, discriminator: miraCombatant.discriminator),
                effect: .init(currentHp: 23)
            )
        ),
        RunningEncounterEvent(
            id: uuid("10000000-0000-0000-0000-000000000602").tagged(),
            turn: .init(round: 1, combatantId: myrmidonCombatant.id),
            combatantEvent: .init(
                target: .init(id: pyromancer.id, name: pyromancer.name, discriminator: pyromancer.discriminator),
                source: .init(id: myrmidonCombatant.id, name: myrmidonCombatant.name, discriminator: myrmidonCombatant.discriminator),
                effect: .init(currentHp: 7)
            )
        )
    ]
)
encounter.runningEncounterKey = running.key.rawValue

try store.put(encounter)
try store.put(running)

let campaignGroup = CampaignNode(
    id: uuid("10000000-0000-0000-0000-000000000701").tagged(),
    title: "Legacy Campaign",
    contents: nil,
    special: nil,
    parentKeyPrefix: CampaignNode.root.keyPrefixForChildren.rawValue
)
let encounterNode = CampaignNode(
    id: uuid("10000000-0000-0000-0000-000000000702").tagged(),
    title: encounter.name,
    contents: .init(key: encounter.key.rawValue, type: .encounter),
    special: nil,
    parentKeyPrefix: campaignGroup.keyPrefixForChildren.rawValue
)
let notesNode = CampaignNode(
    id: uuid("10000000-0000-0000-0000-000000000703").tagged(),
    title: "Session zero notes",
    contents: nil,
    special: nil,
    parentKeyPrefix: campaignGroup.keyPrefixForChildren.rawValue
)
try store.put(campaignGroup)
try store.put(encounterNode)
try store.put(notesNode)

try store.put(Preferences(didShowWelcomeSheet: true, parseableManagerLastRunVersion: nil, errorReportingEnabled: false))
try database.close()
