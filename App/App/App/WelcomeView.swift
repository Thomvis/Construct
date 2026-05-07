//
//  WelcomeView.swift
//  Construct
//
//  Created by Thomas Visser on 02/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import SwiftUI
import SharedViews
import ComposableArchitecture

struct WelcomeView: View {

    @Bindable var store: StoreOf<AppFeature.WelcomeFeature>

    var body: some View {
        VStack(spacing: 20) {
            switch store.page {
            case .benefits:
                benefitsPage
            case .contentImport:
                contentImportPage
            }
        }
        .padding(28)
    }

    private var benefitsPage: some View {
        VStack(spacing: 20) {
            ScrollView(.vertical) {
                Text("Welcome to Construct")
                    .font(Font.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits([.isHeader])
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Self.items) { item in
                        HStack(spacing: 25) {
                            Image(systemName: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: ContentMode.fit)
                                .frame(width: 45, height: 45)
                                .foregroundColor(item.iconColor)
                                .accessibility(hidden: true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.headline)
                                    .accessibilityAddTraits([.isHeader])
                                Text(item.body)
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                            }
                        }
                    }
                }
            }

            Button(action: {
                store.send(.didTapNext)
            }) {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var contentImportPage: some View {
        VStack(spacing: 12) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Load default content")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DefaultContentSelectionView(
                        store: store.scope(
                            state: \.defaultContentSelection,
                            action: \.defaultContentSelection
                        ),
                        showsTitle: false,
                        showsValidationMessage: false,
                        showsSampleEncounterOption: false
                    )

                    if let sampleEncounterOption = store.defaultContentSelection.sampleEncounterOption {
                        HStack(spacing: 12) {
                            Text(sampleEncounterOption.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Spacer(minLength: 8)

                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { sampleEncounterOption.isEnabled },
                                    set: { store.send(.defaultContentSelection(.setSampleEncounterEnabled($0))) }
                                )
                            )
                            .labelsHidden()
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 8)
                        .accessibilityIdentifier("default-content-sample-toggle")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text("You can change this in Settings later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                Button(action: {
                        store.send(.didTapContinue)
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!store.defaultContentSelection.isValidSelection || store.defaultContentSelection.isImporting)

                Text("Select at least one edition.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 18, alignment: .center)
                    .opacity(store.defaultContentSelection.isValidSelection ? 0 : 1)
                    .accessibilityHidden(store.defaultContentSelection.isValidSelection)
            }
        }
    }

    static let items: [ListItem] = [
        ListItem(
            title: "Encounter tracker",
            icon: "shield.fill",
            iconColor: Color.accentColor,
            body: "Let Construct manage monster hp, conditions, limited-use actions and more so you can focus on your story."
        ),
        ListItem(
            title: "Adventure planner",
            icon: "map.fill",
            iconColor: Color.accentColor,
            body: "Prepare encounters and order them by campaign, adventure, session or any other way you like. Every encounter is replayable and can be tailored to the players at your table."
        ),
        ListItem(
            title: "Compendium",
            icon: "book.fill",
            iconColor: Color.accentColor,
            body: "Quickly look up monster stats or spell details (from the SRD 5.1). Add your own monsters and NPCs to make them available in every encounter."
        )
    ]
    struct ListItem: Identifiable {
        let title: String
        let icon: String
        let iconColor: Color
        let body: String

        var id: String { title }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(
            store: Store(initialState: .init(selection: .none, sampleEncounterDefault: true)) {
                AppFeature.WelcomeFeature()
            }
        )
    }
}
