//
//  GenerateCombatantTraitsView.swift
//  Construct
//
//  Created by Thomas Visser on 03/01/2023.
//  Copyright © 2023 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels
import Helpers
import SharedViews
import OpenAI
import MechMuse

struct GenerateCombatantTraitsView: View {
    typealias State = GenerateCombatantTraitsFeature.State

    @Bindable var store: StoreOf<GenerateCombatantTraitsFeature>

    init(store: StoreOf<GenerateCombatantTraitsFeature>) {
        self.store = store
    }

    var body: some View {
        list
            .safeAreaInset(edge: .top) {
                topMessage
            }
            .safeAreaInset(edge: .bottom) {
                generateButton
            }
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.onDoneButtonTap)
                    } label: {
                        Text("Done").bold()
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .navigationTitle("Combatant Traits")
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var topMessage: some View {
        if let error = store.error {
            let bg = store.isMechMuseUnconfigured
                ? Color(UIColor.systemBlue).gradient
                : Color(UIColor.systemRed).gradient

            let image = store.isMechMuseUnconfigured
                ? Image("tabbar_d20")
                : Image(systemName: "exclamationmark.circle.fill")

            VStack(spacing: 12) {
                image.font(.title).symbolRenderingMode(.hierarchical)

                Text(error.attributedDescription)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(Color.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(in: RoundedRectangle(cornerSize: .init(width: 8, height: 8)))
            .backgroundStyle(bg)
            .padding()
            .padding(.bottom, -10)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.6).combined(with: .opacity).animation(.spring().delay(0.15)),
                removal: .scale(scale: 0.6).combined(with: .opacity)
            ))
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(store.combatants) { combatant in
                    row(combatant: combatant)
                }
            } header: {
                listHeader
            }
            .disabled(store.disableInteractions)

            VStack(spacing: 10) {
                Text("Powered by Mechanical Muse").bold()
                Text("For the best result, generate traits for all monsters at once.")
            }
        }
    }

    private var generateButton: some View {
        Button {
            store.send(.onGenerateTap, animation: .default)
        } label: {
            HStack(spacing: 0) {
                Spacer()

                if store.isLoading {
                    ProgressView()
                        .padding(.trailing, 10)
                        .controlSize(.regular)
                }
                Text("Generat")

                if store.isLoading {
                    Text("ing…")
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.default.delay(0.15)),
                            removal: .opacity
                        ))
                } else {
                    Text("e traits")
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.default.delay(0.15)),
                            removal: .opacity
                        ))
                }

                Spacer()
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(store.disableInteractions || store.state.selectedCombatants().isEmpty)
        .padding()
    }

    @ViewBuilder
    private var listHeader: some View {
        HStack {
            FlowLayout(spacing: 4) {
                Button("Monsters") {
                    store.send(.onSmartSelectionGroupTap(.monsters))
                }
                .tint(store.selection == .smart(.monsters) ? Color(UIColor.systemBlue) : nil)

                Button("Mobs") {
                    store.send(.onSmartSelectionGroupTap(.mobs))
                }
                .tint(store.selection == .smart(.mobs) ? Color(UIColor.systemBlue) : nil)
            }

            Spacer()

            Button {
                store.send(.onOverwriteButtonTap, animation: .default.speed(2))
            } label: {
                if store.overwriteEnabled {
                    Text("Overwrite on")
                } else {
                    Text("Overwrite off")
                }
            }
            .tint(Color(store.overwriteEnabled ? UIColor.systemRed : UIColor.systemGreen))
            .animation(nil, value: store.overwriteEnabled)

            if store.showRemoveAllTraits || store.showUndoAllChanges {
                Menu {
                    if store.showRemoveAllTraits {
                        Button {
                            store.send(.onRemoveAllTraitsTap, animation: .default)
                        } label: {
                            Label("Remove all traits", systemImage: "clear")
                        }
                    }

                    if store.showUndoAllChanges {
                        Button(role: .destructive) {
                            store.send(.onUndoAllChangesTap, animation: .default)
                        } label: {
                            Label("Undo all changes", systemImage: "arrow.uturn.backward.square")
                        }
                    }
                } label: {
                    Button { } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.accentColor)
                .font(.body)
                .padding(.trailing, 12)
            }
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
        .font(.footnote)
        .textCase(.none)
        .padding([.leading, .trailing], -12)
    }

    @ViewBuilder
    private func row(combatant: State.CombatantModel) -> some View {
        VStack(alignment: .leading) {
            let canSelect = store.state.canSelect(combatant: combatant)
            let isSelected = store.state.isSelected(combatant: combatant)

            let checkbox = Image(systemName: canSelect ? (isSelected ? "checkmark.circle.fill" : "circle") : "slash.circle")
                .symbolRenderingMode(.monochrome)
                .font(Font.title3)
                .foregroundColor((isSelected && !store.disableInteractions) ? Color(UIColor.systemBlue) : Color(UIColor.systemGray2))

            HStack {
                Button {
                    store.send(.onToggleCombatantSelection(combatant.id), animation: .default.speed(2))
                } label: {
                    HStack {
                        checkbox.opacity(store.state.canSelect(combatant: combatant) ? 1.0 : 0.33)
                        Combatant.discriminatedNameText(name: combatant.name, discriminator: combatant.discriminator)
                            .foregroundColor(Color.primary)

                        Spacer()
                    }
                }
                .disabled(!store.state.canSelect(combatant: combatant))

                if combatant.traits != nil || store.state.combatantHasChanges(combatant) {
                    Menu {
                        if combatant.traits != nil {
                            Button {
                                store.send(.onRemoveCombatantTraitsTap(combatant.id), animation: .default)
                            } label: {
                                Label("Remove traits", systemImage: "clear")
                            }

                            Button {
                                store.send(.onRegenerateCombatantTraitsTap(combatant.id), animation: .default)
                            } label: {
                                Label("Regenerate traits", systemImage: "arrow.clockwise")
                            }
                        }

                        if store.state.combatantHasChanges(combatant) {
                            Button {
                                store.send(.onUndoCombatantTraitsChangesTap(combatant.id), animation: .default)
                            } label: {
                                Label("Undo changes", systemImage: "arrow.uturn.backward.square")
                            }
                        }
                    } label: {
                        Button { } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }

            if let traits = combatant.traits {
                HStack {
                    checkbox.hidden() // for alignment

                    VStack(alignment: .leading, spacing: 2) {
                        if let physical = traits.physical {
                            StatBlockView.line(title: "Physical", text: physical).lineLimit(2)
                        }

                        if let personality = traits.personality {
                            StatBlockView.line(title: "Personality", text: personality).lineLimit(2)
                        }

                        if let nickname = traits.nickname {
                            StatBlockView.line(title: "Nickname", text: nickname).lineLimit(2)
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(Color.secondary)
                }
            }
        }
    }
}

#if DEBUG
struct GenerateCombatantTraitsView_Preview: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GenerateCombatantTraitsView(store: Store(
                initialState: .init(
                    encounter: Encounter(
                        name: "Test",
                        combatants: [
                            Combatant(monster: Monster(
                                realm: .init(CompendiumRealm.core.id),
                                stats: StatBlock(name: "Goblin"),
                                challengeRating: .half
                            )),
                            apply(Combatant(monster: Monster(
                                realm: .init(CompendiumRealm.core.id),
                                stats: StatBlock(name: "Goblin"),
                                challengeRating: .half
                            ))) {
                                $0.traits = .init(
                                    physical: "Muddy",
                                    personality: "Grumpy",
                                    nickname: "Grumps",
                                    generatedByMechMuse: false
                                )
                            },
                            Combatant(monster: Monster(
                                realm: .init(CompendiumRealm.core.id),
                                stats: StatBlock(name: "Bugbear"),
                                challengeRating: .half
                            )),
                            Combatant(compendiumCombatant: Character(
                                id: UUID().tagged(),
                                realm: .init(CompendiumRealm.core.id),
                                stats: StatBlock(name: "Sarovin"),
                                player: .init(name: nil)
                            ))
                        ]
                    )
                )
            ) {
                GenerateCombatantTraitsFeature()
            } withDependencies: {
                $0.mechMuse = MechMuse(
                    client: .constant(OpenAI(apiToken: "")),
                    describeAction: { client, request in
                        return AsyncThrowingStream { continuation in
                            Task {
                                try await Task.sleep(for: .seconds(0.5))
                                continuation.yield("Here's a description for prompt: \(request.prompt())")
                            }
                        }
                    },
                    describeCombatants: { _, request in
                        AsyncThrowingStream { continuation in
                            Task {
                                try await Task.sleep(for: .seconds(2))
                                continuation.finish(throwing: MechMuseError.insufficientQuota)
                            }
                        }
                    },
                    generateStatBlock: { _, _ in
                        try await Task.sleep(for: .seconds(0.5))
                        return nil
                    },
                    verifyAPIKey: { client in
                        try await Task.sleep(for: .seconds(1))
                    }
                )
            })
        }
    }
}
#endif
