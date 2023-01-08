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
                .environment(\.editMode, .constant(.active))
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button("Cancel") {
                            viewStore.send(.onCancelButtonTap)
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewStore.send(.onDoneButtonTap)
                        } label: {
                            Text("Done").bold()
                        }
                        .disabled(viewStore.state.disableInteractions)
                    }

                    ToolbarItem(placement: .bottomBar) {
                        VStack {
                            Button {
                                viewStore.send(.onGenerateTap, animation: .default)
                            } label: {
                                ZStack {
                                    if viewStore.state.isLoading {
                                        ProgressView()
                                    } else {
                                        Text("Generate traits")
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewStore.state.disableInteractions || viewStore.state.selectedCombatants().isEmpty)

                            Text("Powered by Mechanical Muse")
                                .font(.footnote)
                                .foregroundColor(.secondary)
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
                : Image(systemName: "exclamationmark.square.fill")

            VStack(spacing: 12) {
                image

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

            if viewStore.state.showRemoveAllTraits {
                Menu {
                    Button(role: .destructive) {
                        viewStore.send(.onRemoveAllTraitsTap, animation: .default)
                    } label: {
                        Label("Remove all traits", systemImage: "clear")
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

            Button {
                viewStore.send(.onToggleCombatantSelection(combatant.id), animation: .default.speed(2))
            } label: {
                HStack {
                    checkbox.opacity(viewStore.state.canSelect(combatant: combatant) ? 1.0 : 0.33)
                    Combatant.discriminatedNameText(name: combatant.name, discriminator: combatant.discriminator)
                        .foregroundColor(Color.primary)

                    Spacer()

                    if combatant.traits != nil {
                        Menu {
                            Button(role: .destructive) {
                                viewStore.send(.onRemoveCombatantTraitsTap(combatant.id), animation: .default)
                            } label: {
                                Label("Remove traits", systemImage: "clear")
                            }
                        } label: {
                            Button { } label: {
                                Image(systemName: "ellipsis.circle")
                            }
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
struct DiceRollerView_Preview: PreviewProvider {
    static var previews: some View {
        ZStack(alignment: .bottom) {
            Color.blue.ignoresSafeArea()

            NavigationView {
                GenerateCombatantTraitsView(store: Store(
                    initialState: .init(
                        encounter: Encounter(
                            name: "Test",
                            combatants: [
                                Combatant(monster: Monster(
                                    realm: .core,
                                    stats: StatBlock(name: "Goblin"),
                                    challengeRating: .half
                                )),
                                apply(Combatant(monster: Monster(
                                    realm: .core,
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
                                    realm: .core,
                                    stats: StatBlock(name: "Bugbear"),
                                    challengeRating: .half
                                )),
                                Combatant(compendiumCombatant: Character(
                                    id: UUID().tagged(),
                                    realm: .homebrew,
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
            .frame(height: 400)
        }
    }
}

import OpenAIClient
import MechMuse
struct GenerateCombatantTraitsViewPreviewEnvironment: GenerateCombatantTraitsViewEnvironment {
    var mechMuse = MechMuse(
        clientProvider: AsyncThrowingStream([OpenAIClient.live(apiKey: "")].async),
        describeAction: { client, request, tov in
            try await Task.sleep(for: .seconds(0.5))
            return "Here's a description for prompt: \(request.prompt(toneOfVoice: tov))"
        },
        describeCombatants: { _, request in
            try await Task.sleep(for: .seconds(2))
            throw MechMuseError.insufficientQuota
//            return .init(descriptions: Dictionary(
//                uniqueKeysWithValues: request.combatantNames.map { name -> (String, EncounterCombatantsDescription.Description) in
//                    (name, .init(appearance: "Lots 'o scars", behavior: "Many 'o laughs", nickname: "The Real \(name)"))
//                }
//            ))
        },
        verifyAPIKey: { client in
            try await Task.sleep(for: .seconds(1))
        }
    )

    var crashReporter = CrashReporter.init(registerUserPermission: { _ in }, trackError: { _ in })
}
#endif
