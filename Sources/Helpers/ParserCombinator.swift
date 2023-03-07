//
//  ParserCombinator.swift
//  Construct
//
//  Created by Thomas Visser on 23/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

// We need to use Swift.Character because Character is a thing in D&D too

let digits: [Swift.Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

public struct Remainder {
    public let original: [Swift.Character]
    public var position: Int
    public let endIndex: Int
}

// taken from https://gist.github.com/chriseidhof/4860a12bf36a48f28b55769db1004d95
extension Remainder: Collection {
    public func string() -> String {
        return String(original[position...])
    }

    mutating func next() -> Swift.Character? {
        guard position < endIndex else { return nil }
        let character = original[position]
        position = original.index(after: position)
        return character
    }

    public init(_ string: String) {
        original = Array(string)
        position = original.startIndex
        endIndex = original.endIndex
    }

    public typealias Index = Int

    public var startIndex: Index { return position }

    public subscript(index: Index) -> Swift.Character {
        return original[index]
    }

    public func index(after i: Index) -> Index {
        return original.index(after: i)
    }
}

public extension Remainder {
    // Returns and consumes the next character
    mutating func scanCharacter() -> Swift.Character? {
        return scanCharacter(condition: { _ in true })
    }

    // Returns the next character without consuming it
    mutating func peek() -> Swift.Character? {
        guard position < endIndex else { return nil }
        return original[position]
    }

    // Returns and consumes the next character if it meets the condition
    mutating func scanCharacter(condition: (Swift.Character) -> Bool) -> Swift.Character? {
        guard position < endIndex else { return nil }
        let character = original[position]
        guard condition(character) else {
            return nil
        }
        position = index(after: position)
        return character
    }

    mutating func scanString(_ str: String) -> String? {
        guard position.advanced(by: str.count) <= endIndex else { return nil }
        let nextCharacters = String(original[position..<position.advanced(by: str.count)])
        guard str == nextCharacters else {
            return nil
        }
        position = position.advanced(by: str.count)
        return str
    }
}

public struct Parser<A> {
    public let parse: (inout Remainder) -> A?
}

public func character(_ condition: @escaping (Swift.Character) -> Bool) -> Parser<Swift.Character> {
    return Parser { input in
        return input.scanCharacter(condition: condition)
    }
}

public func character(in s: [Swift.Character]) -> Parser<Swift.Character> {
    return character(s.contains)
}

public func char(_ c: Swift.Character) -> Parser<Swift.Character> {
    return character { s in s == c }
}

public func digit() -> Parser<Swift.Character> {
    return character(in: digits)
}

public func string(_ str: String) -> Parser<String> {
    return Parser { input in
        return input.scanString(str)
    }
}

public func any<A>(_ p: Parser<A>) -> Parser<[A]> {
    return Parser { input in
        var res: [A] = []
        while let e = p.parse(&input) {
            res.append(e)
        }
        return res
    }
}

public func oneOrMore<A>(_ p: Parser<A>) -> Parser<[A]> {
    any(p).flatMap { $0.nonEmptyArray }
}

public func remainder() -> Parser<String> {
    return Parser { input in
        defer { input.position = input.endIndex }
        return input.string()
    }
}

public func end() -> Parser<Void> {
    return Parser { input in
        guard input.isEmpty else { return nil }
        return ()
    }
}

/**
 Skips all input until the given parser succeeds. If parser never succeeds, the skipping also fails.
 Upon success, all input up to and including the input by the given parser is consumed.

 The returned parser succeeds with the skipped string (excluding what the given parser parsed)
 and the resulting value of the given parser.
 */
public func skip<A>(until parser: Parser<A>) -> Parser<(String, A)> {
    return Parser { input in
        let initialPosition = input.position
        var res = parser.parse(&input)
        var preParsePosition = input.position
        while res == nil && !input.isEmpty {
            input.position += 1
            preParsePosition = input.position
            res = parser.parse(&input)
        }

        if let res = res {
            return (String(input.original[initialPosition..<preParsePosition]), res)
        } else {
            input.position = initialPosition
            return nil
        }
    }
}

public extension Parser {
    func run(_ string: String) -> A? {
        var remainder = Remainder(string)
        return parse(&remainder)
    }

    func matches(`in` string: String) -> [Located<A>] {
        any(withRange().skippingAnyBefore().map { (value, range) in
            Located(value: value, range: Range(range))
        }).run(string) ?? []
    }

    func map<B>(_ transform: @escaping (A) -> B) -> Parser<B> {
        return Parser<B> { input in
            return self.parse(&input).map(transform)
        }
    }

    func flatMap<B>(_ transform: @escaping (A) -> B?) -> Parser<B> {
        return Parser<B> { input in
            return self.parse(&input).flatMap(transform)
        }.attempt()
    }

    func attempt() -> Parser<A> {
        return Parser { input in
            let position = input.position
            if let result = parse(&input) { return result }
            input.position = position
            return nil
        }
    }

    func followed<B>(by p: Parser<B>) -> Parser<(A, B)> {
        return Parser<(A, B)> { input in
            return parse(&input).flatMap { a in
                p.parse(&input).map { b in
                    (a, b)
                }
            }
        }.attempt()
    }

    func or(_ p: Parser<A>) -> Parser<A> {
        return Parser { input in
            return self.parse(&input) ?? p.parse(&input)
        }
    }

    func optional() -> Parser<A?> {
        return Parser<A?> { input in
            guard let a = self.parse(&input) else { return .some(.none) }
            return .some(a)
        }
    }

    func skippingAnyBefore() -> Parser<A> {
        skip(until: self).map { $0.1 }
    }

    /**
     Parses a sequence of p?, self, p? (throwing away the results of p)
     */
    func trimming<B>(_ p: Parser<B>) -> Parser<A> {
        zip(p.optional(), self, p.optional()).map { _, s, _ in s }
    }

    func log(_ id: String) -> Parser<A> {
        #if !DEBUG
        return self
        #else
        return Parser<A> { input in
            let position = input.position
            let res = self.parse(&input)

            if let res = res {
                print("Parser[\(id)]: parsed '\(String(input.original[position..<input.position]))' into '\(res)' at pos \(position), remainder: '\(input.string().truncated(40))'")
            } else {
                print("Parser[\(id)]: failed at pos \(position), remainder '\(input.string().truncated(40))'")
            }

            return res
        }
        #endif
    }

    func withRange() -> Parser<(A, ClosedRange<Int>)> {
        return Parser<(A, ClosedRange<Int>)> { input in
            let position = input.position
            if let res = self.parse(&input) {
                return (res, ClosedRange(uncheckedBounds: (position, input.position-1)))
            }
            return nil
        }
    }

    static var never: Parser<Void> {
        Parser<Void> { _ in nil }
    }

    static var nothing: Parser<Void> {
        Parser<Void> { _ in () }
    }

//    func ignoring(_ cc: CharacterSet) -> Parser<A> {
//        return Parser { input in
//            var positionMap: [Int: Int] = [:]
//            var filtered: [Unicode.Scalar] = []
//
//            for (i, us) in input.string.unicodeScalars.enumerated() {
//                guard !cc.contains(us) else {
//                    continue
//                }
//                positionMap[filtered.count] = i
//                filtered.append(us)
//            }
//
//            return self.parse(String(String.UnicodeScalarView(filtered))).map {
//                if $0.1.isEmpty {
//                    return $0
//                } else {
//                    return ($0.0, String(str.unicodeScalars[str.index(str.startIndex, offsetBy: positionMap[filtered.count - $0.1.count]!)...]))
//                }
//            }
//        }
//    }
}

public extension Parser where A: Sequence, A.Element: CustomStringConvertible {
    func joined(separator: String = "") -> Parser<String> {
        return map { res in
            return res.map { e in String(describing: e) }.joined(separator: separator)
        }
    }
}

fileprivate let intNumberFormatter = apply(NumberFormatter()) { f in
    f.locale = Locale(identifier: "en_US")
}

public extension Parser where A == String {
    func toInt() -> Parser<Int> {
        return flatMap { str -> Int? in
            return intNumberFormatter.number(from: str)?.intValue
        }
    }
}

public func int() -> Parser<Int> {
    return any(character(in: digits)).joined().toInt()
}

// Parses any number of alphanumeric characters or quotes
public func word() -> Parser<String> {
    return any(character { $0.isLetter || $0.isNumber || "'＇’".contains(String($0)) })
        .flatMap { $0.count > 0 ? $0 : nil }
        .joined()
}

public func whitespace() -> Parser<String> {
    oneOrMore(either(horizontalWhitespace(), verticalWhitespace())).joined()
}

public func horizontalWhitespace() -> Parser<String> {
    oneOrMore(character(in: [" ", "\t"])).joined()
}

public func verticalWhitespace() -> Parser<String> {
    oneOrMore(character(in: ["\r", "\n"])).joined()
}

public func many<E, D, T>(
    element: Parser<E>,
    separator: Parser<D>,
    terminator: Parser<T>
) -> Parser<[E]> {
    return Parser { remainder in
        var result: [E] = []
        var previous = remainder.position
        while true {
            if let elem = element.attempt().parse(&remainder) {
                result.append(elem)
            } else {
                // undo parsing a dangling separator
                remainder.position = previous
                break
            }
            previous = remainder.position

            if separator.attempt().parse(&remainder) == nil {
                break
            }
        }
        guard terminator.parse(&remainder) != nil else {
            return nil
        }
        return result
    }
}

public func either<A>(_ a: Parser<A>, _ b: Parser<A>) -> Parser<A> {
    a.or(b)
}

public func either<A>(_ a: Parser<A>, _ b: Parser<A>, _ c: Parser<A>) -> Parser<A> {
    a.or(b).or(c)
}

public func either<A>(_ a: Parser<A>, _ b: Parser<A>, _ c: Parser<A>, _ d: Parser<A>) -> Parser<A> {
    a.or(b).or(c).or(d)
}

public func either<A>(_ a: Parser<A>, _ b: Parser<A>, _ c: Parser<A>, _ d: Parser<A>, _ e: Parser<A>) -> Parser<A> {
    a.or(b).or(c).or(d).or(e)
}

public func either<A>(_ a: Parser<A>, _ b: Parser<A>, _ c: Parser<A>, _ d: Parser<A>, _ e: Parser<A>, _ f: Parser<A>) -> Parser<A> {
    a.or(b).or(c).or(d).or(e).or(f)
}

public func zip<A, B>(_ a: Parser<A>, _ b: Parser<B>) -> Parser<(A, B)> {
    a.followed(by: b)
}

public func zip<A, B, C>(_ a: Parser<A>, _ b: Parser<B>, _ c: Parser<C>) -> Parser<(A, B, C)> {
    a.followed(by: b).followed(by: c).map { ($0.0, $0.1, $1) }
}

public func zip<A, B, C, D>(_ a: Parser<A>, _ b: Parser<B>, _ c: Parser<C>, _ d: Parser<D>) -> Parser<(A, B, C, D)> {
    zip(a, b, c).followed(by: d).map { ($0.0.0, $0.0.1, $0.0.2, $0.1) }
}

public func zip<A, B, C, D, E>(_ a: Parser<A>, _ b: Parser<B>, _ c: Parser<C>, _ d: Parser<D>, _ e: Parser<E>) -> Parser<(A, B, C, D, E)> {
    zip(a, b, c, d).followed(by: e).map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.1) }
}

public func zip<A, B, C, D, E, F>(_ a: Parser<A>, _ b: Parser<B>, _ c: Parser<C>, _ d: Parser<D>, _ e: Parser<E>, _ f: Parser<F>) -> Parser<(A, B, C, D, E, F)> {
    zip(a, b, c, d, e).followed(by: f).map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1) }
}

public func zip<A, B, C, D, E, F, G>(_ a: Parser<A>, _ b: Parser<B>, _ c: Parser<C>, _ d: Parser<D>, _ e: Parser<E>, _ f: Parser<F>, _ g: Parser<G>) -> Parser<(A, B, C, D, E, F, G)> {
    zip(a, b, c, d, e, f).followed(by: g).map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.1) }
}
