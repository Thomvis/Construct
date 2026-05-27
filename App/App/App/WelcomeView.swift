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
            if let pageStore = store.scope(state: \.page, action: \.page.presented) {
                switch pageStore.case {
                case .benefits:
                    benefitsPage
                case let .contentImport(contentImportStore):
                    contentImportPage(store: contentImportStore)
                }
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

    private func contentImportPage(store contentImportStore: StoreOf<DefaultContentSelectionFeature>) -> some View {
        VStack(spacing: 12) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    DefaultContentSelectionPage(
                        store: contentImportStore,
                        primaryAction: {
                            store.send(.didTapContinue)
                        }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
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
            body: "Quickly look up monster stats and spell details. Add your own monsters and NPCs to make them available in every encounter."
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
            store: Store(initialState: .init()) {
                AppFeature.WelcomeFeature()
            }
        )
    }
}
