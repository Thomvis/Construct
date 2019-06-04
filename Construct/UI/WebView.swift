//
//  WebView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 18/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {

    let content: Content?

    func makeUIView(context: UIViewRepresentableContext<WebView>) -> WKWebView {
        let view = WKWebView()
        view.backgroundColor = UIColor.clear
        view.isOpaque = false

        switch content {
        case .fileUrl(let url)?:
            view.loadFileURL(url, allowingReadAccessTo: Bundle.main.bundleURL)
        case .html(let string)?:
            view.loadHTMLString(string, baseURL: nil)
        case nil:
            break
        }

        return view
    }

    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<WebView>) {

    }

    enum Content {
        case fileUrl(URL)
        case html(String)

        static func resource(_ name: String, extension ext: String, in bundle: Bundle = Bundle.main) -> Content? {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return .fileUrl(url)
            }
            return nil
        }
    }
}
