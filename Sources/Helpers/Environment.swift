//
//  Environment.swift
//  
//
//  Created by Thomas Visser on 30/10/2022.
//

import Foundation
import CombineSchedulers

/// These protocols are only used in a couple of spaces as this was a late-stage idea.
/// I expect these to not really gain momentum, since the latest TCA release has a whole
/// different way of working with environments.

public protocol EnvironmentWithModifierFormatter {
    var modifierFormatter: NumberFormatter { get }
}

public protocol EnvironmentWithMainQueue {
    var mainQueue: AnySchedulerOf<DispatchQueue> { get }
}

