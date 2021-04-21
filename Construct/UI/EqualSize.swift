//
//  EqualSize.swift
//  Construct
//
//  Created by Thomas Visser on 06/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct SizeConstraint: Equatable, CustomStringConvertible {
    var width: CGFloat?
    var height: CGFloat?

    var description: String {
        "\(width ?? -1), \(height ?? -1)"
    }
}

struct SizeKey: PreferenceKey {
    static let defaultValue: [CGSize] = []
    static func reduce(value: inout [CGSize], nextValue: () -> [CGSize]) {
        value.append(contentsOf: nextValue())
    }
}

struct SizeEnvironmentKey: EnvironmentKey {
    static let defaultValue: SizeConstraint? = nil
}

extension EnvironmentValues {
    var size: SizeConstraint? {
        get { self[SizeEnvironmentKey.self] }
        set { self[SizeEnvironmentKey.self] = newValue }
    }
}

fileprivate struct EqualSize: ViewModifier {
    @SwiftUI.Environment(\.size) private var size
    let alignment: SwiftUI.Alignment

    func body(content: Content) -> some View {
        content
            .transformEnvironment(\.size) { $0 = nil }
            .overlay(GeometryReader { proxy in
                Color.clear.preference(key: SizeKey.self, value: [proxy.size])
            })
            .frame(width: size?.width, height: size?.height, alignment: alignment)
    }
}

fileprivate struct EqualSizes: ViewModifier {
    let horizontal: Bool
    let vertical: Bool

    @State var constraint: SizeConstraint?

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(SizeKey.self) { sizes in
                self.constraint = SizeConstraint(
                    width: self.horizontal ? sizes.map { $0.width }.max() : nil,
                    height: self.vertical ? sizes.map { $0.height }.max() : nil
                )
            }
            .environment(\.size, constraint)
            .transformPreference(SizeKey.self) { $0.removeAll() }
    }
}

extension View {
    func equalSize(alignment: SwiftUI.Alignment = .center) -> some View {
        self.modifier(EqualSize(alignment: alignment))
    }

    func equalSizes() -> some View {
        equalSizes(horizontal: true, vertical: true)
    }

    func equalSizes(horizontal: Bool, vertical: Bool) -> some View {
        self.modifier(EqualSizes(horizontal: horizontal, vertical: vertical))
    }
}
