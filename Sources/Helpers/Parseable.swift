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
public struct Parseable<Input, Result> {

    public var input: Input
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

    public var projectedValue: Self? {
        self
    }

    public mutating func parseIfNeeded<Parser>(parser: Parser.Type) where Parser: DomainParser, Parser.Input == Input, Parser.Result == Result {
        guard result?.version != Parser.version || result?.parserName != String(describing: parser) else { return }
        var result = ParserResult(
            value: Parser.parse(input: input),
            version: Parser.version
        )
        result.parserName = String(describing: parser)
        self.result = result
    }

    public struct ParserResult {
        public let value: Result?
        @DecodableDefault.EmptyString public var parserName: String
        let version: String
    }

}

public protocol DomainParser {
    associatedtype Input
    associatedtype Result

    static var version: String { get }
    static func parse(input: Input) -> Result?
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
                assertionFailure("Parseable result could not be decoded. Did \(Result.self) change in a breaking way?")
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

extension Parseable.ParserResult: Codable where Result: Codable { }

extension Parseable: Equatable where Input: Equatable, Result: Equatable { }

extension Parseable.ParserResult: Equatable where Result: Equatable { }

extension Parseable: Hashable where Input: Hashable, Result: Hashable { }

extension Parseable.ParserResult: Hashable where Result: Hashable { }

public enum ParseableVisitorAction {
    case visit
}

public typealias ParseableVisitor<T> = Reducer<T, ParseableVisitorAction, Void>

extension ParseableVisitor where Action == ParseableVisitorAction, Environment == Void {
    public init(visit: @escaping (inout State) -> Void) {
        self.init { state, action, env in
            visit(&state)
            return .none
        }
    }

    public func visitEach<ID, Global>(in toCollection: WritableKeyPath<Global, IdentifiedArray<ID, State>>) -> ParseableVisitor<Global> {
        return ParseableVisitor<Global> { state, action, env in
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
    mutating func visitParseable()
}

public protocol HasParseableVisitor: ParseableVisitable {
    static var parseableVisitor: ParseableVisitor<Self> { get }
}

extension ParseableVisitable where Self: HasParseableVisitor {
    public mutating func visitParseable() {
        _ = Self.parseableVisitor.run(&self, .visit, ())
    }
}
