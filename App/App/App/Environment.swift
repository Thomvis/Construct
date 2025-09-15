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
import ComposableArchitecture

class Environment: ObservableObject {

    var modifierFormatter: NumberFormatter
    var ordinalFormatter: NumberFormatter
    var database: Database

    var canSendMail: () -> Bool
    var sendMail: (FeedbackMailContents) -> Void
    var rateInAppStore: () -> Void
    var requestAppStoreReview: () -> Void

    var isIdleTimerDisabled: Binding<Bool>

    var generateUUID: @Sendable () -> UUID
    var rng: AnyRandomNumberGenerator
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var backgroundQueue: AnySchedulerOf<DispatchQueue>

    var dismissKeyboard: () -> Void
    var screenshot: @MainActor () -> UIImage?

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
        generateUUID: @Sendable @escaping () -> UUID,
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
        DatabaseCompendium(
            databaseAccess: database.access,
            fallback: DndBeyondExternalCompendium()
        )
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
        let mailer = Mailer.liveValue

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
            canSendMail: mailer.canSendMail,
            sendMail: mailer.sendMail,
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
            generateUUID: { UUID() },
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
            crashReporter: CrashReporter.firebase,
            mechMuse: .live(db: database)
        )
    }

}

extension Database {
    static func live() async throws -> Database {
        let dbUrl = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")

        return try await Database(path: dbUrl.absoluteString)
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

extension Environment: EnvironmentWithModifierFormatter, EnvironmentWithMainQueue, EnvironmentWithDiceLog, EnvironmentWithMechMuse, EnvironmentWithDatabase, EnvironmentWithSendMail, EnvironmentWithCrashReporter, EnvironmentWithCompendium, EnvironmentWithCompendiumMetadata, EnvironmentWithRandomNumberGenerator, EnvironmentWithUUIDGenerator {

    var compendiumMetadata: CompendiumMetadata {
        CompendiumMetadata.live(database)
    }

}
