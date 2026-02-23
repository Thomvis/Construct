//
//  ScreenshotClient.swift
//  
//
//  Created during migration to swift-dependencies
//

import Foundation
import UIKit
import ComposableArchitecture

public struct ScreenshotClient {
    public var screenshot: @MainActor () -> UIImage?
    
    public init(screenshot: @escaping @MainActor () -> UIImage?) {
        self.screenshot = screenshot
    }
}

extension ScreenshotClient: DependencyKey {
    @MainActor
    public static var liveValue: ScreenshotClient {
        let keyWindow = {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .filter(\.isKeyWindow)
                .first
        }
        
        return ScreenshotClient(
            screenshot: {
                guard let window = keyWindow() else { return nil }
                
                UIGraphicsBeginImageContextWithOptions(window.frame.size, true, 0.0)
                defer { UIGraphicsEndImageContext() }
                
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                return UIGraphicsGetImageFromCurrentImageContext()
            }
        )
    }
}

public extension DependencyValues {
    var screenshot: ScreenshotClient {
        get { self[ScreenshotClient.self] }
        set { self[ScreenshotClient.self] = newValue }
    }
}

