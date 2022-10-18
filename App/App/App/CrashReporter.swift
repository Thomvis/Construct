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
import Helpers

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
