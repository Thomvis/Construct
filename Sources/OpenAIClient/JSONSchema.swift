//
//  JSONSchema.swift
//
//
//  Created by Thomas Visser on 08/09/2023.
//

import Foundation

public struct JSONSchema: Codable, Equatable {
    public var type: String
    public var description: String?
    public var properties: [String: JSONSchema]?
    public var required: [String]?
    public var `enum`: [String]?
}

public extension JSONSchema {
    static func object(description: String? = nil, properties: [String: JSONSchema], required: [String]) -> Self {
        JSONSchema(type: "object", description: description, properties: properties, required: required)
    }

    static func string(description: String? = nil, enum: [String]? = nil) -> Self {
        JSONSchema(type: "string", description: description, enum: `enum`)
    }

    static func number(description: String? = nil) -> Self {
        JSONSchema(type: "number", description: description)
    }

    static func boolean(description: String? = nil) -> Self {
        JSONSchema(type: "boolean", description: description)
    }
}
