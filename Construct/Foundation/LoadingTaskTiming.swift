//
//  LoadingTaskTiming.swift
//  Construct
//
//  Created by Thomas Visser on 08/12/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

enum LoadingTaskTiming: Equatable {
    case immediate
    case gracePeriodEnded
    case minimumLoadDurationEnded
}

enum LoadingTaskState<Value> {
    case finishedImmediately(Value) // finished before grace period ended
    case showProgressView
    case finishedAfterMinimumLoadDuration(Value)

    var value: Value? {
        switch self {
        case .finishedImmediately(let v): return v
        case .showProgressView: return nil
        case .finishedAfterMinimumLoadDuration(let v): return v
        }
    }
}

extension Publisher {

    /**
     This helps prevent showing a progress view for a very short duration for loading tasks of variable length.
     */
    func loadingTaskStates(graceInterval: DispatchTimeInterval = .milliseconds(200), minLoadInterval: DispatchTimeInterval = .seconds(1)) -> AnyPublisher<LoadingTaskState<Output>, Failure> {
        let timing = Just(LoadingTaskTiming.minimumLoadDurationEnded)
            .delay(for: .init(minLoadInterval) - .init(graceInterval), scheduler: DispatchQueue.main)
            .prepend(
                Just(LoadingTaskTiming.gracePeriodEnded)
                        .delay(for: .init(graceInterval), scheduler: DispatchQueue.main)
            )
            .prepend(Just(LoadingTaskTiming.immediate))
            .setFailureType(to: Failure.self)

        let work = self.print().receive(on: DispatchQueue.main).map(Optional.some).prepend(nil)

        return work.combineLatest(timing).compactMap { w, t in
            if let w = w, t == .immediate {
                return .finishedImmediately(w)
            } else if w == nil && t == .gracePeriodEnded {
                return .showProgressView
            } else if let w = w, t == .minimumLoadDurationEnded {
                return .finishedAfterMinimumLoadDuration(w)
            }
            return nil
        }
        .removeDuplicates { ($0.value == nil) == ($1.value == nil) }
        .eraseToAnyPublisher()
    }
}
