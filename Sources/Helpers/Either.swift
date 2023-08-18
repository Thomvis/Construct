//
//  Either.swift
//  
//
//  Created by Thomas Visser on 15/06/2023.
//

import Foundation

public enum Either<Left, Right> {
    case left(Left)
    case right(Right)

    public var leftValue: Left? {
        if case .left(let left) = self {
            return left
        }
        return nil
    }

    public var rightValue: Right? {
        if case .right(let right) = self {
            return right
        }
        return nil
    }
}

extension Either: Decodable where Left: Decodable, Right: Decodable {
    public init(from decoder: Decoder) throws {
        do {
            let left = try Left(from: decoder)
            self = .left(left)
        } catch let leftError {
            do {
                let right = try Right(from: decoder)
                self = .right(right)
            } catch let rightError {
                throw EitherDecodableError(errors: [leftError, rightError])
            }
        }
    }
}

struct EitherDecodableError: Swift.Error {
    let errors: [Swift.Error]
}
