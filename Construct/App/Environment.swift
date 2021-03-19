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
    let urlSession = URLSession(configuration: URLSessionConfiguration.default)
    let modifierFormatter: NumberFormatter
    let ordinalFormatter: NumberFormatter
    let database: Database
    let compendium: Compendium
    let campaignBrowser: CampaignBrowser

    let playHapticsFile: (String) -> ()

    let canSendMail: Bool
    let sendMail: () -> Void
    let rateInAppStore: () -> Void
    private let mailComposeDelegate: MailComposeDelegate

    var isIdleTimerDisabled: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }

    let generateUUID: () -> UUID
    var rng: AnyRandomNumberGenerator
    let mainQueue: AnySchedulerOf<DispatchQueue>

    init(
        window: UIWindow,
        generateUUID: @escaping () -> UUID = UUID.init,
        rng: RandomNumberGenerator = SystemRandomNumberGenerator(),
        mainQueue: AnySchedulerOf<DispatchQueue> = DispatchQueue.main.eraseToAnyScheduler()
    ) {
        self.modifierFormatter = NumberFormatter()
        modifierFormatter.positivePrefix = modifierFormatter.plusSign

        self.ordinalFormatter = NumberFormatter()
        ordinalFormatter.numberStyle = .ordinal

        let dbUrl: URL?
        do {
            dbUrl = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("db.sqlite")

            // FIXME
            //try? FileManager.default.removeItem(at: dbUrl!)
        } catch {
            print("Could not determine file for database. Using in-memory database.")
            dbUrl = nil
        }

        self.database = try! Database(path: dbUrl?.path)
        print("Using database at path: \(dbUrl?.path ?? "in-memory")")

        self.compendium = Compendium(database)
        self.campaignBrowser = CampaignBrowser(store: database.keyValueStore)

        let engine = try? CHHapticEngine()
        self.playHapticsFile = { name in
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
            guard let path = Bundle.main.path(forResource: name, ofType: "ahap") else {
                return
            }

            do {
                try engine?.playPattern(from: URL(fileURLWithPath: path))
            } catch {
                print("An error occured playing \(name): \(error).")
            }
        }

        self.canSendMail = MFMailComposeViewController.canSendMail()
        let mailComposeDelegate = MailComposeDelegate()
        self.mailComposeDelegate = mailComposeDelegate
        self.sendMail = {
            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = mailComposeDelegate

            // Configure the fields of the interface.
            composeVC.setToRecipients(["hello@construct5e.app"])
            composeVC.setSubject("Construct feedback")

            // Present the view controller modally.
            window.rootViewController?.deepestPresentedViewController.present(composeVC, animated: true, completion: nil)
        }

        self.rateInAppStore = {
            let appID = 1490015210
            let url = "https://itunes.apple.com/app/id\(appID)?action=write-review"
            UIApplication.shared.open(URL(string: url)!, options: [:], completionHandler: nil)
        }

        self.generateUUID = generateUUID
        self.rng = AnyRandomNumberGenerator(wrapped: rng)
        self.mainQueue = mainQueue
    }

    func dismissKeyboard() {
        let keyWindow = UIApplication.shared.windows
                           .filter { $0.isKeyWindow }.first
        keyWindow!.endEditing(true)
    }

    private class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true, completion: nil)
        }
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
