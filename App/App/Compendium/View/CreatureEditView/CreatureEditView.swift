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
import Compendium
import MechMuse
import Persistence

struct CreatureEditView: View {
    static let iconColumnWidth: CGFloat = 30

    @EnvironmentObject var modifierFormatter: ModifierFormatter
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Bindable var store: StoreOf<CreatureEditFeature>

    @ScaledMetric(relativeTo: .body)
    var bodyMetric: CGFloat = 14

    var model: Binding<CreatureEditFormModel> {
        $store.model.sending(\.model)
    }

    @ViewBuilder
    var noticeBanner: some View {
        if let notice = store.notice {
            NoticeView(
                notice: notice,
                backgroundColor: Color(UIColor.systemBackground),
                onDismiss: {
                    store.send(.dismissNotice, animation: .default)
                }
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }

    var body: some View {
        return Form {
            noticeBanner
            FormSection(.basicCharacter) {
                HStack {
                    ClearableTextField("Name", text: model.statBlock.name)
                        .disableAutocorrection(true)

                    creatureTypeAccessoryControl
                }
                characterFields

                if store.mode != .create(.adHocCombatant) {
                    compendiumDocumentField
                }
            }

            FormSection(.basicMonster) {
                HStack {
                    ClearableTextField("Name", text: model.statBlock.name)
                        .disableAutocorrection(true)
                        .disabled(!store.canEditName)
                        .foregroundColor(store.canEditName ? Color(UIColor.label) : Color(UIColor.secondaryLabel))

                    creatureTypeAccessoryControl
                }
                monsterFields

                if store.mode != .create(.adHocCombatant) {
                    compendiumDocumentField
                }
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
                        self.store.send(.popover(.numberEntry(NumberEntryFeature.State.dice(.editingExpression()))))
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
                                selection: Binding(
                                    get: { mode },
                                    set: { newMode in
                                        var model = store.model
                                        model.statBlock.change(mode: mode, to: newMode)
                                        store.send(.model(model))
                                    }
                                ),
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
                    }), in: 1...store.maximumAbilityScore) {
                        Text("\(ability.localizedDisplayName): ")
                            + Text("\(self.model.statBlock.abilities.wrappedValue.score(for: ability).score)")
                            + Text(" (\(modifierFormatter.string(from: self.model.statBlock.abilities.wrappedValue.score(for: ability).modifier.modifier)))").bold()

                    }
                }
            }

            skillsAndSavesSection

