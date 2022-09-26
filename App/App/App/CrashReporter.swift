//
//  CrashReporter.swift
//  Construct
//
//  Created by Thomas Visser on 22/09/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import AppCenterCrashes
import GameModels

struct CrashReporter {
    let registerUserPermission: (UserPermission) -> Void
    let trackError: (ErrorReport) -> Void

    enum UserPermission {
        case dontSend
        case send
        case sendAlways
    }

    struct ErrorReport {
        let error: Swift.Error
        let properties: [String: String]
        let attachments: [String: String]
    }
}

extension CrashReporter {
    static let appCenter = CrashReporter(
        registerUserPermission: { permission in
            switch permission {
            case .dontSend:
                Crashes.notify(with: .dontSend)
            case .send:
                Crashes.notify(with: .send)
            case .sendAlways:
                Crashes.notify(with: .always)
            }
        },
        trackError: { report in
            Crashes.trackException(
                ExceptionModel(
                    // NSError.domain gives the fully qualified name of the Swift error type
                    withType: (report.error as NSError).domain,
                    exceptionMessage: String(describing: report.error),
                    stackTrace: Array(Thread.callStackSymbols[2...])
                ),
                properties: report.properties,
                attachments: report.attachments.map { name, text in
                    ErrorAttachmentLog(filename: name, attachmentText: text)
                }
            )
        }
    )
}

extension KeyValueStore {
    func get<V>(_ key: String, crashReporter: CrashReporter) throws -> V? where V: Codable {
        do {
            return try get(key)
        } catch let error as DecodingError {
            guard let preferences: Preferences = try? get(Preferences.key),
                  preferences.errorReportingEnabled == true else { throw error }

            let data = try? (getRaw(key)?.value)
                .flatMap { String(data: $0, encoding: .utf8) }

            crashReporter.trackError(.init(
                error: error,
                properties: [
                    "key": key,
                    "type": String(describing: V.self)
                ],
                attachments: [
                    "data": data ?? "((missing))"
                ]
            ))
            throw error
        } catch {
            throw error
        }
    }

    func get(_ itemKey: CompendiumItemKey, crashReporter: CrashReporter) throws -> CompendiumEntry? {
        try get(CompendiumEntry.key(for: itemKey), crashReporter: crashReporter)
    }
}
