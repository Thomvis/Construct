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

class Environment: ObservableObject {

    var modifierFormatter: NumberFormatter
    var ordinalFormatter: NumberFormatter
    var database: Database

    var canSendMail: () -> Bool
    var sendMail: () -> Void
    var rateInAppStore: () -> Void
    var requestAppStoreReview: () -> Void

    var isIdleTimerDisabled: Binding<Bool>

    var generateUUID: () -> UUID
    var rng: AnyRandomNumberGenerator
    var mainQueue: AnySchedulerOf<DispatchQueue>

    var dismissKeyboard: () -> Void

    var diceLog: DiceLogPublisher

    var crashReporter: CrashReporter

    internal init(
        modifierFormatter: NumberFormatter,
        ordinalFormatter: NumberFormatter,
        database: Database,
        canSendMail: @escaping () -> Bool,
        sendMail: @escaping () -> Void,
        rateInAppStore: @escaping () -> Void,
        requestAppStoreReview: @escaping () -> Void,
        isIdleTimerDisabled: Binding<Bool>,
        generateUUID: @escaping () -> UUID,
        rng: AnyRandomNumberGenerator,
        mainQueue: AnySchedulerOf<DispatchQueue>,
        dismissKeyboard: @escaping () -> Void,
        diceLog: DiceLogPublisher,
        crashReporter: CrashReporter
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
        self.dismissKeyboard = dismissKeyboard
        self.diceLog = diceLog
        self.crashReporter = crashReporter
    }

    var compendium: Compendium {
        DatabaseCompendium(database: database, fallback: DndBeyondExternalCompendium())
    }

    var campaignBrowser: CampaignBrowser {
        CampaignBrowser(store: database.keyValueStore)
    }

}

extension Environment {
    static func live() throws -> Environment {
        let database: Database = try .live()
        let mailComposeDelegate = MailComposeDelegate()

        let keyWindow = {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .filter(\.isKeyWindow)
                .first
        }

        return Environment(
            modifierFormatter: apply(NumberFormatter()) { f in
                f.positivePrefix = f.plusSign
            },
            ordinalFormatter: apply(NumberFormatter()) { f in
                f.numberStyle = .ordinal
            },
            database: database,
            canSendMail: { MFMailComposeViewController.canSendMail() },
            sendMail: {
                let composeVC = MFMailComposeViewController()
                composeVC.mailComposeDelegate = mailComposeDelegate

                // Configure the fields of the interface.
                composeVC.setToRecipients(["hello@construct5e.app"])
                composeVC.setSubject("Construct feedback")

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
            mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
            dismissKeyboard: {
                keyWindow()?.endEditing(true)
            },
            diceLog: DiceLogPublisher(),
            crashReporter: CrashReporter.appCenter
        )
    }

    private class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true, completion: nil)
        }
    }
}

extension Database {
    static func live() throws -> Database {
        let dbUrl = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")

        return try Database(path: dbUrl.absoluteString)
    }
}

extension UIViewController {
    var deepestPresentedViewController: UIViewController {
        presentedViewController ?? self
    }
}

struct AnyRandomNumberGenerator: RandomNumberGenerator {
    var wrapped: RandomNumberGenerator

    public mutating func next() -> UInt64 {
        return wrapped.next()
    }
}

extension Environment {
    var diceRollerEnvironment: DiceRollerEnvironment {
        DiceRollerEnvironment(
            mainQueue: mainQueue,
            diceLog: diceLog,
            modifierFormatter: modifierFormatter
        )
    }
}
