//
//  CompendiumItemDetailView.swift
//  Construct
//
//  Created by Thomas Visser on 23/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels
import Helpers
import DiceRollerFeature
import BetterSafariView
import ActionResolutionFeature
import Compendium
import SharedViews

struct CompendiumEntryDetailView: View {
    @SwiftUI.Environment(\.appNavigation) var appNavigation

    var store: StoreOf<CompendiumEntryDetailFeature>

    var item: CompendiumItem {
        store.item
    }

    var itemStatBlock: StatBlock? {
        switch item {
        case let monster as Monster: return monster.stats
        case let character as Character: return character.stats
        default: return nil
        }
    }

    var body: some View {
        content
    }

    private var content: some View {
        let scroll = ScrollView {
            VStack {
                contentView()
                
                if let attribution = store.entryAttribution {
                    Text(attribution)
                        .font(.footnote).italic()
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 12, bottom: 80, trailing: 12))
            // Placing .popover inside ScrollView to work around https://github.com/stleamist/BetterSafariView/issues/23
            .popover(popoverBinding)
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == StatBlockView.urlSchema,
                  let host = url.host,
                  let target = try? StatBlockView.TapTarget(urlEncoded: host)
            else {
                return .systemAction
            }

            self.onTap(target)
            return .handled
        })

