//
//  WelcomeView.swift
//  Construct
//
//  Created by Thomas Visser on 02/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import SwiftUI
import SharedViews

struct WelcomeView: View {

    let action: (ButtonTap) -> Void

    var body: some View {
        VStack(spacing: 20) {

            ScrollView(.vertical) {
                Text("Welcome to Construct").font(Font.largeTitle.bold())
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


            Text("Check out the sample encounter or tap Continue to start building your own adventures.")
                .font(.footnote)
                .foregroundColor(Color(UIColor.secondaryLabel))

            RoundedButton(color: Color(UIColor.systemBlue), action: {
                self.action(.sampleEncounter)
            }) {
                Text("Open sample encounter")
                    .font(.headline)
                    .foregroundColor(Color.white)
            }

            Button(action: {
                self.action(.dismiss)
            }) {
                Text("Continue")
            }
        }
        .padding(28)
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

    enum ButtonTap {
        case sampleEncounter
        case dismiss
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView { _ in }
    }
}
