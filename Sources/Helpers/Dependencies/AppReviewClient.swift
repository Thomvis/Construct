//
//  AppReviewClient.swift
//  
//
//  Created during migration to swift-dependencies
//

import Foundation
import StoreKit
import UIKit
import ComposableArchitecture

public struct AppReviewClient {
    public var rateInAppStore: () -> Void
    public var requestAppStoreReview: () -> Void
    
    public init(
        rateInAppStore: @escaping () -> Void,
        requestAppStoreReview: @escaping () -> Void
    ) {
        self.rateInAppStore = rateInAppStore
        self.requestAppStoreReview = requestAppStoreReview
    }
}

extension AppReviewClient: DependencyKey {
    public static var liveValue: AppReviewClient {
        let appID = 1490015210
        
        let keyWindow = {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .filter(\.isKeyWindow)
                .first
        }
        
        return AppReviewClient(
            rateInAppStore: {
                let url = "https://itunes.apple.com/app/id\(appID)?action=write-review"
                UIApplication.shared.open(URL(string: url)!, options: [:], completionHandler: nil)
            },
            requestAppStoreReview: {
                if let windowScene = keyWindow()?.windowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
        )
    }
}

public extension DependencyValues {
    var appReview: AppReviewClient {
        get { self[AppReviewClient.self] }
        set { self[AppReviewClient.self] = newValue }
    }
}

