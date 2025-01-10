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
public let modifierFormatter: NumberFormatter = apply(NumberFormatter()) { f in
    f.positivePrefix = f.plusSign
}

enum ModifierFormatterKey: DependencyKey {
    public static var liveValue: NumberFormatter = modifierFormatter
}

public extension DependencyValues {
    var modifierFormatter: NumberFormatter {
        get { self[ModifierFormatterKey.self] }
        set { self[ModifierFormatterKey.self] = newValue }
    }
}
