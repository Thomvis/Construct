//
//  File.swift
//  
//
//  Created by Thomas Visser on 05/07/2023.
//

import Foundation

public struct PaginatedResponse<Item>: Decodable where Item: Decodable {
    public let count: Int
    public let next: String?
    public let previous: String?
    public let results: [Item]

    public init(count: Int, next: String?, previous: String?, results: [Item]) {
        self.count = count
        self.next = next
        self.previous = previous
        self.results = results
    }
}

public struct Document: Decodable, Hashable {
    public let title: String
    public let slug: String
    public let organization: String

    public init(title: String, slug: String, organization: String) {
        self.title = title
        self.slug = slug
        self.organization = organization
    }
}
