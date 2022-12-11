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
    public func replaceNilWith<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Group {
            if self != nil {
                unsafelyUnwrapped
            } else {
                content()
            }
        }
    }
}

public extension NumberFormatter {
    func stringWithFallback(for obj: Any) -> String {
        return string(for: obj) ?? "\(obj)"
    }
}

extension State: Identifiable where Value: Identifiable {
    public var id: Value.ID {
        wrappedValue.id
    }
}

public extension View {
    var eraseToAnyView: AnyView {
        AnyView(self)
    }
}

public extension RandomNumberGenerator {
    mutating func randomInt(in range: ClosedRange<Int>) -> Int {
        let r = next()
        return range.lowerBound + Int(r.remainderReportingOverflow(dividingBy: UInt64(range.upperBound)).partialValue)
    }
}

public extension String {
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
    public var nonNilString: String {
        self ?? ""
    }
}

extension Optional {
    public var nonNilArray: [Wrapped] {
        map { [$0] } ?? []
    }

    public var optionalArray: [Wrapped]? {
        map { [$0] } ?? nil
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

public extension Array {
    var single: Element? {
        return count == 1 ? self[0] : nil
    }

    var nonEmptyArray: Self? {
        isEmpty ? nil : self
    }
}

public extension Publisher {
    func delaySubscription<S>(for interval: S.SchedulerTimeType.Stride, tolerance: S.SchedulerTimeType.Stride? = nil, scheduler: S, options: S.SchedulerOptions? = nil) -> AnyPublisher<Output, Failure> where S : Scheduler {
        Just(1).setFailureType(to: Failure.self).delay(for: interval, tolerance: tolerance, scheduler: scheduler, options: options).flatMap { _ in
            self
        }.eraseToAnyPublisher()
    }

    func ensureMinimumIntervalUntilFirstOutput<S>(_ interval: S.SchedulerTimeType.Stride, tolerance: S.SchedulerTimeType.Stride? = nil, scheduler: S, options: S.SchedulerOptions? = nil) -> AnyPublisher<Output, Failure> where S : Scheduler {

        let delay = Just(0)
            .delay(for: interval, tolerance: tolerance, scheduler: scheduler, options: options)
            .setFailureType(to: Failure.self)

        return combineLatest(delay)
            .map { o, _ in o }
            .eraseToAnyPublisher()
    }
}

public extension Int {
    func times(_ f: () -> Void) {
        for _ in 0..<self {
            f()
        }
    }
}

public protocol OptionalProtocol {
    associatedtype Wrapped

    init(_ value: Wrapped)
    static func emptyOptional() -> Self
    var optional: Optional<Wrapped> { get }
}

extension Optional: OptionalProtocol {
    public static func emptyOptional() -> Optional<Wrapped> {
        return Self.none
    }

    public var optional: Optional<Wrapped> { self }
}

public extension Reducer {
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

    func pullback<GlobalState, GlobalAction>(
        state toLocalState: WritableKeyPath<GlobalState, State>,
        action toLocalAction: CasePath<GlobalAction, Action>
    ) -> Reducer<GlobalState, GlobalAction, Environment> {
        pullback(state: toLocalState, action: toLocalAction, environment: { $0 })
    }

    // From https://github.com/pointfreeco/isowords/blob/244925184babddd477d637bdc216fb34d1d8f88d/Sources/TcaHelpers/OnChange.swift#L4
    func onChange<LocalState>(
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

    /// Equivalent to TCA's `optional()` except that `ifSome()` silently does nothing if the state is nil
    func ifSome() -> Reducer<State?, Action, Environment> {
        .init { state, action, environment in
            guard state != nil else {
                return .none
            }
            return self(&state!, action, environment)
        }
    }
}

public extension CasePath {
    init(embed: CasePath<Root, Any>, extract: KeyPath<Root, Value?>) {
        self.init(embed: embed.embed, extract: { $0[keyPath: extract] })
    }
}

public extension Result {
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

public func optionalCompare<O>(_ lhs: O, _ rhs: O, compare: (O.Wrapped, O.Wrapped) -> Bool) -> Bool where O: OptionalProtocol {
    switch (lhs.optional, rhs.optional) {
    case (nil, nil): return true
    case (let lhs?, let rhs?): return compare(lhs, rhs)
    default: return false
    }
}

public extension Bool {
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
    public mutating func toggle(_ value: Wrapped) {
        if self == value {
            self = .none
        } else {
            self = value
        }
    }

    public func toggled(_ value: Wrapped) -> Self {
        var res = self
        res.toggle(value)
        return res
    }
}

// From https://fivestars.blog/swiftui/conditional-modifiers.html
public extension View {

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

public extension Text {
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

public extension CGPoint {
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

public extension UUID {
    func tagged<Tag>() -> Tagged<Tag, UUID> {
        Tagged(rawValue: self)
    }
}

public extension AttributedString {
    mutating func apply<V>(_ located: Located<V>, _ f: (inout AttributedSubstring, V) -> Void) {
        let start = index(startIndex, offsetByCharacters: located.range.startIndex)
        let end = index(startIndex, offsetByCharacters: located.range.endIndex)
        f(&self[start..<end], located.value)
    }
}

public extension AttributedStringProtocol {
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

public extension Deferred {

    /// Creates a new result by evaluating a throwing closure, capturing the
    /// returned value as a success, or any thrown error as a failure.
    ///
    /// - Parameter body: A throwing closure to evaluate.
    init<O>(catching body: @escaping () throws -> O) where DeferredPublisher == AnyPublisher<O, Error> {
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

public extension View {
    func italic(_ active: Bool = true) -> some View {
        transformEnvironment(\.font) { f in
            if active {
                f = (f ?? .body).italic()
            }
        }
    }
}

public extension View {
    func menu(@ViewBuilder content: @escaping () -> some View, primaryAction: @escaping () -> Void) -> some View {
        Menu(content: content, label: { self }, primaryAction: primaryAction)
    }
}

public extension Binding {
    func withDefault(_ defaultValue: Value.Wrapped) -> Binding<Value.Wrapped> where Value: OptionalProtocol, Value.Wrapped: Equatable {
        Binding<Value.Wrapped>(get: {
            wrappedValue.optional ?? defaultValue
        }, set: { value, transaction in
            guard wrappedValue.optional != defaultValue || value != defaultValue else { return }
            self.transaction(transaction).wrappedValue = Value(value)
        })
    }
}

public extension AsyncSequence {
    /// Hides the specific type of the AsyncSequence (e.g. AsyncMapSequence)
    var stream: AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream(self)
    }

    var first: Element? {
        get async throws {
            try await self.first(where: { _ in true })
        }
    }
}

public extension Sequence where Element: Identifiable {
    var identified: IdentifiedArrayOf<Element> {
        IdentifiedArrayOf(uniqueElements: self)
    }
}

public extension Optional where Wrapped == String {
    func wrap(prefix: String = "", suffix: String = "") -> String {
        map { "\(prefix)\($0)\(suffix)"} ?? ""
    }
}

public extension String {
    func with(_ str: String?, suffix: String = "") -> String {
        str.wrap(prefix: self, suffix: suffix)
    }
}
