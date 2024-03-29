//
//  SectionContainer.swift
//  Construct
//
//  Created by Thomas Visser on 22/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

func SectionContainer<Content>(title: String, backgroundColor: Color = Color(UIColor.secondarySystemBackground), @ViewBuilder content: () -> Content) -> some View where Content: View {
    SectionContainer(title: title, accessory: EmptyView(), footer: { EmptyView() }, backgroundColor: backgroundColor, content: content)
}

func SectionContainer<Accessory, Content>(
    title: String? = nil,
    accessory: Accessory,
    backgroundColor: Color = Color(UIColor.secondarySystemBackground),
    @ViewBuilder content: () -> Content
) -> some View where Accessory: View, Content: View {
    SectionContainer(title: title, accessory: accessory, footer: { EmptyView() }, backgroundColor: backgroundColor, content: content)
}

func SectionContainer<Content, Footer>(
    title: String? = nil,
    @ViewBuilder footer: () -> Footer,
    backgroundColor: Color = Color(UIColor.secondarySystemBackground),
    @ViewBuilder content: () -> Content
) -> some View where Content: View, Footer: View {
    SectionContainer(title: title, accessory: EmptyView(), footer: footer, backgroundColor: backgroundColor, content: content)
}

func SectionContainer<Content>(backgroundColor: Color = Color(UIColor.secondarySystemBackground), @ViewBuilder content: () -> Content) -> some View where Content: View {
    SectionContainerContent(backgroundColor, content)
}

func SectionContainer<Accessory, Content, Footer>(
    title: String? = nil,
    accessory: Accessory,
    @ViewBuilder footer: () -> Footer,
    backgroundColor: Color = Color(UIColor.secondarySystemBackground),
    @ViewBuilder content: () -> Content
) -> some View where Accessory: View, Content: View, Footer: View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            title.map { Text($0).font(.headline) }
            Spacer()
            accessory
        }
        SectionContainerContent(backgroundColor, content)
        footer()
    }
}


fileprivate func SectionContainerContent<Content>(_ backgroundColor: Color = Color(UIColor.secondarySystemBackground), @ViewBuilder _ content: () -> Content) -> some View where Content: View {
    content()
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor.cornerRadius(8))
}
