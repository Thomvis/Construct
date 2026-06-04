//
//  IdleTimerClient.swift
//  
//
//  Created during migration to swift-dependencies
//

import Foundation
import UIKit
import ComposableArchitecture

public struct IdleTimerClient {
    public var setIdleTimerDisabled: @MainActor (Bool) -> Void
    
    public init(setIdleTimerDisabled: @escaping @MainActor (Bool) -> Void) {
        self.setIdleTimerDisabled = setIdleTimerDisabled
    }
}

extension IdleTimerClient: DependencyKey {
    public static var liveValue: IdleTimerClient {
        IdleTimerClient(
            setIdleTimerDisabled: { isDisabled in
                UIApplication.shared.isIdleTimerDisabled = isDisabled
            }
        )
    }
}

public extension DependencyValues {
    var idleTimer: IdleTimerClient {
        get { self[IdleTimerClient.self] }
        set { self[IdleTimerClient.self] = newValue }
    }
}
