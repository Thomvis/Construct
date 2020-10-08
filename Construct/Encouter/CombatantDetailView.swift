//
//  CombatantDetailView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import CasePaths
import ComposableArchitecture

struct CombatantDetailContainerView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var env: Environment

    var store: Store<CombatantDetailViewState, CombatantDetailViewAction>
    @ObservedObject var viewStore: ViewStore<CombatantDetailViewState, CombatantDetailViewAction>

    init(store: Store<CombatantDetailViewState, CombatantDetailViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.normalizedForDeduplication == $1.normalizedForDeduplication })
    }

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    CombatantDetailView(store: store).padding(12).padding(.bottom, 50)
                }

                defaultActionBar.frame(maxHeight: .infinity, alignment: .bottom).padding(8)
            }
            .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
            .navigationBarItems(trailing: Group {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done").bold()
                }
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .edgesIgnoringSafeArea(.all)
    }

    var defaultActionBar: some View {
        HStack {
            Spacer()

            if let stats = viewStore.state.combatant.definition.stats {
                Menu(content: {
                    ForEach(Ability.allCases.reversed(), id: \.self) { a in
                        if let modifier = stats.savingThrowModifier(a) {
                            Button(action: {
                                viewStore.send(.popover(.rollCheck(NumberEntryViewState.dice(DiceCalculatorState.rollingExpression(1.d(20)+modifier.modifier, rollOnAppear: true)))))
                            }) {
                                Label(
                                    "\(a.localizedDisplayName) save: \(env.modifierFormatter.stringWithFallback(for: modifier.modifier))",
                                    systemImage: stats.savingThrows[a] != nil
                                        ? "circlebadge.fill"
                                        : "circlebadge"
                                )
                            }
                        } else {
                            Text(a.localizedDisplayName)
                        }
                    }

                    Divider()

                    Menu(content: {
                        ForEach(Ability.allCases.reversed(), id: \.rawValue) { a in
                            if let modifier = stats.abilityScores?.score(for: a).modifier {
                                Button(action: {
                                    viewStore.send(.popover(.rollCheck(NumberEntryViewState.dice(DiceCalculatorState.rollingExpression(1.d(20)+modifier.modifier, rollOnAppear: true)))))
                                }) {
                                    Label(title: {
                                        Text("\(a.localizedDisplayName): \(env.modifierFormatter.stringWithFallback(for: modifier.modifier))")
                                    }, icon: {
                                        Image(systemName: "circlebadge")
                                    })
                                }
                            } else {
                                Text(a.localizedDisplayName)
                            }
                        }

                        Divider()

                        ForEach(Skill.allCases.reversed(), id: \.rawValue) { s in
                            let title = "\(s.localizedDisplayName) (\(s.ability.localizedAbbreviation.uppercased()))"
                            if let modifier = stats.skillModifier(s) {
                                Button(action: {
                                    viewStore.send(.popover(.rollCheck(NumberEntryViewState.dice(DiceCalculatorState.rollingExpression(1.d(20)+modifier.modifier, rollOnAppear: true)))))
                                }) {
                                    Label(title: {
                                        Text("\(title): \(env.modifierFormatter.stringWithFallback(for: modifier.modifier))")
                                    }, icon: {
                                        Image(systemName: stats.skills[s] != nil
                                                ? "circlebadge.fill"
                                                : "circlebadge"
                                        )
                                    })
                                }
                            } else {
                                Text("\(title)")
                            }
                        }
                    }) {
                        Text("Ability Check...")
                    }
                }) {
                    RoundedButton(action: { }) {
                        Label("Roll...", systemImage: "die.face.6")
                    }
                    .frame(minWidth: 100)
                }
            }
        }
    }

    struct Rollable: Hashable {
        var title: String
        var modifier: Modifier?
        var proficient: Bool
        var ability: Bool
    }

}

struct CombatantDetailView: View {
    @EnvironmentObject var env: Environment

    var store: Store<CombatantDetailViewState, CombatantDetailViewAction>
    @ObservedObject var viewStore: ViewStore<CombatantDetailViewState, CombatantDetailViewAction>

