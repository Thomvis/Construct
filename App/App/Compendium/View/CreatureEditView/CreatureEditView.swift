//
//  CreatureEditView.swift
//  Construct
//
//  Created by Thomas Visser on 21/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels
import DiceRollerFeature
import SharedViews
import Helpers

struct CreatureEditView: View {
    static let iconColumnWidth: CGFloat = 30

    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var store: Store<CreatureEditViewState, CreatureEditViewAction>
    @ObservedObject var viewStore: ViewStore<CreatureEditViewState, CreatureEditViewAction>

    init(store: Store<CreatureEditViewState, CreatureEditViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication })
    }

    var model: Binding<CreatureEditFormModel> {
        viewStore.binding(get: { $0.model }, send: { .model($0) })
    }

    var body: some View {
        return Form {
            FormSection(.basicCharacter) {
                ClearableTextField("Name", text: model.statBlock.name)
                    .disableAutocorrection(true)
                characterFields
            }

            FormSection(.basicMonster) {
                ClearableTextField("Name", text: model.statBlock.name)
                    .disableAutocorrection(true)
                    .disabled(!viewStore.state.canEditName)
                    .foregroundColor(viewStore.state.canEditName ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
                monsterFields
            }

            FormSection(.basicStats, footer:Group {
                Button(action: {
                    self.model.wrappedValue.statBlock.addMovementMode()
                }) {
                    Image(systemName: "plus.circle").font(Font.footnote.bold())
                    Text("Add movement mode").bold()
                }.disabled(!model.wrappedValue.statBlock.canAddMovementMode())
            }) {
                HStack {
                    Image(systemName: "shield").frame(width: Self.iconColumnWidth)
                    ClearableTextField("Armor class (Optional)", text: model.statBlock.ac)
                    .keyboardType(.numberPad)
                }
                HStack {
                    Image(systemName: "heart").frame(width: Self.iconColumnWidth)
                    ClearableTextField("Hit Points (Optional)", text: model.statBlock.hp)
                        .keyboardType(.numberPad)
                    Button(action: {
                        self.viewStore.send(.popover(.numberEntry(NumberEntryViewState.dice(.editingExpression()))))
                    }) {
                        Text("Roll")
                    }
                }
                ForEach(Array(model.wrappedValue.statBlock.movementModes.enumerated()), id: \.0) { (idx, mode) in
                    HStack(spacing: 8) {
                        if mode == self.model.wrappedValue.statBlock.movementModes.first {
                            Image(systemName: "hare").frame(width: Self.iconColumnWidth)
                        } else {
                            Spacer().frame(width: Self.iconColumnWidth)
                        }

                        Menu(mode.localizedDisplayName) {
                            Picker(
                                selection: viewStore.binding(get: { _ in mode }, send: {
                                    var model = viewStore.model
                                    model.statBlock.change(mode: mode, to: $0)
                                    return .model(model)
                                }),
                                label: EmptyView()
                            ) {
                                ForEach(MovementMode.allCases, id: \.hashValue) { option in
                                    Text("\(option.rawValue)").tag(option)
                                }
                            }
                        }

                        TextField("speed in ft. (Optional)", text: Binding(get: {
                                self.model.wrappedValue.statBlock.speed(for: mode)
                            }, set: {
                                self.model.wrappedValue.statBlock.setSpeed($0, for: mode)
                            })
                        )
                        .keyboardType(.numberPad)
                        .offset(x: 0, y: 1)
                    }
                    .deleteDisabled(self.model.wrappedValue.statBlock.movementModes.count == 1)
                }
                .onDelete { indices in
                    self.model.wrappedValue.statBlock.movementModes.remove(atOffsets: indices)
                }
            }

            FormSection(.abilities) {
                ForEach(Ability.allCases, id: \.self) { ability in
                    Stepper(value: Binding(get: {
                        self.model.statBlock.abilities.wrappedValue.score(for: ability).score
                    }, set: {
                        self.model.statBlock.abilities.wrappedValue.set(ability, to: $0)
                    }), in: 1...20) {
                        Text("\(ability.localizedDisplayName): ")
                            + Text("\(self.model.statBlock.abilities.wrappedValue.score(for: ability).score)")
                            + Text(" (\(modifierFormatter.stringWithFallback(for: self.model.statBlock.abilities.wrappedValue.score(for: ability).modifier.modifier)))").bold()

                    }
                }
            }

            skillsAndSavesSection

            FormSection(.initiative) {
                Stepper(value: model.statBlock.initiative.modifier.modifier, in: -10...10) {
                    Text("Initiative: ")
                        + Text(modifierFormatter.stringWithFallback(for: model.wrappedValue.statBlock.initiative.modifier.modifier)).bold()
                }
            }

            allNamedContentItemSections

            FormSection(.player) {
                Toggle(isOn: model.isPlayer.animation()) {
                    Text("Controlled by player").bold()
                }
                if model.wrappedValue.isPlayer {
                    ClearableTextField("Player name (Optional)", text: model.playerName).textContentType(.name)
                }
            }

            if viewStore.state.mode.isEdit {
                Section {
                    Button(action: {
                        self.viewStore.send(.onRemoveTap(self.viewStore.state))
                    }) {
                        Text("Remove \(viewStore.state.creatureType.localizedDisplayName)")
                            .foregroundColor(Color(UIColor.systemRed))
                    }
                }
            }
        }
        .popover(popoverBinding)
        .sheet(item: viewStore.binding(get: { $0.sheet }, send: { .sheet($0) })) { item in
            IfLetStore(store.scope(state: replayNonNil({ $0.sheet }))) { store in
                SwitchStore(store) {
                    CaseLet(state: /CreatureEditViewState.Sheet.actionEditor, action: CreatureEditViewAction.creatureActionEditSheet) { store in
                        AutoSizingSheetContainer {
                            SheetNavigationContainer {
                                NamedStatBlockContentItemEditView(store: store)
                                    .navigationTitle(ViewStore(store).state.title)
                                    .navigationBarTitleDisplayMode(.inline)
                            }
                        }
                    }
                }
            }
        }
        .background(Group {
            if viewStore.state.mode.isEdit {
                EmptyView()
                    .navigationBarItems(
                        leading: Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                        },
                        trailing: Button(action: {
                            self.viewStore.send(.onDoneTap(self.viewStore.state))
                        }) {
                            Text("Done").bold()
                        }
                        .disabled(!self.viewStore.state.isValid)
                    )
                    .navigationBarBackButtonHidden(true)
            } else {
                EmptyView()
                    .navigationBarItems(
                        leading: Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                        },
                        trailing: Button(action: {
                            self.viewStore.send(.onAddTap(self.viewStore.state))
                        }) {
                            Text("Add").bold()
                        }
                        .disabled(!self.viewStore.state.isValid)
                    )
            }
        })
        .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
    }

    var characterFields: some View {
        Group {
            OptionalSelectField(
                \.size,
                 fieldLabel: "Size",
                 valueLabel: \.localizedDisplayName.capitalized
            )

            Stepper("Level: \(model.wrappedValue.levelOrNilAsZeroString)", value: model.levelOrNilAsZero, in: 0...20)
        }
    }

    var monsterFields: some View {
        Group {
            OptionalSelectField(
                \.size,
                 fieldLabel: "Size",
                 valueLabel: \.localizedDisplayName.capitalized
            )

            OptionalSelectField(
                \.type,
                 fieldLabel: "Type",
                 valueLabel: \.localizedDisplayName.capitalized
            )

            LabeledContent {
                Menu {
                    Picker(
                        selection: viewStore.binding(get: { $0.model.challengeRating }, send: {
                            var model = viewStore.model
                            model.challengeRating = $0
                            return .model(model)
                        }),
                        label: EmptyView()
                    ) {
                        ForEach(Array(crToXpMapping.keys).sorted(), id: \.hashValue) { option in
                            Text("\(option.rawValue)").tag(Optional.some(option))
                        }
                    }
                } label: {
                    model.wrappedValue.challengeRating.map { cr in
                        Group {
                            Text("\(cr.rawValue)")

                            crToXpMapping[cr].map { xp in
                                Text("(\(xp) XP)")
                            }
                        }
                    }.replaceNilWith {
                        Text("Select")
                    }
                    .foregroundColor(Color(UIColor.secondaryLabel))

                    Image(systemName: "chevron.down.square.fill")
                        .foregroundColor(Color.secondary)
                }
            } label: {
                Text("Challenge rating")
            }
        }
    }

    @ViewBuilder
    var skillsAndSavesSection: some View {
        // Mockup
        FormSection(.skillsAndSaves, footer: Group {
            Text("The proficiency bonus for a \(viewStore.state.model.statBlock.difficultyDescription) \(viewStore.state.creatureType.localizedDisplayName) is \(viewStore.state.model.statBlock.proficiencyBonusModifier).")
        }) {
            ProficiencyMultiPicker(
                fieldName: "Skill proficiencies",
                allValues: Skill.allCases,
                proficiencies: viewStore.state.model.statBlock.skillProficiencies,
                statLabel: \.localizedDisplayName,
                setProficiency: { $0.setProficiency($1, for: $2) },
                removeProficiency: { $0.removeProficiency(for: $1) },
                removeAllProficiencies: { $0.removeAllSkillProficiencies() }
            )

            ProficiencyMultiPicker(
                fieldName: "Saving throw proficiencies",
                allValues: Ability.allCases,
                proficiencies: viewStore.state.model.statBlock.savingThrowProficiencies,
                statLabel: \.localizedAbbreviation.localizedUppercase,
                setProficiency: { $0.setProficiency($1, for: $2) },
                removeProficiency: { $0.removeProficiency(for: $1) },
                removeAllProficiencies: { $0.removeAllSavingThrowProficiencies() }
            )
        }
    }

    @ViewBuilder
    var allNamedContentItemSections: some View {
        ForEach(CreatureEditViewState.Section.allNamedContentItemCases) { section in
            if case .namedContentItems(let t) = section {
                FormSection(section, footer: HStack {
                    Button(action: {
                        viewStore.send(.sheet(.actionEditor(NamedStatBlockContentItemEditViewState(newItemOfType: t))))
                    }) {
                        Image(systemName: "plus.circle").font(Font.footnote.bold())
                        Text("Add \(t.localizedDisplayName)").bold()
                    }

                    Spacer()

                    EditButton()
                }) {
                    ForEach(model.wrappedValue.statBlock[itemsOfType: t], id: \.id) { item in
                        NavigationRowButton {
                            viewStore.send(.onNamedContentItemTap(t, item.id))
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.attributedName)
                                Text(item.attributedDescription)
                                    .font(.footnote)
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(1)
                            }
                            .padding([.top, .bottom], 1)
                        }
                    }
                    .onDelete { indices in
                        viewStore.send(.onNamedContentItemRemove(t, indices))
                    }
                    .onMove { indices, offset in
                        viewStore.send(.onNamedContentItemMove(t, indices, offset))
                    }

                    if model.wrappedValue.statBlock[itemsOfType: t].isEmpty {
                        Text("No items").italic()
                    }
                }
            }
        }
    }

    var popoverBinding: Binding<AnyView?> {
        Binding(get: {
            switch self.viewStore.state.popover {
            case .numberEntry:
                return IfLetStore(store.scope(state: { $0.numberEntryPopover }, action: { .numberEntryPopover($0) })) { store in
                    NumberEntryPopover(store: store) {
                        self.model.statBlock.hp.wrappedValue = "\($0)"
                        self.viewStore.send(.popover(nil))
                    }
                }.eraseToAnyView
            case nil:
                return nil
            }
        }, set: { _ in
            self.viewStore.send(.popover(nil))
        })
    }
}

