//
//  Extensions.swift
//  Construct
//
//  Created by Thomas Visser on 21/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture
import Tagged

extension Optional where Wrapped: View {
    func replaceNilWith<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Group {
            if self != nil {
                unsafelyUnwrapped
            } else {
                content()
            }
        }
    }
}

extension NumberFormatter {
    func stringWithFallback(for obj: Any) -> String {
        return string(for: obj) ?? "\(obj)"
    }
}

extension State: Identifiable where Value: Identifiable {
    public var id: Value.ID {
        wrappedValue.id
    }
}

extension View {
    var eraseToAnyView: AnyView {
        AnyView(self)
    }
}

extension RandomNumberGenerator {
    mutating func randomInt(in range: ClosedRange<Int>) -> Int {
        let r = next()
        return range.lowerBound + Int(r.remainderReportingOverflow(dividingBy: UInt64(range.upperBound)).partialValue)
    }
}

extension String {
    // returns nil if self is empty
    var nonEmptyString: String? {
        isEmpty ? nil : self
    }

    var suffixes: [String] {
        indices.map { String(self[$0...]) }
    }

    // Adds an ellipsis if the string is longer than maxLength. In that case, the result is maxLength+1 long
    func truncated(_ maxLength: Int) -> String {
        return self.count <= maxLength ? self : self.prefix(maxLength) + "…"
    }
}

extension Optional where Wrapped == String {
    var nonNilString: String {
        self ?? ""
    }
}

extension Optional {
    var nonNilArray: [Wrapped] {
        map { [$0] } ?? []
    }
}

extension Array where Element: Identifiable {
    public subscript(id id: Element.ID) -> Element? {
        get {
            first { $0.id == id }
        }
        set {
            let idx = firstIndex(where: { $0.id == id })
            if let value = newValue, let idx = idx {
                self[idx] = value
            } else if let idx = idx {
                self.remove(at: idx)
            } else if let value = newValue {
                self.append(value)
            }
        }
    }
}

extension Array {
    var single: Element? {
        return count == 1 ? self[0] : nil
    }

    var nonEmptyArray: Self? {
        isEmpty ? nil : self
    }
}

extension Publisher {
    public func delaySubscription<S>(for interval: S.SchedulerTimeType.Stride, tolerance: S.SchedulerTimeType.Stride? = nil, scheduler: S, options: S.SchedulerOptions? = nil) -> AnyPublisher<Output, Failure> where S : Scheduler {
        Just(1).setFailureType(to: Failure.self).delay(for: interval, tolerance: tolerance, scheduler: scheduler, options: options).flatMap { _ in
            self
        }.eraseToAnyPublisher()
    }

    public func ensureMinimumIntervalUntilFirstOutput<S>(_ interval: S.SchedulerTimeType.Stride, tolerance: S.SchedulerTimeType.Stride? = nil, scheduler: S, options: S.SchedulerOptions? = nil) -> AnyPublisher<Output, Failure> where S : Scheduler {

        let delay = Just(0)
            .delay(for: interval, tolerance: tolerance, scheduler: scheduler, options: options)
            .setFailureType(to: Failure.self)

        return combineLatest(delay)
            .map { o, _ in o }
            .eraseToAnyPublisher()
    }
}

extension Int {
    func times(_ f: () -> Void) {
        for _ in 0..<self {
            f()
        }
    }
}

protocol OptionalProtocol {
    associatedtype Wrapped

    static func emptyOptional() -> Self
    var optional: Optional<Wrapped> { get }
}

extension Optional: OptionalProtocol {
    static func emptyOptional() -> Optional<Wrapped> {
        return Self.none
    }

    var optional: Optional<Wrapped> { self }
}

extension Reducer {
    static func withState(_ changed: @escaping (State, State) -> Bool, _ reducer: @escaping (State) -> Reducer<State, Action, Environment>) -> Reducer<State, Action, Environment> {
        var innerReducer: Reducer<State, Action, Environment>?
        var innerReducerState: State?
        return Reducer { state, action, environment in
            if let innerReducerState = innerReducerState, !changed(innerReducerState, state) {
                return innerReducer?(&state, action, environment) ?? .none
            }

            let newReducer = reducer(state)
            innerReducer = newReducer
            innerReducerState = state
            return newReducer(&state, action, environment)
        }
    }

    static func withState<Key>(_ key: @escaping (State) -> Key, _ reducer: @escaping (State) -> Reducer<State, Action, Environment>) -> Reducer<State, Action, Environment> where Key: Equatable {
        withState({ lhs, rhs in key(lhs) != key(rhs) }, reducer)
    }

    static func lazy(_ reducer: @escaping @autoclosure () -> Self) -> Reducer<State, Action, Environment> {
        var innerReducer: Reducer<State, Action, Environment>?
        return Reducer { state, action, environment in
            if let r = innerReducer {
                return r(&state, action, environment)
            } else {
                let newReducer = reducer()
                innerReducer = newReducer
                return newReducer(&state, action, environment)
            }
        }
    }

