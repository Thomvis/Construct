//
//  TestWorkaroundEnvironmentKeys.swift
//  Construct
//
//  Created by Thomas Visser on 01/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct TestWorkaroundReferenceViewTabBarVisibility: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var applyTestWorkaroundReferenceViewTabBarVisibility: Bool {
        get { self[TestWorkaroundReferenceViewTabBarVisibility.self] }
        set { self[TestWorkaroundReferenceViewTabBarVisibility.self] = newValue }
    }
}