extension CreatureEditView {
    fileprivate func FormSection<Content>(_ section: CreatureEditViewState.Section, @ViewBuilder content: @escaping () -> Content) -> some View where Content: View {
        FormSection(section, footer: EmptyView(), content: content)
    }

    @ViewBuilder
    fileprivate func FormSection<Footer, Content>(_ section: CreatureEditViewState.Section, footer: Footer, @ViewBuilder content: @escaping () -> Content) -> some View where Footer: View, Content: View {
        if viewStore.state.addableSections.contains(section) || viewStore.state.sections.contains(section) {
            Section(footer: Group {
                if viewStore.state.sections.contains(section) {
                    footer
                }
            }) {
                if !viewStore.state.creatureType.requiredSections.contains(section) {
                    Toggle(isOn: Binding(get: {
                        viewStore.state.sections.contains(section)
                    }, set: { b in
                        self.viewStore.send(b ? .addSection(section) : .removeSection(section), animation: .default)
                    })) {
                        Text(section.localizedHeader ?? "").bold()
                    }
                }

                if viewStore.state.sections.contains(section) {
                    content()
                }
            }
        }
    }

    fileprivate func OptionalSelectField<M: Hashable>(
        _ path: WritableKeyPath<StatBlockFormModel, M?>,
        fieldLabel: String,
        valueLabel: @escaping (M) -> String
    ) -> some View where M: CaseIterable, M.AllCases: RandomAccessCollection, M: RawRepresentable, M.RawValue: Hashable {
        LabeledContent {
            Menu {
                Picker(
                    selection: viewStore.binding(get: { $0.model.statBlock[keyPath: path] }, send: {
                        var model = viewStore.model
                        model.statBlock[keyPath: path] = $0
                        return .model(model)
                    }),
                    label: EmptyView()
                ) {
                    Text("None").tag(Optional<M>.none)
                    Divider()
                    ForEach(M.allCases, id: \.rawValue) { value in
                        Text(valueLabel(value)).tag(Optional.some(value))
                    }
                }
            } label: {
                let string = viewStore.state.model.statBlock[keyPath: path].map(valueLabel) ?? "Select (Optional)"
                Text(string)
                    .foregroundColor(Color.secondary)

                Image(systemName: "chevron.down.square.fill")
                    .foregroundColor(Color.secondary)
            }
        } label: {
            Text(fieldLabel)
        }
    }

