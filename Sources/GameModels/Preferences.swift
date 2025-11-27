//
//  Preferences.swift
//  Construct
//
//  Created by Thomas Visser on 02/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers

public struct Preferences: Codable, Equatable, Sendable {
    public var didShowWelcomeSheet = false
    /// The ParseableGameModels.combinedVersion when ParseableKeyValueRecordManager last ran
    public var parseableManagerLastRunVersion: String?
    public var errorReportingEnabled: Bool?
    @DecodableDefault.TypeDefault<MechMusePreferences>
    public var mechMuse: MechMusePreferences

    public init(
        didShowWelcomeSheet: Bool = false,
        parseableManagerLastRunVersion: String? = nil,
        errorReportingEnabled: Bool? = nil,
        mechMuse: MechMusePreferences = .defaultValue
    ) {
        self.didShowWelcomeSheet = didShowWelcomeSheet
        self.parseableManagerLastRunVersion = parseableManagerLastRunVersion
        self.errorReportingEnabled = errorReportingEnabled
        self.mechMuse = mechMuse
    }
}

public struct MechMusePreferences: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var apiKey: String?
}

extension MechMusePreferences: DecodableDefaultSource {
    public typealias Value = Self

    public static var defaultValue: MechMusePreferences {
        MechMusePreferences(enabled: true, apiKey: nil)
    }
}
