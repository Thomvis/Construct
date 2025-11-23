//
//  File.swift
//  
//
//  Created by Thomas Visser on 08/12/2022.
//

import Foundation
import ComposableArchitecture

/// The NumberFormatter that is to be used to display modifiers. It always
/// includes the +/- sign.
public class ModifierFormatter: ObservableObject {
    private let formatter: NumberFormatter

    public init() {
        formatter = NumberFormatter()
        formatter.positivePrefix = formatter.plusSign
    }

    public func string(from modifier: Int) -> String {
        if let str = formatter.string(for: modifier) {
            return str
        }

        if modifier >= 0 {
            return "+\(modifier)"
        } else {
            return "-\(modifier)"
        }
    }
}

enum ModifierFormatterKey: DependencyKey {
    public static var liveValue: ModifierFormatter = ModifierFormatter()
}

public extension DependencyValues {
    var modifierFormatter: ModifierFormatter {
        get { self[ModifierFormatterKey.self] }
        set { self[ModifierFormatterKey.self] = newValue }
    }
}