    @ViewBuilder
    fileprivate func ProficiencyMultiPicker<Stat>(
        fieldName: String,
        allValues: [Stat],
        proficiencies: [StatBlockFormModel.Proficiency<Stat>],
        statLabel: KeyPath<Stat, String>,
        setProficiency: @escaping (inout StatBlockFormModel, StatBlock.Proficiency, Stat) -> Void,
        removeProficiency: @escaping (inout StatBlockFormModel, Stat) -> Void,
        removeAllProficiencies: @escaping (inout StatBlockFormModel) -> Void
    ) -> some View where Stat: RawRepresentable, Stat.RawValue: Hashable {
        VStack(alignment: .leading) {

            HStack {
                Menu {
                    if !proficiencies.isEmpty {
                        Button(role: .destructive) {
                            var model = viewStore.model
                            removeAllProficiencies(&model.statBlock)
                            viewStore.send(.model(model))
                        } label: {
                            Label("Remove all", systemImage: "clear")
                        }

                        Divider()
                    }

                    ForEach(allValues, id: \.rawValue) { stat in
                        let proficiency = proficiencies.first(where: { $0.stat == stat })
                        Button {
                            var model = viewStore.model
                            if proficiency != nil {
                                removeProficiency(&model.statBlock, stat)
                            } else {
                                setProficiency(&model.statBlock, .times(1), stat)
                            }
                            viewStore.send(.model(model))
                        } label: {
                            let image = proficiency?.proficiency.systemImageName(filled: true)
                                            ?? StatBlock.Proficiency.times(1).systemImageName(filled: false)

                            Label(
                                stat[keyPath: statLabel],
                                systemImage: image
                            )
                        }
                    }
                } label: {
                    Text(fieldName)
                        .foregroundColor(proficiencies.isEmpty ? Color.secondary : Color.primary)
                        .bold(!proficiencies.isEmpty)
                        .font(proficiencies.isEmpty ? .body : .footnote)

                    Spacer()

                    Image(systemName: "chevron.down.square.fill")
                        .foregroundColor(Color.secondary)
                }
            }

            if !proficiencies.isEmpty {
                FlowLayout {
                    ForEach(proficiencies, id: \.stat) { proficiency in
                        Menu {
                            let times = (/StatBlock.Proficiency.times).extract(from: proficiency.proficiency)
                            Button {
                                var model = viewStore.model
                                setProficiency(&model.statBlock, .times(1), proficiency.stat)
                                viewStore.send(.model(model))
                            } label: {
                                Label(
                                    "Single proficiency",
                                    systemImage: StatBlock.Proficiency.times(1).systemImageName(filled: times == 1)
                                )
                            }

                            Button {
                                var model = viewStore.model
                                setProficiency(&model.statBlock, .times(2), proficiency.stat)
                                viewStore.send(.model(model))
                            } label: {
                                Label(
                                    "Double proficiency",
                                    systemImage: StatBlock.Proficiency.times(2).systemImageName(filled: times == 2)
                                )
                            }

                            Menu {
                                ForEach(0...20) { i in
                                    Button(modifierFormatter.stringWithFallback(for: i)) {
                                        var model = viewStore.model
                                        setProficiency(&model.statBlock, .custom(Modifier(modifier: i)), proficiency.stat)
                                        viewStore.send(.model(model))
                                    }
                                }
                            } label: {
                                Label(
                                    "Custom…",
                                    systemImage: StatBlock.Proficiency.custom(0).systemImageName(filled: proficiency.proficiency.isCustom)
                                )
                            }

                            Divider()

                            Button(role: .destructive) {
                                var model = viewStore.model
                                removeProficiency(&model.statBlock, proficiency.stat)
                                viewStore.send(.model(model))
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: proficiency.proficiency.systemImageName(filled: true))
                                    .foregroundColor(Color.primary.opacity(0.2))

                                Text(proficiency.stat[keyPath: statLabel])

                                Text(modifierFormatter.stringWithFallback(for: proficiency.modifier.modifier))
                                    .padding(.leading, 4)
                                    .background(Color.primary.opacity(0.05).padding([.top, .trailing, .bottom], -10))
                            }
                            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)
                            .foregroundColor(Color.primary)
                            .font(.callout)
                        }
                    }
                }
                .padding(.trailing, -10) // make layout a bit tighter, increase chance of showing multiple items on a line
            }
        }
    }
}

