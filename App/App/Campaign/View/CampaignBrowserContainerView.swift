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
    var store: Store<CampaignBrowseViewFeature.State, CampaignBrowseViewFeature.Action>

    var body: some View {
        NavigationStack {
            CampaignBrowseView(store: store)
        }
    }    
}
