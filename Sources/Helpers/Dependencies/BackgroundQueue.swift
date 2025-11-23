//
//  BackgroundQueue.swift
//  
//
//  Created during migration to swift-dependencies
//

import Foundation
import CombineSchedulers
import ComposableArchitecture

enum BackgroundQueueKey: DependencyKey {
    public static var liveValue: AnySchedulerOf<DispatchQueue> {
        DispatchQueue.global(qos: .userInitiated).eraseToAnyScheduler()
    }
}

public extension DependencyValues {
    var backgroundQueue: AnySchedulerOf<DispatchQueue> {
        get { self[BackgroundQueueKey.self] }
        set { self[BackgroundQueueKey.self] = newValue }
    }
}

