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

struct CompendiumItemDetailView: View {
    @EnvironmentObject var env: Environment
    @SwiftUI.Environment(\.appNavigation) var appNavigation

    var store: Store<CompendiumEntryDetailViewState, CompendiumItemDetailViewAction>
    @ObservedObject var viewStore: ViewStore<CompendiumEntryDetailViewState, CompendiumItemDetailViewAction>

    init(store: Store<CompendiumEntryDetailViewState, CompendiumItemDetailViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication })
    }

    var item: CompendiumItem {
        viewStore.state.item
    }

    var itemStatBlock: StatBlock? {
        switch item {
        case let monster as Monster: return monster.stats
        case let character as Character: return character.stats
        default: return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack {
                contentView()

                if let sourceDisplayName = viewStore.state.entry.source?.displayName {
                    Text(sourceDisplayName)
                        .font(.footnote).italic()
                        .foregroundColor(Color.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 12, bottom: 80, trailing: 12))
            // Placing .popover inside ScrollView to work around https://github.com/stleamist/BetterSafariView/issues/23
            .popover(popoverBinding)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                with(menuItems) { items in
                    if let only = items.single {
                        Button(action: only.action) {
                            Text(only.text)
                        }
                    } else {
                        Menu(content: {
                            ForEach(menuItems, id: \.text) { item in
                                Button(action: item.action) {
                                    Label(item.text, systemImage: item.systemImage)
                                }
                            }
                        }) {
                            Image(systemName: "ellipsis.circle").frame(width: 30, height: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(viewStore.state.navigationTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: viewStore.binding(get: \.sheet) { _ in .setSheet(nil) }, content: self.sheetView)
        .onAppear {
            viewStore.send(.onAppear)
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

    @ViewBuilder
    func sheetView(_ sheet: CompendiumEntryDetailViewState.Sheet) -> some View {
        switch viewStore.state.sheet {
        case .creatureEdit:
            IfLetStore(store.scope(state: replayNonNil({ $0.creatureEditSheet }), action: { .sheet(.creatureEdit($0)) })) { store in
                SheetNavigationContainer(isModalInPresentation: true) {
                    CreatureEditView(store: store)
                }
            }
        case .groupEdit:
            IfLetStore(store.scope(state: replayNonNil({ $0.groupEditSheet }), action: { .sheet(.groupEdit($0)) })) { store in
                SheetNavigationContainer {
                    CompendiumItemGroupEditView(store: store)
                }
            }
        default: EmptyView()
        }
    }

    var editViewState: CreatureEditViewState? {
        switch item {
        case let monster as Monster: return CreatureEditViewState(edit: monster)
        case let character as Character: return CreatureEditViewState(edit: character)
        default: return nil
        }
    }

    var menuItems: [MenuItem] {
        switch item {
        case let monster as Monster: return [
            MenuItem(text: "Save as NPC", systemImage: "plus.square.on.square") {
                self.viewStore.send(.onSaveMonsterAsNPCButton(monster))
            },
            MenuItem(text: "Edit", systemImage: "pencil") {
                if let evs = self.editViewState {
                    self.viewStore.send(.setSheet(.creatureEdit(evs)))
                }
            }
        ]
        case is Character: return [
            MenuItem(text: "Edit", systemImage: "pencil") {
                if let evs = self.editViewState {
                    self.viewStore.send(.setSheet(.creatureEdit(evs)))
                }
            }
        ]
        case let group as CompendiumItemGroup: return [
            MenuItem(text: "Edit", systemImage: "pencil") {
                self.viewStore.send(.setSheet(.groupEdit(CompendiumItemGroupEditState(mode: .edit, group: group))))
            }
        ]
        default: return []
        }
    }

    func onTap(_ stats: StatBlock) -> ((StatBlockView.TapTarget) -> Void)? {
        { target in
            switch target {
            case .ability(let a):
                let modifier: Int = stats.abilityScores?.score(for: a).modifier.modifier ?? 0
                self.viewStore.send(.popover(.rollCheck(.rolling(.abilityCheck(modifier, ability: a, skill: nil, creatureName: stats.name, environment: self.env), rollOnAppear: true))))
            case .skill(let s):
                let modifier: Int = stats.skillModifier(s)?.modifier ?? 0
                self.viewStore.send(.popover(.rollCheck(.rolling(.abilityCheck(modifier, ability: s.ability, skill: s, creatureName: stats.name, environment: self.env), rollOnAppear: true))))
            case .action(let a, let p):
                if let action = DiceAction(title: a.name, parsedAction: p, env: env) {
                    self.viewStore.send(.popover(.creatureAction(DiceActionViewState(creatureName: stats.name, action: action))))
                }
            case .rollCheck(let e):
                self.viewStore.send(.popover(.rollCheck(DiceCalculatorState.rollingExpression(e, rollOnAppear: true))))
            case .compendiumItemReferenceTextAnnotation(let a):
                self.viewStore.send(.didTapCompendiumItemReferenceTextAnnotation(a, appNavigation))
            }
        }
    }

    var popoverBinding: Binding<AnyView?> {
        Binding(get: {
            switch viewStore.state.popover {
            case .creatureAction:
                return IfLetStore(store.scope(state: { $0.createActionPopover }, action: { .creatureActionPopover($0) })) { store in
                    return DiceActionView(
                        store: store
                    )
                }.eraseToAnyView
            case .rollCheck:
                return IfLetStore(store.scope(state: { $0.rollCheckPopover }, action: { .rollCheckPopover($0) })) { store in
                    DiceCalculatorView(store: store)
                }.eraseToAnyView
            case nil: return nil
            }
        }, set: {
            assert($0 == nil)
            self.viewStore.send(.popover(nil))
        })
    }

    struct MenuItem {
        let text: String
        let systemImage: String
        let action: () -> Void
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
    @EnvironmentObject var env: Environment
    let spell: Spell
    let onTap: ((StatBlockView.TapTarget) -> Void)?

    var body: some View {
        SectionContainer {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    Text(spell.name).font(.title).lineLimit(nil)
                    Text(spell.subheading(env)).italic().lineLimit(nil)
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
    func subheading(_ env: Environment) -> String {
        let levelText: String
        if let level = level {
            levelText = "\(env.ordinalFormatter.stringWithFallback(for: level)) level"
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
