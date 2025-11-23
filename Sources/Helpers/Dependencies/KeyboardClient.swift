//
//  KeyboardClient.swift
//  
//
//  Created during migration to swift-dependencies
//

import Foundation
import UIKit
import ComposableArchitecture

public struct KeyboardClient {
    public var dismissKeyboard: () -> Void
    
    public init(dismissKeyboard: @escaping () -> Void) {
        self.dismissKeyboard = dismissKeyboard
    }
}

extension KeyboardClient: DependencyKey {
    public static var liveValue: KeyboardClient {
        let keyWindow = {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .filter(\.isKeyWindow)
                .first
        }
        
        return KeyboardClient(
            dismissKeyboard: {
                keyWindow()?.endEditing(true)
            }
        )
    }
}

public extension DependencyValues {
    var keyboard: KeyboardClient {
        get { self[KeyboardClient.self] }
        set { self[KeyboardClient.self] = newValue }
    }
}

