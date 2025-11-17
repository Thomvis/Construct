//
//  SafariView.swift
//  Construct
//
//  Created by Thomas Visser on 25/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import SafariServices
import ComposableArchitecture
import Helpers

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        
    }
}

struct SafariViewState: Hashable, Codable, Identifiable {
    let url: URL

    var id: URL { url }

    static let nullInstance = SafariViewState(url: URL(fileURLWithPath: "/"))
}

extension SafariViewState: NavigationStackItemState {
    var navigationStackItemStateId: String {
        "safariView:\(url.absoluteString)"
    }

    var navigationTitle: String {
        "Safari"
    }
}

extension SafariViewState: NavigationTreeNode {}

extension SafariView {
    init(store: Store<SafariViewState, Void>) {
        self.init(url: ViewStore(store, observe: \.self).url)
    }
}
