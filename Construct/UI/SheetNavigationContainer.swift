//
//  SheetNavigationContainer.swift
//  Construct
//
//  Created by Thomas Visser on 23/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Introspect

struct SheetNavigationContainer<Content>: View where Content: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var isModalInPresentation = false
    let content: () -> Content

    var body: some View {
        NavigationView {
            content()
        }
        .environment(\.sheetPresentationMode, SheetPresentationMode {
            self.presentationMode.wrappedValue.dismiss()
        })
        .introspectViewController { vc in
            assert(vc.parent == nil && vc.presentingViewController != nil)
            if isModalInPresentation {
                vc.isModalInPresentation = true
            }
        }
    }

}

struct SheetPresentationModeEnvironmentKey: EnvironmentKey {
    static var defaultValue: SheetPresentationMode?
}

extension EnvironmentValues {
    var sheetPresentationMode: SheetPresentationMode? {
        get { self[SheetPresentationModeEnvironmentKey.self] }
        set { self[SheetPresentationModeEnvironmentKey.self] = newValue }
    }
}

struct SheetPresentationMode {
    let dismiss: () -> Void
}
