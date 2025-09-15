//
//  CrashReporter.swift
//  Construct
//
//  Created by Thomas Visser on 22/09/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import FirebaseCrashlytics
import GameModels
import Helpers

extension CrashReporter {
    static let firebase = CrashReporter { permission in
        if case .dontSend = permission {
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        } else {
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        }
    } trackError: { report in
        Crashlytics.crashlytics().record(error: report.error, userInfo: [
            "properties": report.properties,
            "attachments": report.attachments
        ])
    }
}
