//
//  SectionContainer.swift
//  Construct
//
//  Created by Thomas Visser on 22/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

func SectionContainer<Content>(title: String, backgroundColor: Color = Color.secondarySystemBackground, @ViewBuilder content: () -> Content) -> some View where Content: View {
    SectionContainer(title: title, accessory: EmptyView(), backgroundColor: backgroundColor, content: content)
}

func SectionContainer<Accessory, Content>(title: String, accessory: Accessory, backgroundColor: Color = Color.secondarySystemBackground, @ViewBuilder content: () -> Content) -> some View where Accessory: View, Content: View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Text(title).font(.headline)
            Spacer()
            accessory
        }
        SectionContainerContent(backgroundColor, content)
    }
}

func SectionContainer<Content>(backgroundColor: Color = Color.secondarySystemBackground, @ViewBuilder content: () -> Content) -> some View where Content: View {
    SectionContainerContent(backgroundColor, content)
}

fileprivate func SectionContainerContent<Content>(_ backgroundColor: Color = Color.secondarySystemBackground, @ViewBuilder _ content: () -> Content) -> some View where Content: View {
    content()
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor.cornerRadius(8))
}
