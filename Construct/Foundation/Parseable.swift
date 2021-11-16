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
struct Parseable<Input, Result, Parser> where Parser: DomainParser, Parser.Input == Input, Parser.Result == Result {

    var input: Input
    var result: ParserResult?

    var wrappedValue: Input {
        get { input }
        set {
            input = newValue
            result = nil
        }
    }

    init(input: Input) {
        self.input = input
    }

    var projectedValue: Result? {
        result?.value
    }

    mutating func parseIfNeeded() {
//        guard result?.version != Parser.version else { return }
        let result = ParserResult(value: Parser.parse(input: input), version: Parser.version)
        self.result = result
    }

    struct ParserResult {
        let value: Result?
        let version: String
    }

}

protocol DomainParser {
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

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

enum ParseableVisitorAction {
    case visit
    indirect case indexedVisit(AnyHashable, ParseableVisitorAction)
}

typealias ParseableVisitor<T> = Reducer<T, ParseableVisitorAction, Void>

extension ParseableVisitor {
    init(visit: @escaping (inout State) -> Void) {
        self.init { state, action, env in
            visit(&state)
            return .none
        }
    }
}

protocol HasParseableVisitor {
    //static var parseableVisitor: ParseableVisitor<Self> { get }

    mutating func visit()
}

protocol HasParseableVisitor2: HasParseableVisitor {
    static var parseableVisitor: ParseableVisitor<Self> { get }
}

extension HasParseableVisitor where Self: HasParseableVisitor2 {
    mutating func visit() {
        _ = Self.parseableVisitor.run(&self, .visit, ())
    }
}
