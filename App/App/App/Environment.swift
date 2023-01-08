//
//  Environment.swift
//  Construct
//
//  Created by Thomas Visser on 07/06/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import CoreHaptics
import MessageUI
import CombineSchedulers
import StoreKit
import DiceRollerFeature
import Helpers
import Persistence
import Compendium
import GameModels
import MechMuse

class Environment: ObservableObject {

    var modifierFormatter: NumberFormatter
    var ordinalFormatter: NumberFormatter
    var database: Database

    var canSendMail: () -> Bool
    var sendMail: (FeedbackMailContents) -> Void
    var rateInAppStore: () -> Void
    var requestAppStoreReview: () -> Void

    var isIdleTimerDisabled: Binding<Bool>

    var generateUUID: () -> UUID
    var rng: AnyRandomNumberGenerator
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var backgroundQueue: AnySchedulerOf<DispatchQueue>

    var dismissKeyboard: () -> Void
    var screenshot: () -> UIImage?

    var diceLog: DiceLogPublisher
    var crashReporter: CrashReporter
    var mechMuse: MechMuse

    internal init(
        modifierFormatter: NumberFormatter,
        ordinalFormatter: NumberFormatter,
        database: Database,
        canSendMail: @escaping () -> Bool,
        sendMail: @escaping (FeedbackMailContents) -> Void,
        rateInAppStore: @escaping () -> Void,
        requestAppStoreReview: @escaping () -> Void,
        isIdleTimerDisabled: Binding<Bool>,
        generateUUID: @escaping () -> UUID,
        rng: AnyRandomNumberGenerator,
        mainQueue: AnySchedulerOf<DispatchQueue>,
        backgroundQueue: AnySchedulerOf<DispatchQueue>,
        dismissKeyboard: @escaping () -> Void,
        screenshot: @escaping () -> (UIImage?),
        diceLog: DiceLogPublisher,
        crashReporter: CrashReporter,
        mechMuse: MechMuse
    ) {
        self.modifierFormatter = modifierFormatter
        self.ordinalFormatter = ordinalFormatter
        self.database = database
        self.canSendMail = canSendMail
        self.sendMail = sendMail
        self.rateInAppStore = rateInAppStore
        self.requestAppStoreReview = requestAppStoreReview
        self.isIdleTimerDisabled = isIdleTimerDisabled
        self.generateUUID = generateUUID
        self.rng = rng
        self.mainQueue = mainQueue
        self.backgroundQueue = backgroundQueue
        self.dismissKeyboard = dismissKeyboard
        self.screenshot = screenshot
        self.diceLog = diceLog
        self.crashReporter = crashReporter
        self.mechMuse = mechMuse
    }

    var compendium: Compendium {
        DatabaseCompendium(database: database, fallback: DndBeyondExternalCompendium())
    }

    var campaignBrowser: CampaignBrowser {
        CampaignBrowser(store: database.keyValueStore)
    }

}

extension Environment {
    @MainActor
    static func live(
        database db: Database? = nil,
        mainQueue: AnySchedulerOf<DispatchQueue>? = nil,
        backgroundQueue: AnySchedulerOf<DispatchQueue>? = nil
    ) async throws -> Environment {
        let database: Database
        if let db {
            database = db
        } else {
            database = try await .live()
        }
        let mailComposeDelegate = MailComposeDelegate()

        let keyWindow = {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .filter(\.isKeyWindow)
                .first
        }

        return Environment(
            modifierFormatter: Helpers.modifierFormatter,
            ordinalFormatter: apply(NumberFormatter()) { f in
                f.numberStyle = .ordinal
            },
            database: database,
            canSendMail: { MFMailComposeViewController.canSendMail() },
            sendMail: { contents in
                let composeVC = MFMailComposeViewController()
                composeVC.mailComposeDelegate = mailComposeDelegate

                // Configure the fields of the interface.
                composeVC.setToRecipients(["hello@construct5e.app"])
                composeVC.setSubject(contents.subject)

                for attachment in contents.attachments {
                    composeVC.addAttachmentData(
                        attachment.data,
                        mimeType: attachment.mimeType,
                        fileName: attachment.fileName
                    )
                }

                // Present the view controller modally.
                keyWindow()?.rootViewController?.deepestPresentedViewController.present(composeVC, animated: true, completion:nil)
            },
            rateInAppStore: {
                let appID = 1490015210
                let url = "https://itunes.apple.com/app/id\(appID)?action=write-review"
                UIApplication.shared.open(URL(string: url)!, options: [:], completionHandler: nil)
            },
            requestAppStoreReview: {
                if let windowScene = keyWindow()?.windowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            },
            isIdleTimerDisabled: Binding<Bool>(get: {
                UIApplication.shared.isIdleTimerDisabled
            }, set: {
                UIApplication.shared.isIdleTimerDisabled = $0
            }),
            generateUUID: UUID.init,
            rng: AnyRandomNumberGenerator(wrapped: SystemRandomNumberGenerator()),
            mainQueue: mainQueue ?? DispatchQueue.main.eraseToAnyScheduler(),
            backgroundQueue: backgroundQueue ?? DispatchQueue.global(qos: .userInitiated).eraseToAnyScheduler(),
            dismissKeyboard: {
                keyWindow()?.endEditing(true)
            },
            screenshot: { () -> UIImage? in
                guard let window = keyWindow() else { return nil }

                UIGraphicsBeginImageContextWithOptions(window.frame.size, true, 0.0)
                defer { UIGraphicsEndImageContext() }

                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                return UIGraphicsGetImageFromCurrentImageContext()
            },
            diceLog: DiceLogPublisher(),
            crashReporter: CrashReporter.appCenter,
            mechMuse: .live(db: database)
        )
    }

    private class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true, completion: nil)
        }
    }
}

extension Database {
    static func live() async throws -> Database {
        let dbUrl = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")

        return try await Database(path: dbUrl.absoluteString)
    }
}

extension UIViewController {
    var deepestPresentedViewController: UIViewController {
        presentedViewController?.deepestPresentedViewController ?? self
    }
}

struct AnyRandomNumberGenerator: RandomNumberGenerator {
    var wrapped: RandomNumberGenerator

    public mutating func next() -> UInt64 {
        return wrapped.next()
    }
}

extension EnvironmentWithDatabase {
    func preferences() -> Preferences {
        (try? database.keyValueStore.get(Preferences.key)) ?? Preferences()
    }

    func updatePreferences(_ f: (inout Preferences) -> Void) throws {
        var p = preferences()
        f(&p)
        try database.keyValueStore.put(p)
    }
}

extension Environment: EnvironmentWithModifierFormatter, EnvironmentWithMainQueue, EnvironmentWithDiceLog, EnvironmentWithMechMuse, EnvironmentWithDatabase, EnvironmentWithSendMail, EnvironmentWithCrashReporter {

}
