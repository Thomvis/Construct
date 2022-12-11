//
//  File.swift
//  
//
//  Created by Thomas Visser on 08/12/2022.
//

import Foundation

/// The NumberFormatter that is to be used to display modifiers. It always
/// includes the +/- sign.
public let modifierFormatter: NumberFormatter = apply(NumberFormatter()) { f in
    f.positivePrefix = f.plusSign
}
