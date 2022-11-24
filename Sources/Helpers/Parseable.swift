//
//  ParseableText.swift
//  Construct
//
//  Created by Thomas Visser on 08/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

@propertyWrapper
public struct Parseable<Input, Result> where Input: Equatable, Result: DomainModel {

    public var input: Input {
        didSet {
            if oldValue != input {
                result = nil
            }
        }
    }
    public var result: ParserResult?

    public var wrappedValue: Input {
        get { input }
        set {
            input = newValue
            result = nil
        }
    }

    public init(input: Input) {
        self.input = input
    }

    public init(input: Input, result: ParserResult) {
        self.input = input
        self.result = result
    }

    public var projectedValue: Self? {
        self
    }

    /// Returns true if parsing was needed
    public mutating func parseIfNeeded<Parser>(parser: Parser.Type) -> Bool where Parser: DomainParser, Parser.Input == Input, Parser.Result == Result {
        guard result?.version != Parser.version ||
                result?.modelVersion != Result.version ||
                result?.parserName != String(describing: parser)
        else { return false }

        self.result = ParserResult(
            value: Parser.parse(input: input),
            parserName: String(describing: parser),
            version: Parser.version,
            modelVersion: Result.version
        )

        return true
    }

    public struct ParserResult {
        public let value: Result?
        @DecodableDefault.EmptyString public var parserName: String
        let version: String
        @DecodableDefault.EmptyString public var modelVersion: String

        public init(value: Result?, parserName: String, version: String, modelVersion: String) {
            self.value = value
            self.parserName = parserName
            self.version = version
            self.modelVersion = modelVersion
        }
    }

}

public protocol DomainParser {
    associatedtype Input
    associatedtype Result

    /// Update the version when making a change to the parser that changes its output
    /// This causes the app to recompute all (relevant) values on launch
    static var version: String { get }
    static func parse(input: Input) -> Result?
}

public protocol DomainModel {
    /// Update the version when making a change to the model that changes the codable implementation
    /// and/or requires recomputation from the input
    /// This causes the app to recompute all (relevant) values on launch
    static var version: String { get }
}

extension Parseable: Codable where Input: Codable, Result: Codable {
    enum CodingKeys: CodingKey {
        case input
        case result
    }

    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.input = try container.decode(Input.self, forKey: .input)
            do {
                self.result = try container.decodeIfPresent(ParserResult.self, forKey: .result)
            } catch {
                let resultContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .result)
                // Only if the model version changed, it is expected that the result can't be decoded
                if ParserResult.modelVersion(from: resultContainer) == Result.version {
                    assertionFailure("Parseable result could not be decoded. Did \(Result.self) change in a breaking way?: \(error)")
                }
                self.result = nil
            }
        } catch {
            // Fallback for backward compatibility
            let container = try decoder.singleValueContainer()
            self.input = try container.decode(Input.self)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(input, forKey: .input)
        try container.encode(result, forKey: .result)
    }
}

extension Parseable.ParserResult {
    static func modelVersion(from container: KeyedDecodingContainer<AnyCodingKey>) -> String? {
        try? container.decode(String.self, forKey: AnyCodingKey(stringValue: "modelVersion"))
    }
}

extension Parseable.ParserResult: Codable where Result: Codable { }

extension Parseable: Equatable where Input: Equatable, Result: Equatable { }

extension Parseable.ParserResult: Equatable where Result: Equatable { }

extension Parseable: Hashable where Input: Hashable, Result: Hashable { }

extension Parseable.ParserResult: Hashable where Result: Hashable { }

public enum ParseableVisitorAction {
    case visit
    case didParse
}

public typealias ParseableVisitor<T> = Reducer<T, ParseableVisitorAction, Void>

extension ParseableVisitor where Action == ParseableVisitorAction, Environment == Void {
    public init(visit: @escaping (inout State) -> Bool) {
        self.init { state, action, env in
            assert(action == .visit)
            return visit(&state) ? Effect(value: .didParse) : .none
        }
    }

    public func visitEach<ID, Global>(in toCollection: WritableKeyPath<Global, IdentifiedArray<ID, State>>) -> ParseableVisitor<Global> {
        return ParseableVisitor<Global> { state, action, env in
            assert(action == .visit)
            return .merge(
                state[keyPath: toCollection].ids
                    .map {
                        self.ifSome().run(
                            &state[keyPath: toCollection][id: $0],
                            ParseableVisitorAction.visit,
                            env
                        )
                    }
            )
        }
    }
}

public protocol ParseableVisitable {
    mutating func visitParseable() -> Effect<ParseableVisitorAction, Never>
}

public protocol HasParseableVisitor: ParseableVisitable {
    static var parseableVisitor: ParseableVisitor<Self> { get }
}

extension ParseableVisitable where Self: HasParseableVisitor {
    public mutating func visitParseable() -> Effect<ParseableVisitorAction, Never> {
        return Self.parseableVisitor.run(&self, .visit, ())
    }
}