    public func pullback<GlobalState, GlobalAction>(
        state toLocalState: WritableKeyPath<GlobalState, State>,
        action toLocalAction: CasePath<GlobalAction, Action>
    ) -> Reducer<GlobalState, GlobalAction, Environment> {
        pullback(state: toLocalState, action: toLocalAction, environment: { $0 })
    }

    // From https://github.com/pointfreeco/isowords/blob/244925184babddd477d637bdc216fb34d1d8f88d/Sources/TcaHelpers/OnChange.swift#L4
    public func onChange<LocalState>(
        of toLocalState: @escaping (State) -> LocalState,
        perform additionalEffects: @escaping (LocalState, inout State, Action, Environment) -> Effect<
        Action, Never
        >
    ) -> Self where LocalState: Equatable {
        .init { state, action, environment in
            let previousLocalState = toLocalState(state)
            let effects = self.run(&state, action, environment)
            let localState = toLocalState(state)

            return previousLocalState != localState
            ? .merge(effects, additionalEffects(localState, &state, action, environment))
            : effects
        }
    }
}

extension CasePath {
    init(embed: CasePath<Root, Any>, extract: KeyPath<Root, Value?>) {
        self.init(embed: embed.embed, extract: { $0[keyPath: extract] })
    }
}

extension Result {
    var value: Success? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    var error: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

func optionalCompare<O>(_ lhs: O, _ rhs: O, compare: (O.Wrapped, O.Wrapped) -> Bool) -> Bool where O: OptionalProtocol {
    switch (lhs.optional, rhs.optional) {
    case (nil, nil): return true
    case (let lhs?, let rhs?): return compare(lhs, rhs)
    default: return false
    }
}

extension Bool {
    func toggled() -> Bool {
        !self
    }

    func mapTrue<T>(_ f: () -> T) -> T? {
        self ? f() : nil
    }

    func compactMapTrue<T>(_ f: () -> T?) -> T? {
        self ? f() : nil
    }
}

extension Optional where Wrapped: Equatable {
    // If self contains value, self is made nil
    // Otherwise: self becomes .some(value)
    mutating func toggle(_ value: Wrapped) {
        if self == value {
            self = .none
        } else {
            self = value
        }
    }

    func toggled(_ value: Wrapped) -> Self {
        var res = self
        res.toggle(value)
        return res
    }
}

// From https://fivestars.blog/swiftui/conditional-modifiers.html
extension View {

    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func ifLet<V, Transform: View>(
        _ value: V?,
        transform: (Self, V) -> Transform
    ) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

extension Text {
    func ifLet<V>(
        _ value: V?,
        transform: (Self, V) -> Text
    ) -> Text {
        if let value = value {
            return transform(self, value)
        } else {
            return self
        }
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow((point.x - x), 2) + pow((point.y - y), 2))
    }

    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    func offset(dx: CGFloat = 0, dy: CGFloat = 0) -> CGPoint {
        return CGPoint(x: x + dx, y: y + dy)
    }

    init(_ size: CGSize) {
        self = CGPoint(x: size.width, y: size.height)
    }
}

extension UUID {
    func tagged<Tag>() -> Tagged<Tag, UUID> {
        Tagged(rawValue: self)
    }
}

extension AttributedString {
    mutating func apply<V>(_ located: Located<V>, _ f: (inout AttributedSubstring, V) -> Void) {
        let start = index(startIndex, offsetByCharacters: located.range.startIndex)
        let end = index(startIndex, offsetByCharacters: located.range.endIndex)
        f(&self[start..<end], located.value)
    }
}

extension AttributedStringProtocol {
    var underlinedLink: URL? {
        get {
            self.link
        }
        set {
            if let newValue = newValue {
                self.link = newValue
                self.underlineStyle = .single
            } else {
                self.link = nil
                self.underlineStyle = nil
            }
        }
    }
}

extension Deferred {

    /// Creates a new result by evaluating a throwing closure, capturing the
    /// returned value as a success, or any thrown error as a failure.
    ///
    /// - Parameter body: A throwing closure to evaluate.
    public init<O>(catching body: @escaping () throws -> O) where DeferredPublisher == AnyPublisher<O, Error> {
        self.init(createPublisher: {
            do {
                let result = try body()
                return Just(result).setFailureType(to: Error.self).eraseToAnyPublisher()
            } catch {
                return Fail(error: error).eraseToAnyPublisher()
            }
        })
    }
}

extension View {
    func italic(_ active: Bool = true) -> some View {
        transformEnvironment(\.font) { f in
            if active {
                f = (f ?? .body).italic()
            }
        }
    }
}
