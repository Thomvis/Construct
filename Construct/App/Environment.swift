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
#if os(iOS)
import MessageUI
#endif
import CombineSchedulers
import StoreKit

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
        diceLog: DiceLogPublisher
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
    }

    var compendium: Compendium {
        Compendium(database)
    }

    var campaignBrowser: CampaignBrowser {
        CampaignBrowser(store: database.keyValueStore)
    }

}

extension Environment {
    static func live() throws -> Environment {
        let database: Database = try .live()
        #if os(iOS)
        let mailComposeDelegate = MailComposeDelegate()
        #endif

        let keyWindow = {
            #if os(iOS)
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .filter(\.isKeyWindow)
                .first
            #elseif os(macOS)
            NSApplication.shared.keyWindow
            #endif
        }

        return Environment(
            modifierFormatter: apply(NumberFormatter()) { f in
                f.positivePrefix = f.plusSign
            },
            ordinalFormatter: apply(NumberFormatter()) { f in
                f.numberStyle = .ordinal
            },
            database: database,
            canSendMail: {
                #if os(iOS)
                MFMailComposeViewController.canSendMail()
                #elseif os(macOS)
                true
                #endif
            },
            sendMail: {
                #if os(iOS)
                let composeVC = MFMailComposeViewController()
                composeVC.mailComposeDelegate = mailComposeDelegate

                // Configure the fields of the interface.
                composeVC.setToRecipients(["hello@construct5e.app"])
                composeVC.setSubject("Construct feedback")

                // Present the view controller modally.
                keyWindow()?.rootViewController?.deepestPresentedViewController.present(composeVC, animated: true, completion:nil)
                #elseif os(macOS)
                NSWorkspace.shared.open(URL(string: "mailto:hello@construct5e.app?subject=Construct%20feedback")!)
                #endif
            },
            rateInAppStore: {
                #if os(iOS)
                let appID = 1490015210
                let url = "https://itunes.apple.com/app/id\(appID)?action=write-review"
                UIApplication.shared.open(URL(string: url)!, options: [:], completionHandler: nil)
                #endif
            },
            requestAppStoreReview: {
                #if os(iOS)
                if let windowScene = keyWindow()?.windowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
                #else
                SKStoreReviewController.requestReview()
                #endif
            },
            isIdleTimerDisabled: Binding<Bool>(get: {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled
                #else
                false
                #endif
            }, set: {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled = $0
                #endif
            }),
            generateUUID: UUID.init,
            rng: AnyRandomNumberGenerator(wrapped: SystemRandomNumberGenerator()),
            mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
            dismissKeyboard: {
                #if os(iOS)
                keyWindow()?.endEditing(true)
                #endif
            },
            diceLog: DiceLogPublisher()
        )
    }

    #if os(iOS)
    private class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true, completion: nil)
        }
    }
    #endif
}

extension Database {
    static func live() throws -> Database {
        let dbUrl = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")

        return try Database(path: dbUrl.absoluteString)
    }
}

#if os(iOS)
extension UIViewController {
    var deepestPresentedViewController: UIViewController {
        presentedViewController ?? self
    }
}
#endif

struct AnyRandomNumberGenerator: RandomNumberGenerator {
    var wrapped: RandomNumberGenerator

    public mutating func next() -> UInt64 {
        return wrapped.next()
    }
}
