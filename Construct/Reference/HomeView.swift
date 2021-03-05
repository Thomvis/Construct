//
//  HomeView.swift
//  Construct
//
//  Created by Thomas Visser on 25/01/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: Store<ReferenceItemViewState.Content.Home, ReferenceItemViewAction.Home>

    var body: some View {
        WithViewStore(store) { viewStore in
            ScrollView {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        SectionContainer(title: "Compendium") {
                            VStack {
                                // fake search field
                                Button(action: {
                                    viewStore.send(.compendiumSearchTapped)
                                }) {
                                    SearchField(text: Binding.constant(""), accessory: EmptyView())
                                        .allowsHitTesting(false)
                                        .padding(8)
                                        .background(Color(UIColor.systemBackground).cornerRadius(4))
                                        .contentShape(Rectangle())
                                }

                                Divider()

                                SimpleList(
                                    data: [
                                        CompendiumItemType.monster,
                                        CompendiumItemType.character,
                                        CompendiumItemType.group,
                                        CompendiumItemType.spell
                                    ],
                                    id: \.rawValue
                                ) { type in
                                    Button(action: {
                                        viewStore.send(.compendiumSectionTapped(type))
                                    }) {
                                        Text(type.localizedScreenDisplayName).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
            .stateDrivenNavigationLink(
                store: store,
                state: /ReferenceItemViewState.Content.Home.NextScreenState.compendium,
                action: /ReferenceItemViewAction.Home.NextScreenAction.compendium,
                isActive: { _ in true },
                destination: { CompendiumIndexView(store: $0) }
            )
            .navigationBarHidden(true)
        }
    }

    struct ButtonStyle: SwiftUI.ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Font.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    Color(UIColor.systemGray3)
                        .cornerRadius(8)
                )
                .opacity(configuration.isPressed ? 0.66 : 1.0)
        }
    }
}
