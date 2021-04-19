//
//  Environment.swift
//  SwiftUITest
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

class Environment: ObservableObject {

    var modifierFormatter: NumberFormatter
    var ordinalFormatter: NumberFormatter
    var database: Database

    var canSendMail: () -> Bool
    var sendMail: () -> Void
    var rateInAppStore: () -> Void

    var isIdleTimerDisabled: Binding<Bool>

    var generateUUID: () -> UUID
    var rng: AnyRandomNumberGenerator
    var mainQueue: AnySchedulerOf<DispatchQueue>

    var dismissKeyboard: () -> Void

    internal init(
        modifierFormatter: NumberFormatter,
        ordinalFormatter: NumberFormatter,
        database: Database,
        canSendMail: @escaping () -> Bool,
        sendMail: @escaping () -> Void,
        rateInAppStore: @escaping () -> Void,
        isIdleTimerDisabled: Binding<Bool>,
        generateUUID: @escaping () -> UUID,
        rng: AnyRandomNumberGenerator,
        mainQueue: AnySchedulerOf<DispatchQueue>,
        dismissKeyboard: @escaping () -> Void
    ) {
        self.modifierFormatter = modifierFormatter
        self.ordinalFormatter = ordinalFormatter
        self.database = database
        self.canSendMail = canSendMail
        self.sendMail = sendMail
        self.rateInAppStore = rateInAppStore
        self.isIdleTimerDisabled = isIdleTimerDisabled
        self.generateUUID = generateUUID
        self.rng = rng
        self.mainQueue = mainQueue
        self.dismissKeyboard = dismissKeyboard
    }

    var compendium: Compendium {
        Compendium(database)
    }

    var campaignBrowser: CampaignBrowser {
        CampaignBrowser(store: database.keyValueStore)
    }

}

extension Environment {
    static func live(window: UIWindow) throws -> Environment {
        let database: Database = try .live()
        let mailComposeDelegate = MailComposeDelegate()

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
                window.rootViewController?.deepestPresentedViewController.present(composeVC, animated: true, completion:nil)
            },
            rateInAppStore: {
                let appID = 1490015210
                let url = "https://itunes.apple.com/app/id\(appID)?action=write-review"
                UIApplication.shared.open(URL(string: url)!, options: [:], completionHandler: nil)
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
                window.endEditing(true)
            }
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
