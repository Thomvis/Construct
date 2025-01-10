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

struct GenerateCombatantTraitsView: View {
    typealias State = GenerateCombatantTraitsViewState
    typealias ThisStore = Store<State, GenerateCombatantTraitsViewAction>
    typealias ThisViewStore = ViewStore<State, GenerateCombatantTraitsViewAction>

    let store: ThisStore

    var body: some View {
        WithViewStore(store) { viewStore in
            list(viewStore)
                .safeAreaInset(edge: .top) {
                    topMessage(viewStore)
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        viewStore.send(.onGenerateTap, animation: .default)
                    } label: {
                        HStack(spacing: 0) {
                            Spacer()

                            if viewStore.state.isLoading {
                                ProgressView()
                                    .padding(.trailing, 10)
                                    .controlSize(.regular)
                            }
                            Text("Generat")

                            if viewStore.state.isLoading {
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
                    .disabled(viewStore.state.disableInteractions || viewStore.state.selectedCombatants().isEmpty)
                    .padding()
                }
                .environment(\.editMode, .constant(.active))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewStore.send(.onDoneButtonTap)
                        } label: {
                            Text("Done").bold()
                        }
                    }
                }
        }
        .navigationTitle("Combatant Traits")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func topMessage(_ viewStore: ThisViewStore) -> some View {
        if let error = viewStore.state.error {
            let bg = viewStore.state.isMechMuseUnconfigured
                ? Color(UIColor.systemBlue).gradient
                : Color(UIColor.systemRed).gradient

            let image = viewStore.state.isMechMuseUnconfigured
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

    @ViewBuilder
    private func list(_ viewStore: ThisViewStore) -> some View {
        List {
            Section {
                ForEach(viewStore.state.combatants) { combatant in
                    row(combatant: combatant, viewStore: viewStore)
                }
            } header: {
                listHeader(viewStore)
            }
            .disabled(viewStore.state.disableInteractions)

            VStack(spacing: 10) {
                Text("Powered by Mechanical Muse").bold()
                Text("For the best result, generate traits for all monsters at once.")
            }
        }
    }

    @ViewBuilder
    private func listHeader(_ viewStore: ThisViewStore) -> some View {
        HStack {
            FlowLayout(spacing: 4) {
                Button("Monsters") {
                    viewStore.send(.onSmartSelectionGroupTap(.monsters))
                }
                .tint(viewStore.state.selection == .smart(.monsters) ? Color(UIColor.systemBlue) : nil)

                Button("Mobs") {
                    viewStore.send(.onSmartSelectionGroupTap(.mobs))
                }
                .tint(viewStore.state.selection == .smart(.mobs) ? Color(UIColor.systemBlue) : nil)
            }

            Spacer()

            Button {
                viewStore.send(.onOverwriteButtonTap, animation: .default.speed(2))
            } label: {
                if viewStore.overwriteEnabled {
                    Text("Overwrite on")
                } else {
                    Text("Overwrite off")
                }
            }
            .tint(Color(viewStore.overwriteEnabled ? UIColor.systemRed : UIColor.systemGreen))
            .animation(nil, value: viewStore.overwriteEnabled)

            if viewStore.state.showRemoveAllTraits || viewStore.state.showUndoAllChanges {
                Menu {
                    if viewStore.state.showRemoveAllTraits {
                        Button {
                            viewStore.send(.onRemoveAllTraitsTap, animation: .default)
                        } label: {
                            Label("Remove all traits", systemImage: "clear")
                        }
                    }

                    if viewStore.state.showUndoAllChanges {
                        Button(role: .destructive) {
                            viewStore.send(.onUndoAllChangesTap, animation: .default)
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
    private func row(combatant: State.CombatantModel, viewStore: ThisViewStore) -> some View {
        VStack(alignment: .leading) {
            let canSelect = viewStore.state.canSelect(combatant: combatant)
            let isSelected = viewStore.state.isSelected(combatant: combatant)

            let checkbox = Image(systemName: canSelect ? (isSelected ? "checkmark.circle.fill" : "circle") : "slash.circle")
                .symbolRenderingMode(.monochrome)
                .font(Font.title3)
                .foregroundColor((isSelected && !viewStore.state.disableInteractions) ? Color(UIColor.systemBlue) : Color(UIColor.systemGray2))

            HStack {
                Button {
                    viewStore.send(.onToggleCombatantSelection(combatant.id), animation: .default.speed(2))
                } label: {
                    HStack {
                        checkbox.opacity(viewStore.state.canSelect(combatant: combatant) ? 1.0 : 0.33)
                        Combatant.discriminatedNameText(name: combatant.name, discriminator: combatant.discriminator)
                            .foregroundColor(Color.primary)

                        Spacer()
                    }
                }
                .disabled(!viewStore.state.canSelect(combatant: combatant))

                if combatant.traits != nil || viewStore.state.combatantHasChanges(combatant) {
                    Menu {
                        if combatant.traits != nil {
                            Button {
                                viewStore.send(.onRemoveCombatantTraitsTap(combatant.id), animation: .default)
                            } label: {
                                Label("Remove traits", systemImage: "clear")
                            }

                            Button {
                                viewStore.send(.onRegenerateCombatantTraitsTap(combatant.id), animation: .default)
                            } label: {
                                Label("Regenerate traits", systemImage: "arrow.clockwise")
                            }
                        }

                        if viewStore.state.combatantHasChanges(combatant) {
                            Button {
                                viewStore.send(.onUndoCombatantTraitsChangesTap(combatant.id), animation: .default)
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
                ),
                reducer: GenerateCombatantTraitsViewState.reducer,
                environment: GenerateCombatantTraitsViewPreviewEnvironment()
            ))
        }
    }
}

import OpenAIClient
import MechMuse
struct GenerateCombatantTraitsViewPreviewEnvironment: GenerateCombatantTraitsViewEnvironment {
    var mechMuse = MechMuse(
        client: .constant(OpenAIClient.live(apiKey: "")),
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
        verifyAPIKey: { client in
            try await Task.sleep(for: .seconds(1))
        }
    )

    var crashReporter = CrashReporter.init(registerUserPermission: { _ in }, trackError: { _ in })
}
#endif
