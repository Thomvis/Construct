//
//  CrashReporter.swift
//  
//
//  Created by Thomas Visser on 30/09/2022.
//

import Foundation

public struct CrashReporter {
    public let registerUserPermission: (UserPermission) -> Void
    public let trackError: (ErrorReport) -> Void

    public init(registerUserPermission: @escaping (UserPermission) -> Void, trackError: @escaping (ErrorReport) -> Void) {
        self.registerUserPermission = registerUserPermission
        self.trackError = trackError
    }

    public enum UserPermission {
        case dontSend
        case send
        case sendAlways
    }

    public struct ErrorReport {
        public let error: Swift.Error
        public let properties: [String: String]
        public let attachments: [String: String]

        public init(error: Error, properties: [String : String], attachments: [String : String]) {
            self.error = error
            self.properties = properties
            self.attachments = attachments
        }
    }
}
