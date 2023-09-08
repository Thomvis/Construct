//
//  TextFieldWithSlug.swift
//
//
//  Created by Thomas Visser on 03/09/2023.
//

import Foundation
import SwiftUI

public struct TextFieldWithSlug: View {
    let title: String
    @Binding var text: String
    @Binding var slug: String
    let configuration: Configuration

    public init(
        title: String,
        text: Binding<String>,
        slug: Binding<String>,
        configuration: Configuration = .default
    ) {
        self.title = title
        _text = text
        _slug = slug
        self.configuration = configuration
    }

    public var body: some View {
        HStack {
            TextField(title, text: $text)
                .foregroundStyle(configuration.textForegroundColor)
                .frame(minHeight: 35)
                .layoutPriority(1)

            TextField("", text: $slug)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(configuration.slugForegroundColor)
            .frame(minWidth: 50)
        }
    }

    public struct Configuration {
        var textForegroundColor: Color
        var slugForegroundColor: Color

        public init(textForegroundColor: Color, slugForegroundColor: Color) {
            self.textForegroundColor = textForegroundColor
            self.slugForegroundColor = slugForegroundColor
        }

        public static let `default`: Self = .init(
            textForegroundColor: Color(UIColor.secondaryLabel),
            slugForegroundColor: Color(UIColor.tertiaryLabel)
        )
    }
}
