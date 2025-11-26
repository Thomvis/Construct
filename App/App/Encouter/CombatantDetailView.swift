//
//  CombatantDetailView.swift
//  Construct
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import ActionResolutionFeature
import BetterSafariView
import ComposableArchitecture
import DiceRollerFeature
import GameModels
import Helpers
import SharedViews
import SwiftUI
import Tagged

struct CombatantDetailContainerView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode

    let store: StoreOf<CombatantDetailFeature>

    var body: some View {
        NavigationStack {
            CombatantDetailView(store: store)
                .navigationBarItems(trailing: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done").bold()
                })
        }
    }
}

struct CombatantDetailView: View {
    @EnvironmentObject var modifierFormatter: ModifierFormatter
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    @Bindable var store: StoreOf<CombatantDetailFeature>

    init(store: StoreOf<CombatantDetailFeature>) {
        self.store = store
    }

    var combatant: Combatant {
        store.combatant
    }

    var body: some View {
        navigationDestinations(
            baseContent
                .navigationBarTitle(Text(store.navigationTitle), displayMode: .inline)
                // START: work-around for https://forums.swift.org/t/14-5-beta3-navigationlink-unexpected-pop/45279/27
                .background(VStack {
                    NavigationLink(destination: EmptyView()) {
                        EmptyView()
                    }

                    NavigationLink(destination: EmptyView()) {
                        EmptyView()
                    }
                })
                // END
        )
        .eraseToAnyView
    }

