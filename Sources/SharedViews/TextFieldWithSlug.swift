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

    @Binding var requestFocusOnText: Bool
    @FocusState private var focusOnText: Bool
    @FocusState private var focusOnSlug: Bool

    @Environment(\.isEnabled) var isEnabled: Bool

    @State var localSlug: String = ""

    public init(
        title: String,
        text: Binding<String>,
        slug: Binding<String>,
        configuration: Configuration = .default,
        requestFocusOnText: Binding<Bool> = Binding.constant(false)
    ) {
        self.title = title
        _text = text
        _slug = slug
        self.configuration = configuration
        _requestFocusOnText = requestFocusOnText.projectedValue
    }

    public var body: some View {
        HStack {
            TextField(title, text: $text)
                .foregroundStyle(configuration.textForegroundColor.opacity(isEnabled ? 1.0 : 0.5))
                .frame(minHeight: 35)
                .layoutPriority(1)
                .focused($focusOnText)

            TextField("", text: $localSlug)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(configuration.slugForegroundColor)
                .frame(minWidth: 50)
                .focused($focusOnSlug)
                .disabled(!configuration.slugFieldEnabled)
        }
        .onChange(of: requestFocusOnText) { newValue in
            if newValue {
                focusOnText = true
                requestFocusOnText = false
            }
        }
        .onAppear {
            if requestFocusOnText {
                focusOnText = true
                requestFocusOnText = false
            }
            // populate local state with model
            localSlug = slug
        }
        .onChange(of: localSlug) { newValue in
            // write every change to the model
            slug = localSlug
        }
        .onChange(of: focusOnSlug) { newValue in
            // update field with model when we lose focus
            if !newValue {
                localSlug = slug
            }
        }
        .onChange(of: slug) { newValue in
            // update field with model while we don't have focus
            if !focusOnSlug {
                localSlug = slug
            }
        }
    }

    public struct Configuration {
        let textForegroundColor: Color
        let slugForegroundColor: Color
        let slugFieldEnabled: Bool


        public init(
            textForegroundColor: Color = Color(UIColor.secondaryLabel),
            slugForegroundColor: Color = Color(UIColor.tertiaryLabel),
            slugFieldEnabled: Bool = true
        ) {
            self.textForegroundColor = textForegroundColor
            self.slugForegroundColor = slugForegroundColor
            self.slugFieldEnabled = slugFieldEnabled
        }

        public static let `default`: Self = .init()
    }

    private enum Field {
        case text
        case slug
    }
}
