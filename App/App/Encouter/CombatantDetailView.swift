//
//  CombatantDetailView.swift
//  Construct
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import CasePaths
import ComposableArchitecture
import Tagged
import BetterSafariView
import SharedViews
import Helpers
import DiceRollerFeature
import GameModels
import ActionResolutionFeature

struct CombatantDetailContainerView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode

    @EnvironmentObject var env: Environment

    let store: Store<CombatantDetailViewState, CombatantDetailViewAction>

    var body: some View {
        NavigationStack {
            CombatantDetailView(store: store)
                .navigationBarItems(trailing: Group {
                    Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done").bold()
                    }
                })
        }
    }
}

struct CombatantDetailView: View {
    @EnvironmentObject var env: Environment
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    var store: Store<CombatantDetailViewState, CombatantDetailViewAction>
    @ObservedObject var viewStore: ViewStore<CombatantDetailViewState, CombatantDetailViewAction>

    init(store: Store<CombatantDetailViewState, CombatantDetailViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication })
    }

    var combatant: Combatant {
        viewStore.state.combatant
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        SimpleButton(action: {
                            self.viewStore.send(.popover(.healthAction(HealthDialogState(numberEntryView: NumberEntryViewState.pad(value: 0), hp: self.combatant.hp))))
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
                            self.viewStore.send(.popover(.initiative(NumberEntryViewState.initiative(combatant: combatant))))
                        }) {
                            VStack {
                                Text("Initiative")

                                combatant.initiative.map {
                                    Text("\($0)")
                                }.replaceNilWith {
                                    combatant.definition.initiativeModifier.map {
                                        Text(env.modifierFormatter.stringWithFallback(for: $0)).italic().opacity(0.6)
                                    }.replaceNilWith {
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

                    if combatant.hasTraits {
                        SectionContainer(
                            title: "Traits",
                            accessory: Menu("Manage", content: {
                                Button(role: .destructive) {
                                    viewStore.send(.combatant(.removeTraits), animation: .default)
                                } label: {
                                    Label("Remove", systemImage: "clear")
                                }

                                Text("Editing is not yet supported")
                            }),
                            footer: {
                                if combatant.traits?.generatedByMechMuse == true {
                                    HStack {
                                        Spacer()
                                        Text("Powered by Mechanical Muse")
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

                    SectionContainer(
                        title: "Tags",
                        accessory: Button(action: {
                            let state = CombatantTagsViewState(combatants: [self.combatant], effectContext: self.viewStore.state.runningEncounter.map {
                                EffectContext(
                                    source: nil,
                                    targets: [self.viewStore.state.combatant],
                                    running: $0
                                )
                            })
                            viewStore.send(.setNextScreen(.combatantTagsView(state)))
                        }, label: {
                            Text("Manage")
                        })
                    ) {
                        InlineCombatantTagsView(store: store, viewStore: viewStore)
                    }

                    if !combatant.resources.isEmpty {
                        SectionContainer(
                            title: "Limited resources",
                            accessory: Button(action: {
                                let state = CombatantResourcesViewState(combatant: self.combatant)
                                viewStore.send(.setNextScreen(.combatantResourcesView(state)))
                            }, label: {
                                Text("Manage")
                            })
                        ) {
                            SimpleList(data: combatant.resources, id: \.id) { resource in
                                IfLetStore(self.store.scope(state: { $0.combatant.resources.first { $0.id == resource.id } }, action: { .combatant(.resource(resource.id, $0)) })) { store in

                                    CombatantResourceTrackerView(store: store)
                                }
                            }
                        }
                    }

                    SectionContainer(
                        title: "Stats",
                        accessory: Button {
                            viewStore.send(.editCreatureConfirmingUnlinkIfNeeded)
                        } label: {
                            Text("Edit")
                        }
                    ) {
                        contentView(for: combatant)
                    }

                    viewStore.state.runningEncounter.map { running in
                        latestEvents(running)
                    }

                    SectionContainer(title: "Edit") {
                        VStack(alignment: .leading) {
                            Button(action: {
                                self.viewStore.send(.popover(.addLimitedResource(CombatantTrackerEditViewState(resource: CombatantResource(id: UUID().tagged(), title: "", slots: [false])))))
                            }) {
                                Text("Add limited resource")
                            }

                            if combatant.definition is CompendiumCombatantDefinition {
                                Divider()

                                VStack(alignment: .leading) {
                                    Button(action: {
                                        self.viewStore.send(.unlinkFromCompendium)
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
                                        self.viewStore.send(.saveToCompendium)
                                    }) {
                                        Text("Save to compendium")
                                    }
                                    Text("This combatant was created for this encounter. Save it to the compendium to make it available for other encounters.").font(.footnote).foregroundColor(Color(UIColor.secondaryLabel)).fixedSize(horizontal: false, vertical: true)
                                }

                                Divider()

                                Button {
                                    let state = {
                                        guard let def = self.combatant.definition as? AdHocCombatantDefinition else { return CreatureEditViewState(create: .monster) }
                                        return CreatureEditViewState(edit: def)
                                    }()
                                    viewStore.send(.setNextScreen(.creatureEditView(state)))
                                } label: {
                                    Text("Edit combatant")
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .padding(.bottom, 50)
                // Placing this (and .popover) inside the scrollview to work around https://github.com/stleamist/BetterSafariView/issues/23
                .safariView(
                    item: viewStore.binding(get: { $0.presentedNextSafariView }, send: { _ in .setNextScreen(nil) }),
                    onDismiss: { viewStore.send(.setNextScreen(nil)) },
                    content: { state in
                        BetterSafariView.SafariView(
                            url: state.url
                        )
                    }
                )
                .popover(self.popover)
                .alert(store.scope(state: { $0.alert }), dismiss: CombatantDetailViewAction.alert(nil))
            }
        }
        .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
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
        .stateDrivenNavigationLink(
            store: store,
            state: /CombatantDetailViewState.NextScreen.combatantTagEditView,
            action: /CombatantDetailViewAction.NextScreenAction.combatantTagEditView,
            destination: CombatantTagEditView.init
        )
        .stateDrivenNavigationLink(
            store: store,
            state: /CombatantDetailViewState.NextScreen.compendiumItemDetailView,
            action: /CombatantDetailViewAction.NextScreenAction.compendiumItemDetailView,
            destination: CompendiumItemDetailView.init
        )
        .stateDrivenNavigationLink(
            store: store,
            state: /CombatantDetailViewState.NextScreen.combatantTagsView,
            action: /CombatantDetailViewAction.NextScreenAction.combatantTagsView,
            destination: CombatantTagsView.init
        )
        .stateDrivenNavigationLink(
            store: store,
            state: /CombatantDetailViewState.NextScreen.combatantResourcesView,
            action: /CombatantDetailViewAction.NextScreenAction.combatantResourcesView,
            destination: CombatantResourcesView.init
        )
        .stateDrivenNavigationLink(
            store: store,
            state: /CombatantDetailViewState.NextScreen.creatureEditView,
            action: /CombatantDetailViewAction.NextScreenAction.creatureEditView,
            destination: CreatureEditView.init
        )
        .stateDrivenNavigationLink(
            store: store,
            state: /CombatantDetailViewState.NextScreen.runningEncounterLogView,
            action: /CombatantDetailViewAction.NextScreenAction.runningEncounterLogView,
            destination: RunningEncounterLogView.init
        )
    }

    func contentView(for combatant: Combatant) -> some View {
        let stats = combatant.definition.stats
        return StatBlockView(stats: stats, onTap: { target in
            switch target {
            case .ability(let a):
                let modifier: Int = stats.abilityScores?.score(for: a).modifier.modifier ?? 0
                self.viewStore.send(.popover(.rollCheck(.rolling(.abilityCheck(modifier, ability: a, skill: nil, combatant: combatant, environment: self.env), rollOnAppear: true))))
            case .skill(let s):
                let modifier: Int = stats.skillModifier(s).modifier
                self.viewStore.send(.popover(.rollCheck(.rolling(.abilityCheck(modifier, ability: s.ability, skill: s, combatant: combatant, environment: self.env), rollOnAppear: true))))
            case .action(let action):
                let state = ActionResolutionViewState(
                    encounterContext: .init(
                        encounter: viewStore.state.runningEncounter?.current,
                        combatant: combatant
                    ),
                    creatureStats: apply(combatant.definition.stats) {
                        $0.name = combatant.discriminatedName
                    },
                    action: action,
                    preferences: env.preferences()
                )
                self.viewStore.send(.popover(.diceAction(state)))
            case .rollCheck(let e):
                self.viewStore.send(.popover(.rollCheck(DiceCalculatorState.rollingExpression(e, rollOnAppear: true))))
            case .compendiumItemReferenceTextAnnotation(let annotation):
                self.viewStore.send(.didTapCompendiumItemReferenceTextAnnotation(annotation, appNavigation))
            }
        })
    }

    func latestEvents(_ running: RunningEncounter) -> some View {
        let log = running.log.filter { $0.involves(self.viewStore.state.combatant) }.reversed()
        return Group {
            if !log.isEmpty {
                SectionContainer(title: "Latest", accessory: Button {
                    let state = RunningEncounterLogViewState(encounter: running, context: self.viewStore.state.combatant)
                    viewStore.send(.setNextScreen(.runningEncounterLogView(state)))
                } label: {
                    Text("View all (\(log.count))")
                }) {
                    VStack {
                        SimpleList(data: log.prefix(3), id: \.id) { event in
                            RunningEncounterEventRow(encounter: running.current, event: event, context: self.viewStore.state.combatant)
                        }
                    }
                }
            }
        }
    }

    var popover: Binding<AnyView?> {
        return Binding(get: {
            guard let popover = self.viewStore.state.popover else { return nil }
            switch popover {
            case .healthAction:
                return HealthDialog(environment: self.env, hp: nil) {
                    viewStore.send(.combatant($0))
                    viewStore.send(.popover(nil))
                }.eraseToAnyView
            case .initiative:
                return IfLetStore(store.scope(state: { $0.initiativePopoverState }, action: { .initiativePopover($0) })) { store in
                    NumberEntryPopover(store: store) { p in
                        self.viewStore.send(.combatant(.initiative(p)))
                        self.viewStore.send(.popover(nil))
                    }
                }.eraseToAnyView
            case .rollCheck:
                return IfLetStore(store.scope(state: { $0.rollCheckDialogState }, action: { .rollCheckDialog($0) })) { store in
                    DiceCalculatorView(store: store)
                }.eraseToAnyView
            case .diceAction:
                return IfLetStore(store.scope(state: { $0.diceActionPopoverState }, action: { .diceActionPopover($0) })) { store in
                    ActionResolutionView(store: store)
                }.eraseToAnyView
            case .tagDetails(let tag):
                return CombatantTagPopover(running: self.viewStore.state.runningEncounter, combatant: self.combatant, tag: tag, onEditTap: {
                    self.viewStore.send(.popover(nil))
                    self.viewStore.send(.setNextScreen(.combatantTagEditView(CombatantTagEditViewState(mode: .edit, tag: tag, effectContext: self.viewStore.state.runningEncounter.map { EffectContext(source: nil, targets: [self.combatant], running: $0) }))))
                }).eraseToAnyView
            case .addLimitedResource:
                return IfLetStore(self.store.scope(state: { state -> CombatantTrackerEditViewState? in
                    guard case .addLimitedResource(let s)? = state.popover else { return nil }
                    return s
                }, action: { .addLimitedResource($0) })) { store in
                    CombatantTrackerEditView(store: store)
                }.eraseToAnyView
            }
        }, set: { _ in
            self.viewStore.send(.popover(nil))
        })
    }
}
