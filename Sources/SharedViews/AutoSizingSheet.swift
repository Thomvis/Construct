//
//  AutoSizingSheet.swift
//  
//
//  Created by Thomas Visser on 16/09/2022.
//

import Foundation
import SwiftUI

struct AutoSizingSheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

public extension View {
    func autoSizingSheetContent(constant: CGFloat = 0) -> some View {
        self.background {
            GeometryReader { proxy in
                Color.clear.preference(key: AutoSizingSheetHeightKey.self, value: proxy.size.height + constant)
            }
        }
    }
}

public struct AutoSizingSheetContainer<Content>: View where Content: View {
    let content: () -> Content

    @State var selectedDetent = PresentationDetent.height(200)
    @State var detents: Set<PresentationDetent> = [PresentationDetent.height(200)]

    public init(content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .onPreferenceChange(AutoSizingSheetHeightKey.self) { height in
                withAnimation {
                    let detent = PresentationDetent.height(height)
                    self.detents.insert(detent)
                    self.selectedDetent = detent

                    // workaround: setting the detents set immediately breaks the animation
                    DispatchQueue.main.async {
                        self.detents = [detent]
                    }
                }
            }
            .presentationDetents(detents, selection: $selectedDetent)
    }
}
