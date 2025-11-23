//
//  IdleTimerClient.swift
//  
//
//  Created during migration to swift-dependencies
//

import Foundation
import SwiftUI
import UIKit
import ComposableArchitecture

public struct IdleTimerClient {
    public var isIdleTimerDisabled: Binding<Bool>
    
    public init(isIdleTimerDisabled: Binding<Bool>) {
        self.isIdleTimerDisabled = isIdleTimerDisabled
    }
}

extension IdleTimerClient: DependencyKey {
    public static var liveValue: IdleTimerClient {
        IdleTimerClient(
            isIdleTimerDisabled: Binding<Bool>(
                get: { UIApplication.shared.isIdleTimerDisabled },
                set: { UIApplication.shared.isIdleTimerDisabled = $0 }
            )
        )
    }
}

public extension DependencyValues {
    var idleTimer: IdleTimerClient {
        get { self[IdleTimerClient.self] }
        set { self[IdleTimerClient.self] = newValue }
    }
}

