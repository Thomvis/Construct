//
//  TestWorkaroundEnvironmentKeys.swift
//  Construct
//
//  Created by Thomas Visser on 01/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct TestWorkaroundSidebarPresentation: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var applyTestWorkaroundSidebarPresentation: Bool {
        get { self[TestWorkaroundSidebarPresentation.self] }
        set { self[TestWorkaroundSidebarPresentation.self] = newValue }
    }
}