    init(store: Store<CombatantDetailViewState, CombatantDetailViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store)
    }

    var combatant: Combatant {
        viewStore.state.combatant
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                SimpleButton(action: {
                    self.viewStore.send(.popover(.healthAction(HealthDialogState(numberEntryView: NumberEntryViewState.pad(value: 0), hp: self.combatant.hp))))
                }) {
                    VStack {
                        Text("Hit Points")
                        combatant.hp.map { hp in
                            HStack {
                                VStack {
                                    Text("\(hp.current)").font(.title)
                                    Text("Cur").font(.subheadline)
                                }.equalSize()
                                VStack {
                                    Text("/").font(.title)
                                    Text("").font(.subheadline)
                                }.fixedSize()
                                VStack {
                                    Text("\(hp.maximum)").font(.title)
                                    Text("Max").font(.subheadline)
                                }.equalSize()
                                VStack {
                                    Text("\(hp.temporary)").font(.title)
                                    Text("Temp").font(.subheadline)
                                }.equalSize()
                            }
                            .equalSizes(horizontal: true, vertical: false)
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
                    self.viewStore.send(.popover(.initiative(self.combatant)))
                }) {
                    VStack {
                        Text("Initiative")

                        combatant.initiative.map {
                            Text("\($0)")
                        }.replaceNilWith {
                            combatant.definition.initiativeModifier.map {
                                Text(env.modifierFormatter.stringWithFallback(for: $0)).italic().opacity(0.6)
                            }.replaceNilWith {
                                Text("--").italic().opacity(0.6)
                            }
                        }
                        .font(.title)
                        .equalSize()
                    }
                }
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground).cornerRadius(8))
            }.equalSizes(horizontal: false, vertical: true)

            SectionContainer(
                title: "Tags",
                accessory: StateDrivenNavigationLink(
                    store: store,
                    state: /CombatantDetailViewState.NextScreen.combatantTagsView,
                    action: /CombatantDetailViewAction.NextScreenAction.combatantTagsView,
                    isActive: { _ in true },
                    initialState: {
                        CombatantTagsViewState(combatants: [self.combatant], effectContext: self.viewStore.state.runningEncounter.map {
                            EffectContext(
                                source: nil,
                                targets: [self.viewStore.state.combatant],
                                running: $0
                            )
                        })
                    },
                    destination: CombatantTagsView.init) {
                    Text("Manage")
                 }
            ) {
                InlineCombatantTagsView(store: store, viewStore: viewStore)
            }

            if !combatant.resources.isEmpty {
                SectionContainer(
                    title: "Limited resources",
                    accessory: StateDrivenNavigationLink(
                        store: store,
                        state: /CombatantDetailViewState.NextScreen.combatantResourcesView,
                        action: /CombatantDetailViewAction.NextScreenAction.combatantResourcesView,
                        isActive: { _ in true },
                        initialState: {
                            CombatantResourcesViewState(combatant: self.combatant)
                        },
                        destination: CombatantResourcesView.init) {
                        Text("Manage")
                     }
                ) {
                    SimpleList(data: combatant.resources, id: \.id) { resource in
                        IfLetStore(self.store.scope(state: { $0.combatant.resources.first { $0.id == resource.id } }, action: { .combatant(.resource(resource.id, $0)) })) { store in

                            CombatantResourceTrackerView(store: store)
                        }
                    }
                }
            }

            SectionContainer(title: "Stats") {
                contentView(for: combatant)
            }

            viewStore.state.runningEncounter.map { running in
                latestEvents(running)
            }

            SectionContainer(title: "Edit") {
                VStack(alignment: .leading) {
                    Button(action: {
                        self.viewStore.send(.popover(.addLimitedResource(CombatantTrackerEditViewState(resource: CombatantResource(id: UUID(), title: "", slots: [false])))))
                    }) {
                        Text("Add limited resource")
                    }

                    if combatant.definition is CompendiumCombatantDefinition {
                        Divider()

                        VStack(alignment: .leading) {
                            Button(action: {
                                self.viewStore.send(.unlinkFromCompendium)
                            }) {
                                Text("Unlink from compendium")
                            }
                            Text("This combatant was added from the compendium. Unlink it to further tailor it for this encounter.").font(.footnote).foregroundColor(Color(UIColor.secondaryLabel))
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
                            Text("This combatant was created for this encounter. Save it to the compendium to make it available for other encounters.").font(.footnote).foregroundColor(Color(UIColor.secondaryLabel))
                        }

                        Divider()

                        StateDrivenNavigationLink(
                            store: store,
                            state: /CombatantDetailViewState.NextScreen.creatureEditView,
                            action: /CombatantDetailViewAction.NextScreenAction.creatureEditView,
                            isActive: { _ in true },
                            initialState: {
                                guard let def = self.combatant.definition as? AdHocCombatantDefinition else { return CreatureEditViewState(create: .monster) }
                                return CreatureEditViewState(edit: def)
                            },
                            destination: CreatureEditView.init)
                        {
                            Text("Edit combatant")
                        }
                    }
                }
            }
        }
        .actionSheet(self.store.scope(state: { $0.actionSheet }), dismiss: .actionSheet(nil))
        .popover(self.popover)
    }

    func contentView(for combatant: Combatant) -> some View {
        combatant.definition.stats.map { stats in
            StatBlockView(stats: stats, onTap: { target in
                switch target {
                case .ability(let a):
                    let modifier: Int = stats.abilityScores?.score(for: a).modifier.modifier ?? 0
                    self.viewStore.send(.popover(.rollCheck(.dice(.rollingExpression(1.d(20)+modifier, rollOnAppear: true)))))
                case .action(let a, let p):
                    if let action = DiceAction(title: a.name, parsedAction: p, env: env) {
                        self.viewStore.send(.popover(.diceAction(DiceActionViewState(action: action))))
                    }
                }
            })
        }
    }

    func latestEvents(_ running: RunningEncounter) -> some View {
        let log = running.log.filter { $0.involves(self.viewStore.state.combatant) }.reversed()
        return Group {
            if !log.isEmpty {
                SectionContainer(title: "Latest", accessory: StateDrivenNavigationLink(
                    store: store,
                    state: /CombatantDetailViewState.NextScreen.runningEncounterLogView,
                    action: /CombatantDetailViewAction.NextScreenAction.runningEncounterLogView,
                    isActive: { _ in true },
                    initialState: {
                        RunningEncounterLogViewState(encounter: running, context: self.viewStore.state.combatant)
                    },
                    destination: RunningEncounterLogView.init
                ) {
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
                } onOtherAction: {
                    let sheet = HealthDialog.otherActionSheet(combatant: viewStore.state.combatant, value: $0).pullback {
                        CombatantDetailViewAction.combatant($0)
                    }
                    viewStore.send(.actionSheet(sheet))
                    viewStore.send(.popover(nil))
                }.eraseToAnyView
            case .initiative(let combatant):
                return NumberEntryPopover.initiative(environment: self.env, combatant: combatant) { p in
                    self.viewStore.send(.combatant(.initiative(p)))
                    self.viewStore.send(.popover(nil))
                }.eraseToAnyView
            case .rollCheck:
                return IfLetStore(store.scope(state: { $0.rollCheckDialogState }, action: { .rollCheckDialog($0) })) { store in
                    NumberEntryPopover(store: store) { _ in
                        self.viewStore.send(.popover(nil))
                    }
                }.eraseToAnyView
            case .diceAction:
                return IfLetStore(store.scope(state: { $0.diceActionPopoverState }, action: { .diceActionPopover($0) })) { store in
                    DiceActionView(store: store)
                }.eraseToAnyView
            case .tagDetails(let tag):
                return CombatantTagPopover(running: self.viewStore.state.runningEncounter, combatant: self.combatant, tag: tag, onEditTap: {
                    self.viewStore.send(.popover(nil))
                    self.viewStore.send(.setNextScreen(.combatantTagEditView(CombatantTagEditViewState(mode: .edit, tag: tag, effectContext: self.viewStore.state.runningEncounter.map { EffectContext(source: nil, targets: [self.combatant], running: $0) }))))
                }).eraseToAnyView
            case .addLimitedResource:
                return IfLetStore(self.store.scope(state: {
                    guard case .addLimitedResource(let s)? = $0.popover else { return nil }
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
