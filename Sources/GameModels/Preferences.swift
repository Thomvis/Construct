//
//  Preferences.swift
//  Construct
//
//  Created by Thomas Visser on 02/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

public struct Preferences: Codable, Equatable {
    public var didShowWelcomeSheet = false
    /// The DomainParsers.combinedVersion when ParseableKeyValueRecordManager last ran
    public var parseableManagerLastRunVersion: String?
    public var errorReportingEnabled: Bool?

    public init(didShowWelcomeSheet: Bool = false, parseableManagerLastRunVersion: String? = nil, errorReportingEnabled: Bool? = nil) {
        self.didShowWelcomeSheet = didShowWelcomeSheet
        self.parseableManagerLastRunVersion = parseableManagerLastRunVersion
        self.errorReportingEnabled = errorReportingEnabled
    }
}