        let base = scroll
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    with(menuItems) { items in
                        if let only = items.single {
                            Button(action: only.action) {
                                Text(only.text)
                            }
                        } else if items.count > 1 {
                            Menu(content: {
                                ForEach(menuItems, id: \.text) { item in
                                    if item.text == MenuItem.divider.text {
                                        Divider()
                                    } else {
                                        Button(action: item.action) {
                                            Label(item.text, systemImage: item.systemImage)
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: "ellipsis.circle").frame(width: 30, height: 30, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle(Text(store.navigationTitle), displayMode: .inline)

        let navigation = base
            .onAppear {
                store.send(.onAppear)
            }
            .navigationDestination(
                store: store.scope(state: \.$destination, action: \.destination)
            ) { destinationStore in
                switch destinationStore.case {
                case let .compendiumItemDetailView(store):
                    CompendiumEntryDetailView(store: store)
                }
            }

        return navigation
            .safariView(
                item: Binding(get: { store.safari }, set: { store.send(.setSafari($0)) }),
                onDismiss: { store.send(.setSafari(nil)) },
                content: { state in
                    BetterSafariView.SafariView(
                        url: state.url
                    )
                }
            )
            .sheet(
                store: store.scope(state: \.$sheet, action: \.sheet)
            ) { sheetStore in
                switch sheetStore.case {
                case let .creatureEdit(store):
                    SheetNavigationContainer(isModalInPresentation: true) {
                        CreatureEditView(store: store)
                    }
                case let .groupEdit(store):
                    SheetNavigationContainer {
                        CompendiumItemGroupEditView(store: store)
                    }
                case let .transfer(store):
                    AutoSizingSheetContainer {
                        SheetNavigationContainer {
                            CompendiumItemTransferSheet(store: store)
                                .autoSizingSheetContent(constant: 40)
                                .navigationTitle("Move")
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }
                }
            }
    }

    @ViewBuilder
    func contentView() -> some View {
        if let monster = item as? Monster {
            CompendiumMonsterDetailView(monster: monster) { m in
                StatBlockView(stats: m.stats, onTap: onTap(m.stats))
            }
        } else if let spell = item as? Spell {
            CompendiumSpellDetailView(spell: spell, onTap: onTap(StatBlock.default))
        } else if let character = item as? Character {
            CompendiumCharacterDetailView(character: character) { c in
                StatBlockView(stats: c.stats, onTap: onTap(c.stats))
            }
        } else if let group = item as? CompendiumItemGroup {
            CompendiumItemGroupDetailView(group: group)
        }
    }

    var editViewState: CreatureEditFeature.State? {
        switch item {
        case let monster as Monster: return CreatureEditFeature.State(
            edit: monster,
            documentId: store.entry.document.id,
            origin: store.entry.origin
        )
        case let character as Character: return CreatureEditFeature.State(
            edit: character,
            documentId: store.entry.document.id,
            origin: store.entry.origin
        )
        default: return nil
        }
    }

    @ArrayBuilder<MenuItem>
    var menuItems: [MenuItem] {
        let isCreature = item is Monster || item is Character
        if isCreature {
            MenuItem(text: "Edit", systemImage: "pencil") {
                if let evs = self.editViewState {
                    self.store.send(.setSheet(.creatureEdit(evs)))
                }
            }
        } else if let group =  item as? CompendiumItemGroup {
            MenuItem(text: "Edit", systemImage: "pencil") {
                self.store.send(.setSheet(.groupEdit(CompendiumItemGroupEditFeature.State(mode: .edit, group: group))))
            }
        }

        if isCreature, let itemStatBlock {
            MenuItem(text: "Edit a copy", systemImage: "document.on.document") {
                var state = CreatureEditFeature.State(create: .monster)
                state.model.statBlock = .init(statBlock: itemStatBlock)
                state.sections = state.creatureType.initialSections.union(state.model.sectionsWithData)
                state.createOrigin = .created(CompendiumItemReference(self.store.item))
                self.store.send(.setSheet(.creatureEdit(state)))
            }
        }

        MenuItem.divider

        // Move/Copy option available for all items
        MenuItem(text: "Move...", systemImage: "arrow.right.doc.on.clipboard") {
            let state = CompendiumItemTransferFeature.State(
                mode: .move,
                selection: .single(self.store.item.key),
                originDocument: CompendiumFilters.Source(
                    realm: self.store.item.realm.value,
                    document: self.store.entry.document.id
                )
            )
            self.store.send(.setSheet(.transfer(state)))
        }
    }

    /// Handles the stats-related tap targets, defers to onTap below for the more general targets
    func onTap(_ stats: StatBlock) -> ((StatBlockView.TapTarget) -> Void)? {
        { target in
            switch target {
            case .ability(let a):
                let modifier: Int = stats.abilityScores?.score(for: a).modifier.modifier ?? 0
                self.store.send(.popover(.rollCheck(.rolling(.abilityCheck(modifier, ability: a, skill: nil, creatureName: stats.name), rollOnAppear: true))))
            case .skill(let s):
                let modifier: Int = stats.skillModifier(s).modifier
                self.store.send(.popover(.rollCheck(.rolling(.abilityCheck(modifier, ability: s.ability, skill: s, creatureName: stats.name), rollOnAppear: true))))
            case .action(let action):
                let state = ActionResolutionFeature.State(
                    creatureStats: stats,
                    action: action
                )
                self.store.send(.popover(.creatureAction(state)))
            default:
                onTap(target)
            }
        }
    }

    /// Handles the stat-free targets
    func onTap(_ target: StatBlockView.TapTarget) {
        switch target {
        case .rollCheck(let e):
            self.store.send(.popover(.rollCheck(DiceCalculator.State.rollingExpression(e, rollOnAppear: true))))
        case .compendiumItemReferenceTextAnnotation(let a):
            self.store.send(.didTapCompendiumItemReferenceTextAnnotation(a, appNavigation))
        default:
            assertionFailure("Failed to handle statblock tap target: \(target)")
            break
        }
    }

    var popoverBinding: Binding<AnyView?> {
        Binding(get: {
            switch store.popover {
            case .creatureAction:
                if let popoverStore = store.scope(state: \.createActionPopover, action: \.creatureActionPopover) {
                    return ActionResolutionView(store: popoverStore).eraseToAnyView
                }
                return nil
            case .rollCheck:
                if let popoverStore = store.scope(state: \.rollCheckPopover, action: \.rollCheckPopover) {
                    return DiceCalculatorView(store: popoverStore).eraseToAnyView
                }
                return nil
            case nil: return nil
            }
        }, set: {
            assert($0 == nil)
            self.store.send(.popover(nil))
        })
    }

    struct MenuItem {
        let text: String
        let systemImage: String
        let action: () -> Void

        static let divider = MenuItem(text: "DIVIDER", systemImage: "", action: { })
    }
}

struct CompendiumCharacterDetailView: View {
    let character: Character
    let statBlockView: (Character) -> StatBlockView

    var body: some View {
        SectionContainer {
            statBlockView(character)
        }
    }
}

struct CompendiumMonsterDetailView: View {
    let monster: Monster
    let statBlockView: (Monster) -> StatBlockView

    var body: some View {
        SectionContainer {
            statBlockView(monster)
        }
    }
}

struct CompendiumSpellDetailView: View {
    @EnvironmentObject var ordinalFormatter: OrdinalFormatter
    let spell: Spell
    let onTap: ((StatBlockView.TapTarget) -> Void)?

    var body: some View {
        SectionContainer {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    Text(spell.name).font(.title).lineLimit(nil)
                    Text(spell.subheading(ordinalFormatter: ordinalFormatter)).italic().lineLimit(nil)
                }

                Divider()

                Group {
                    HStack {
                        StatBlockView.line(title: "Casting time", text: spell.castingTime)
                        if spell.ritual {
                            Text("(Ritual)")
                        }
                    }
                    StatBlockView.line(title: "Range", text: spell.range)
                    StatBlockView.line(title: "Components", text: spell.componentsSummary)
                    HStack {
                        StatBlockView.line(title: "Duration", text: spell.duration)
                        if spell.concentration {
                            Text("(Concentration)")
                        }
                    }
                }

                Divider()

                Text(descriptionString)
                spell.higherLevelDescription.map { StatBlockView.line(title: "At Higher Levels.", text: $0) }
                spell.material.map { Text("* \($0)").font(.footnote).italic() }

                spell.classSummary.map { summary in
                    Group {
                        Divider()
                        Text(verbatim: summary).font(.footnote)
                    }
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == StatBlockView.urlSchema,
                  let host = url.host,
                  let target = try? StatBlockView.TapTarget(urlEncoded: host)
            else {
                return .systemAction
            }

            onTap?(target)
            return .handled
        })
    }

    var descriptionString: AttributedString {
        var result = spell.description.attributedDescription
        StatBlockView.process(attributedString: &result)

        return result
    }
}

extension Spell {
    func subheading(ordinalFormatter: OrdinalFormatter) -> String {
        let levelText: String
        if let level = level {
            levelText = "\(ordinalFormatter.string(from: level)) level"
        } else {
            levelText = "Cantrip"
        }

        return "\(levelText) (\(school))"
    }

    var componentsSummary: String {
        let list = components.compactMap { $0.rawValue.first.map { String($0).uppercased() } }.joined(separator: ", ")
        if components.contains(.material) {
            return "\(list) *"
        } else {
            return list
        }
    }

    var classSummary: String? {
        guard !classes.isEmpty, let list = ListFormatter().string(for: classes) else { return nil }
        return "Classes: \(list)"
    }
}
