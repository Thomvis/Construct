//
//  OrdinalFormatter.swift
//  
//
//  Created during migration to swift-dependencies
//

import Foundation
import ComposableArchitecture

/// The NumberFormatter that is to be used to display ordinal numbers (1st, 2nd, 3rd, etc.)
public class OrdinalFormatter: ObservableObject {
    private let formatter: NumberFormatter

    public init() {
        formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
    }

    public func string(from number: Int) -> String {
        return formatter.string(for: number) ?? "\(number)"
    }
}

enum OrdinalFormatterKey: DependencyKey {
    public static var liveValue: OrdinalFormatter = OrdinalFormatter()
}

public extension DependencyValues {
    var ordinalFormatter: OrdinalFormatter {
        get { self[OrdinalFormatterKey.self] }
        set { self[OrdinalFormatterKey.self] = newValue }
    }
}
