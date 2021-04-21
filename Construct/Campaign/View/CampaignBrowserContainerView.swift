//
//  CampaignBrowserContainerView.swift
//  Construct
//
//  Created by Thomas Visser on 11/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct CampaignBrowserContainerView: View {
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
        NavigationView {
            CampaignBrowseView(store: store)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