extension NamedStatBlockContentItemEditViewState {
    var title: String {
        let verb: String
        switch intent {
        case .edit: verb = "Edit"
        case .new: verb = "New"
        }

        return "\(verb) \(itemType.localizedDisplayName)"
    }
}

extension StatBlock.Proficiency {
    func systemImageName(filled: Bool) -> String {
        let baseName: String
        switch self {
        case .times(1): baseName = "circlebadge"
        case .times(2): baseName = "circlebadge.2"
        default: baseName = "rhombus"
        }

        return filled ? baseName + ".fill" : baseName
    }
}

#if DEBUG
struct CreatureEditView_Preview: PreviewProvider {
    static var previews: some View {
        CreatureEditView(
            store: Store(
                initialState: CreatureEditViewState(edit: Monster(
                    realm: .homebrew,
                    stats: StatBlock(
                        name: "Goblin",
                        armor: [],
                        savingThrows: [:],
                        skills: [:],
                        features: [],
                        actions: [
                            CreatureAction(name: "Scimitar", description: "Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage."),
                            CreatureAction(name: "Shortbow", description: "Ranged Weapon Attack: +4 to hit, range 80/320 ft., one target. Hit: 5 (1d6 + 2) piercing damage.")
                        ],
                        reactions: []
                    ),
                    challengeRating: Fraction(integer: 1)
                )),
                reducer: CreatureEditViewState.reducer,
                environment: CEVE(
                    modifierFormatter: modifierFormatter,
                    mainQueue: DispatchQueue.immediate.eraseToAnyScheduler(),
                    diceLog: DiceLogPublisher()
                )
            )
        )
    }
}

struct CEVE: CreatureEditViewEnvironment {
    var modifierFormatter: NumberFormatter
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var diceLog: DiceLogPublisher
}
#endif
