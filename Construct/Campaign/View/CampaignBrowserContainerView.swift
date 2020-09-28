//
//  CampaignBrowserContainerView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 11/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct CampaignBrowserContainerView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var env: Environment
    var store: Store<CampaignBrowseViewState, CampaignBrowseViewAction>

    var body: some View {
        navigationView
            // Bug: if this frame isn't set here, the StateDrivenNavigationView will not be visible after switching tabs
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.top)
    }

    @ViewBuilder
    var navigationView: some View {
        if horizontalSizeClass == .regular {
            NavigationView {
                CampaignBrowseView(env, store)

                Text("EMPTY")
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
        } else {
            NavigationView {
                CampaignBrowseView(env, store)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
