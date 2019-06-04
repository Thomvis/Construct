//
//  SheetNavigationContainer.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 23/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct SheetNavigationContainer<Content>: View where Content: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let content: () -> Content

    var body: some View {
        NavigationView {
            content()
        }
        .environment(\.sheetPresentationMode, SheetPresentationMode {
            self.presentationMode.wrappedValue.dismiss()
        })
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