            FormSection(.initiative) {
                Stepper(value: model.statBlock.initiative.modifier.modifier, in: -10...10) {
                    Text("Initiative: ")
                        + Text(modifierFormatter.string(from: model.wrappedValue.statBlock.initiative.modifier.modifier)).bold()
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

            if store.mode.isEdit {
                Section {
                    Button(action: {
                        self.store.send(.onRemoveTap(self.store.state))
                    }) {
                        Text("Remove \(store.creatureType.localizedDisplayName)")
                            .foregroundColor(Color(UIColor.systemRed))
                    }
                }
            }
        }
        .popover(popoverBinding)
        .background(Group {
            if store.mode.isEdit {
                EmptyView()
                    .navigationBarItems(
                        leading: Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                        },
                        trailing: Button(action: {
                            self.store.send(.onDoneTap(self.store.state))
                        }) {
                            Text("Done").bold()
                        }
                        .disabled(!self.store.isValid)
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
                            self.store.send(.onAddTap(self.store.state), animation: .default)
                        }) {
                            Text("Add").bold()
                        }
                        .disabled(!self.store.isValid)
                    )
            }
        })
        .navigationBarTitle(Text(store.navigationTitle), displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    store.send(.onCreatureGenerationButtonTap)
                }) {
                    Image(systemName: "quote.bubble")
                }
            }
        }
        .modifier(Sheets(store: store))
    }

    struct Sheets: ViewModifier {
        @Bindable var store: StoreOf<CreatureEditFeature>

        func body(content: Content) -> some View {
            content
                .sheet(item: $store.scope(state: \.sheet, action: \.sheet)) { store in
                    switch store.case {
                    case .actionEditor(let store):
                        AutoSizingSheetContainer {
                            SheetNavigationContainer {
                                NamedStatBlockContentItemEditView(store: store)
                                    .navigationTitle(store.title)
                                    .navigationBarTitleDisplayMode(.inline)
                            }
                        }
                    case .creatureGeneration(let store):
                        SheetNavigationContainer {
                            MechMuseCreatureGenerationSheet(store: store)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    var creatureTypeAccessoryControl: some View {
        let editableCreatureType = !store.mode.isEdit

        Menu {
            if editableCreatureType {
                Picker(
                    selection: $store.creatureType.sending(\.setCreateModeCreatureType),
                    label: EmptyView()
                ) {
                    ForEach(CreatureEditFeature.State.CreatureType.allCases, id: \.rawValue) { type in
                        Text(type.localizedDisplayName).tag(type)
                    }
                }
            } else {
                Text("Type cannot be edited.")
                Text("Choose \"Edit a Copy\" instead.")
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(store.creatureType.localizedDisplayName)

                if editableCreatureType {
                    Image(systemName: "chevron.down")
                        .font(.footnote)
                }
            }
            .padding([.leading, .trailing], 12)
            .padding([.top, .bottom], 2)
            .foregroundStyle(Color.secondary)
            .background(Color(UIColor.systemGray5).cornerRadius(100))
            .padding(.trailing, -12)
        }
    }

    @ViewBuilder
    var compendiumDocumentField: some View {
        let documentSelectionStore = store.scope(state: \.model.document, action: \.documentSelection)
        LabeledContent {
            if !store.mode.isEdit {
                CompendiumDocumentSelectionView.menu(
                    store: documentSelectionStore,
                    label: { name in
                        HStack {
                            Text(name)
                                .foregroundColor(Color.secondary)

                            Image(systemName: "chevron.down.square.fill")
                                .foregroundColor(Color.secondary)
                        }
                    }
                )
            } else {
                CompendiumDocumentSelectionView.withStore(store: documentSelectionStore) { store in
                    Text(store.currentDocument?.displayName ?? "")
                }
            }
        } label: {
            Text("Document")
        }
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
                        selection: Binding(
                            get: { store.model.statBlock.challengeRating },
                            set: { newValue in
                                var model = store.model
                                model.statBlock.challengeRating = newValue
                                store.send(.model(model))
                            }
                        ),
                        label: EmptyView()
                    ) {
                        ForEach(Array(crToXpMapping.keys).sorted(), id: \.hashValue) { option in
                            Text("\(option.rawValue)").tag(Optional.some(option))
                        }
                    }
                } label: {
                    model.wrappedValue.statBlock.challengeRating.map { cr in
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
            Text("The proficiency bonus for a \(store.model.statBlock.difficultyDescription) \(store.creatureType.localizedDisplayName) is \(store.model.statBlock.proficiencyBonusModifier).")
        }) {
            ProficiencyMultiPicker(
                fieldName: "Skill proficiencies",
                allValues: Skill.allCases,
                proficiencies: store.model.statBlock.skillProficiencies,
                statLabel: \.localizedDisplayName,
                setProficiency: { $0.setProficiency($1, for: $2) },
                removeProficiency: { $0.removeProficiency(for: $1) },
                removeAllProficiencies: { $0.removeAllSkillProficiencies() }
            )

            ProficiencyMultiPicker(
                fieldName: "Saving throw proficiencies",
                allValues: Ability.allCases,
                proficiencies: store.model.statBlock.savingThrowProficiencies,
                statLabel: \.localizedAbbreviation.localizedUppercase,
                setProficiency: { $0.setProficiency($1, for: $2) },
                removeProficiency: { $0.removeProficiency(for: $1) },
                removeAllProficiencies: { $0.removeAllSavingThrowProficiencies() }
            )
        }
    }

    @ViewBuilder
    var allNamedContentItemSections: some View {
        ForEach(CreatureEditFeature.State.Section.allNamedContentItemCases) { section in
            if case .namedContentItems(let t) = section {
                FormSection(section, footer: HStack {
                    Button(action: {
                        store.send(.setSheet(.actionEditor(NamedStatBlockContentItemEditFeature.State(newItemOfType: t))))
                    }) {
                        Image(systemName: "plus.circle").font(Font.footnote.bold())
                        Text("Add \(t.localizedDisplayName)").bold()
                    }

                    Spacer()

                    EditButton()
                }) {
                    ForEach(model.wrappedValue.statBlock[itemsOfType: t], id: \.id) { item in
                        NavigationRowButton {
                            store.send(.onNamedContentItemTap(t, item.id))
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
                        store.send(.onNamedContentItemRemove(t, indices))
                    }
                    .onMove { indices, offset in
                        store.send(.onNamedContentItemMove(t, indices, offset))
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
            switch self.store.popover {
            case .numberEntry:
                if let popoverStore = store.scope(state: \.numberEntryPopover, action: \.numberEntryPopover) {
                    return NumberEntryPopover(store: popoverStore) {
                        self.model.statBlock.hp.wrappedValue = "\($0)"
                        self.store.send(.popover(nil))
                    }.eraseToAnyView
                }
                return nil
            case nil:
                return nil
            }
        }, set: { _ in
            self.store.send(.popover(nil))
        })
    }
}

extension CreatureEditView {
    fileprivate func FormSection<Content>(_ section: CreatureEditFeature.State.Section, @ViewBuilder content: @escaping () -> Content) -> some View where Content: View {
        FormSection(section, footer: EmptyView(), content: content)
    }

    @ViewBuilder
    fileprivate func FormSection<Footer, Content>(_ section: CreatureEditFeature.State.Section, footer: Footer, @ViewBuilder content: @escaping () -> Content) -> some View where Footer: View, Content: View {
        if store.addableSections.contains(section) || store.sections.contains(section) {
            Section(footer: Group {
                if store.sections.contains(section) {
                    footer
                }
            }) {
                if !store.creatureType.requiredSections.contains(section) {
                    Toggle(isOn: Binding(get: {
                        store.sections.contains(section)
                    }, set: { b in
                        self.store.send(b ? .addSection(section) : .removeSection(section), animation: .default)
                    })) {
                        Text(section.localizedHeader ?? "").bold()
                    }
                }

                if store.sections.contains(section) {
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
                    selection: Binding(
                        get: { store.model.statBlock[keyPath: path] },
                        set: { newValue in
                            var model = store.model
                            model.statBlock[keyPath: path] = newValue
                            store.send(.model(model))
                        }
                    ),
                    label: EmptyView()
                ) {
                    Text("None").tag(Optional<M>.none)
                    Divider()
                    ForEach(M.allCases, id: \.rawValue) { value in
                        Text(valueLabel(value)).tag(Optional.some(value))
                    }
                }
            } label: {
                let string = store.model.statBlock[keyPath: path].map(valueLabel) ?? "Select (Optional)"
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
        VStack(alignment: .leading, spacing: 0) {
            let overlap = 2*bodyMetric
            HStack {
                Menu {
                    if !proficiencies.isEmpty {
                        Button(role: .destructive) {
                            var model = store.model
                            removeAllProficiencies(&model.statBlock)
                            store.send(.model(model))
                        } label: {
                            Label("Remove all", systemImage: "clear")
                        }

                        Divider()
                    }

                    ForEach(allValues, id: \.rawValue) { stat in
                        let proficiency = proficiencies.first(where: { $0.stat == stat })
                        Button {
                            var model = store.model
                            if proficiency != nil {
                                removeProficiency(&model.statBlock, stat)
                            } else {
                                setProficiency(&model.statBlock, .times(1), stat)
                            }
                            store.send(.model(model))
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
                    HStack {
                        Text(fieldName)
                            .foregroundColor(proficiencies.isEmpty ? Color.secondary : Color.primary)
                            .bold(!proficiencies.isEmpty)
                            .font(proficiencies.isEmpty ? .body : .footnote)

                        Spacer()

                        Image(systemName: "chevron.down.square.fill")
                            .foregroundColor(Color.secondary)
                    }
                    .padding(.bottom, proficiencies.isEmpty ? 0 : 8 + overlap)
                }
            }

            if !proficiencies.isEmpty {
                FlowLayout {
                    ForEach(proficiencies, id: \.stat) { proficiency in
                        Menu {
                            let times = proficiency.proficiency[case: \.times]
                            Button {
                                var model = store.model
                                setProficiency(&model.statBlock, .times(1), proficiency.stat)
                                store.send(.model(model))
                            } label: {
                                Label(
                                    "Single proficiency",
                                    systemImage: StatBlock.Proficiency.times(1).systemImageName(filled: times == 1)
                                )
                            }

                            Button {
                                var model = store.model
                                setProficiency(&model.statBlock, .times(2), proficiency.stat)
                                store.send(.model(model))
                            } label: {
                                Label(
                                    "Double proficiency",
                                    systemImage: StatBlock.Proficiency.times(2).systemImageName(filled: times == 2)
                                )
                            }

                            Menu {
                                ForEach(0...store.maximumAbilityScore, id: \.self) { i in
                                    Button(modifierFormatter.string(from: i)) {
                                        var model = store.model
                                        setProficiency(&model.statBlock, .custom(Modifier(modifier: i)), proficiency.stat)
                                        store.send(.model(model))
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
                                var model = store.model
                                removeProficiency(&model.statBlock, proficiency.stat)
                                store.send(.model(model))
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: proficiency.proficiency.systemImageName(filled: true))
                                    .foregroundColor(Color.primary.opacity(0.2))

                                Text(proficiency.stat[keyPath: statLabel])

                                Text(modifierFormatter.string(from: proficiency.modifier.modifier))
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
                .padding(.top, -overlap)
            }
        }
    }
}

extension NamedStatBlockContentItemEditFeature.State {
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
        // edit
        NavigationView {
            CreatureEditView(
                store: Store(
                    initialState: CreatureEditFeature.State(edit: Monster(
                        realm: .init(CompendiumRealm.homebrew.id),
                        stats: StatBlock(
                            name: "Goblin",
                            armor: [],
                            savingThrows: [:],
                            skills: [:],
                            features: [],
                            actions: [
                                CreatureAction(id: UUID(), name: "Scimitar", description: "Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage."),
                                CreatureAction(id: UUID(), name: "Shortbow", description: "Ranged Weapon Attack: +4 to hit, range 80/320 ft., one target. Hit: 5 (1d6 + 2) piercing damage.")
                            ],
                            reactions: []
                        ),
                        challengeRating: Fraction(integer: 1)
                    ), documentId: CompendiumSourceDocument.homebrew.id)
                ) {
                    CreatureEditFeature()
                } withDependencies: {
                    $0.mainQueue = DispatchQueue.immediate.eraseToAnyScheduler()
                    $0.diceLog = DiceLogPublisher()
                    $0.compendiumMetadata = CompendiumMetadataKey.previewValue
                    $0.database = Database.uninitialized
                    $0.compendium = DatabaseCompendium(databaseAccess: Database.uninitialized.access)
                }
            )
        }

        // create
        CreatureEditView(
            store: Store(
                initialState: CreatureEditFeature.State(
                    create: .monster,
                    sourceDocument: .init(CompendiumSourceDocument.homebrew)
                )
            ) {
                CreatureEditFeature()
            } withDependencies: {
                $0.mainQueue = DispatchQueue.immediate.eraseToAnyScheduler()
                $0.diceLog = DiceLogPublisher()
                $0.compendiumMetadata = CompendiumMetadataKey.previewValue
                $0.database = Database.uninitialized
                $0.compendium = DatabaseCompendium(databaseAccess: Database.uninitialized.access)
            }
        )
    }
}

#endif