    private var baseContent: some View {
        ZStack {
            scrollViewContent
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == StatBlockView.urlSchema,
                          let host = url.host,
                          let target = try? StatBlockView.TapTarget(urlEncoded: host)
                    else {
                        return .systemAction
                    }

                    if case .compendiumItemReferenceTextAnnotation(let annotation) = target {
                        store.send(.didTapCompendiumItemReferenceTextAnnotation(annotation, appNavigation))
                    }
                    return .handled
                })
                // Placing this (and .popover) inside the scrollview to work around https://github.com/stleamist/BetterSafariView/issues/23
                .safariView(
                    item: Binding(
                        get: { store.safari },
                        set: { store.send(.setSafari($0)) }
                    ),
                    onDismiss: { store.send(.setSafari(nil)) },
                    content: { state in
                        BetterSafariView.SafariView(
                            url: state.url
                        )
                    }
                )
                .popover(popover)
                .alert(store: store.scope(state: \.$alert, action: \.alert))
                .onAppear {
                    store.send(.onAppear)
                }
        }
    }

    private var scrollViewContent: some View {
        ScrollView {
            contentStack
        }
    }

    private var contentStack: some View {
        VStack(spacing: 18) {
            header
            traitsSection
            tagsSection
            resourcesSection
            statsSection
            if let running = store.runningEncounter {
                latestEvents(running)
            }
            editSection
        }
        .padding(12)
        .padding(.bottom, 50)
    }

    private func navigationDestinations<Content: View>(_ content: Content) -> some View {
        content
            .navigationDestination(
                store: store.scope(state: \.$destination, action: \.destination)
            ) { destinationStore in
                switch destinationStore.case {
                case let .combatantTagEditView(store):
                    CombatantTagEditView(store: store)
                case let .compendiumItemDetailView(store):
                    CompendiumEntryDetailView(store: store)
                case let .combatantTagsView(store):
                    CombatantTagsView(store: store)
                case let .combatantResourcesView(store):
                    CombatantResourcesView(store: store)
                case let .creatureEditView(store):
                    CreatureEditView(store: store)
                case let .runningEncounterLogView(store):
                    RunningEncounterLogView(store: store)
                }
            }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            SimpleButton(action: {
                store.send(.popover(.healthAction(HealthDialogFeature.State(numberEntryView: NumberEntryFeature.State.pad(value: 0), hp: combatant.hp))))
            }) {
                VStack {
                    Text("Hit Points")
                    combatant.hp.map { hp in
                        HStack(alignment: .firstTextBaseline) {
                            VStack {
                                Text("\(hp.current)").font(.title)
                                Text("Cur").font(.subheadline).foregroundColor(Color(UIColor.secondaryLabel))
                            }
                            VStack {
                                Text("/").font(.title)
                                Text("").font(.subheadline).foregroundColor(Color(UIColor.secondaryLabel))
                            }
                            VStack {
                                Text("\(hp.maximum)").font(.title)
                                Text("Max").font(.subheadline).foregroundColor(Color(UIColor.secondaryLabel))
                            }
                            VStack {
                                Text("\(hp.temporary)").font(.title)
                                Text("Temp").font(.subheadline).foregroundColor(Color(UIColor.secondaryLabel))
                            }
                        }
                    }.replaceNilWith {
                        Text("--").font(.subheadline)
                    }
                    .equalSize()
                }
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground).cornerRadius(8))
            }

            Text(combatant.definition.ac.map { "\($0)" } ?? "--")
                .font(.title)
                .background(
                    Image(systemName: "shield")
                        .resizable()
                        .font(Font.title.weight(.light))
                        .aspectRatio(contentMode: .fit)
                        .padding(-10)
                )
                .padding(10)

            SimpleButton(action: {
                store.send(.popover(.initiative(NumberEntryFeature.State.initiative(combatant: combatant))))
            }) {
                VStack {
                    Text("Initiative")

                    Group {
                        if let initiative = combatant.initiative {
                            Text("\(initiative)")
                        } else if let intMod = combatant.definition.initiativeModifier {
                            Text(modifierFormatter.string(from: intMod)).italic().opacity(0.6)
                        } else {
                            Text("--").italic().foregroundColor(Color(UIColor.secondaryLabel))
                        }
                    }
                    .font(.title)
                    .equalSize()
                }
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground).cornerRadius(8))
        }.equalSizes(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var traitsSection: some View {
        if combatant.hasTraits {
            SectionContainer(
                title: "Traits",
                accessory: Menu("Manage", content: {
                    Button(role: .destructive) {
                        store.send(.combatant(.removeTraits), animation: .default)
                    } label: {
                        Label("Remove", systemImage: "clear")
                    }

                    Text("Editing is not yet supported")
                }),
                footer: {
                    if combatant.traits?.generatedByMechMuse == true {
                        HStack {
                            Spacer()
                            Text("Mechanical Muse")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    if let appearance = combatant.traits?.physical {
                        StatBlockView.line(title: "Physical", text: appearance)
                    }

                    if let behavior = combatant.traits?.personality {
                        StatBlockView.line(title: "Personality", text: behavior)
                    }

                    if let nickname = combatant.traits?.nickname {
                        StatBlockView.line(title: "Nickname", text: nickname)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        SectionContainer(
            title: "Tags",
            accessory: Button(action: {
                let state = CombatantTagsFeature.State(combatants: [combatant], effectContext: store.runningEncounter.map {
                    EffectContext(
                        source: nil,
                        targets: [store.combatant],
                        running: $0
                    )
                })
                store.send(.setDestination(.combatantTagsView(state)))
            }, label: {
                Text("Manage")
            })
        ) {
            InlineCombatantTagsView(store: store)
        }
    }

    @ViewBuilder
    private var resourcesSection: some View {
        if !combatant.resources.isEmpty {
            let combatantStore = store.scope(state: \.combatant, action: \.combatant)
            SectionContainer(
                title: "Limited resources",
                accessory: Button(action: {
                    let state = CombatantResourcesFeature.State(combatant: combatant)
                    store.send(.setDestination(.combatantResourcesView(state)))
                }, label: {
                    Text("Manage")
                })
            ) {
                ForEach(combatant.resources) { resource in
                    CombatantResourceTrackerView(
                        store: combatantStore.scope(
                            state: \.resources[id: resource.id]!,
                            action: \.resources[id: resource.id]
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        VStack {
            SectionContainer(
                title: "Stats",
                accessory: Button {
                    store.send(.editCreatureConfirmingUnlinkIfNeeded)
                } label: {
                    Text("Edit")
                }
            ) {
                contentView(for: combatant)
            }

            if let attribution = store.attribution {
                Text(attribution)
                    .font(.footnote).italic()
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var editSection: some View {
        SectionContainer(title: "Edit") {
            VStack(alignment: .leading) {
                Button(action: {
                    store.send(.popover(.addLimitedResource(CombatantTrackerEditFeature.State(resource: CombatantResource(id: UUID().tagged(), title: "", slots: [false])))))
                }) {
                    Text("Add limited resource")
                }

                if combatant.definition is CompendiumCombatantDefinition {
                    Divider()

                    VStack(alignment: .leading) {
                        Button(action: {
                            store.send(.unlinkFromCompendium)
                        }) {
                            Text("Detach from compendium")
                        }
                        Text("This combatant was added from the compendium. Detach it to further tailor it for this encounter.").font(.footnote).foregroundColor(Color(UIColor.secondaryLabel)).fixedSize(horizontal: false, vertical: true)
                    }
                }

                if combatant.definition is AdHocCombatantDefinition {
                    Divider()

                    VStack(alignment: .leading) {
                        Button(action: {
                            store.send(.saveToCompendium)
                        }) {
                            Text("Save to compendium")
                        }
                        Text("This combatant was created for this encounter. Save it to the compendium to make it available for other encounters.").font(.footnote).foregroundColor(Color(UIColor.secondaryLabel)).fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    Button {
                        let state = {
                            guard let def = combatant.definition as? AdHocCombatantDefinition else { return CreatureEditFeature.State(create: .monster) }
                            return CreatureEditFeature.State(edit: def)
                        }()
                        store.send(.setDestination(.creatureEditView(state)))
                    } label: {
                        Text("Edit combatant")
                    }
                }
            }
        }
    }

    func contentView(for combatant: Combatant) -> some View {
        let stats = combatant.definition.stats
        return StatBlockView(stats: stats, onTap: { target in
            switch target {
            case .ability(let a):
                let modifier: Int = stats.abilityScores?.score(for: a).modifier.modifier ?? 0
                store.send(.popover(.rollCheck(.rolling(.abilityCheck(modifier, ability: a, skill: nil, combatant: combatant), rollOnAppear: true))))
            case .skill(let s):
                let modifier: Int = stats.skillModifier(s).modifier
                store.send(.popover(.rollCheck(.rolling(.abilityCheck(modifier, ability: s.ability, skill: s, combatant: combatant), rollOnAppear: true))))
            case .action(let action):
                let state = ActionResolutionFeature.State(
                    encounterContext: .init(
                        encounter: store.runningEncounter?.current,
                        combatant: combatant
                    ),
                    creatureStats: apply(combatant.definition.stats) {
                        $0.name = combatant.discriminatedName
                    },
                    action: action
                )
                store.send(.popover(.diceAction(state)))
            case .rollCheck(let e):
                store.send(.popover(.rollCheck(DiceCalculator.State.rollingExpression(e, rollOnAppear: true))))
            case .compendiumItemReferenceTextAnnotation(let annotation):
                store.send(.didTapCompendiumItemReferenceTextAnnotation(annotation, appNavigation))
            }
        })
    }

    func latestEvents(_ running: RunningEncounter) -> some View {
        let log = running.log.filter { $0.involves(store.combatant) }.reversed()
        return Group {
            if !log.isEmpty {
                SectionContainer(title: "Latest", accessory: Button {
                    let state = RunningEncounterLogViewState(encounter: running, context: store.combatant)
                    store.send(.setDestination(.runningEncounterLogView(state)))
                } label: {
                    Text("View all (\(log.count))")
                }) {
                    VStack {
                        SimpleList(data: log.prefix(3), id: \.id) { event in
                            RunningEncounterEventRow(encounter: running.current, event: event, context: store.combatant)
                        }
                    }
                }
            }
        }
    }

    var popover: Binding<AnyView?> {
        Binding<AnyView?>(
            get: { () -> AnyView? in
                guard let currentPopover = store.popover else { return nil }
                switch currentPopover {
                case .healthAction:
                    return HealthDialog(hp: nil) {
                        store.send(.combatant($0))
                        store.send(.popover(nil))
                    }.eraseToAnyView
                case .initiative:
                    if let initiativeStore = store.scope(state: \.initiativePopoverState, action: \.initiativePopover) {
                        return NumberEntryPopover(store: initiativeStore) { p in
                            store.send(.combatant(.initiative(p)))
                            store.send(.popover(nil))
                        }
                        .eraseToAnyView
                    }
                case .rollCheck:
                    if let rollCheckStore = store.scope(state: \.rollCheckDialogState, action: \.rollCheckDialog) {
                        return DiceCalculatorView(store: rollCheckStore).eraseToAnyView
                    }
                case .diceAction:
                    if let diceActionStore = store.scope(state: \.diceActionPopoverState, action: \.diceActionPopover) {
                        return ActionResolutionView(store: diceActionStore).eraseToAnyView
                    }
                case .tagDetails(let tag):
                    return CombatantTagPopover(running: store.runningEncounter, combatant: combatant, tag: tag, onEditTap: {
                        store.send(.popover(nil))
                        store.send(.setDestination(.combatantTagEditView(CombatantTagEditFeature.State(mode: .edit, tag: tag, effectContext: store.runningEncounter.map { EffectContext(source: nil, targets: [combatant], running: $0) }))))
                    }).eraseToAnyView
                case .addLimitedResource:
                    if let addLimitedResourceStore = store.scope(state: \.addLimitedResourceState, action: \.addLimitedResource) {
                        return CombatantTrackerEditView(store: addLimitedResourceStore).eraseToAnyView
                    }
                }
                return nil
            },
            set: { _ in
                store.send(.popover(nil))
            }
        )
    }
}
