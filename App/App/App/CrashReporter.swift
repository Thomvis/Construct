import Foundation
import FirebaseCrashlytics
import GameModels
import Helpers

extension CrashReporter {
    static let firebase = CrashReporter(
        registerUserPermission: { permission in
            switch permission {
            case .dontSend:
                Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
            case .send, .sendAlways:
                Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            }
        },
        trackError: { report in
            for (key, value) in report.properties {
                Crashlytics.crashlytics().setCustomValue(value, forKey: key)
            }
            for (name, text) in report.attachments {
                Crashlytics.crashlytics().log("\(name): \(text)")
            }
            Crashlytics.crashlytics().record(error: report.error)
        }
    )
}
