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

    enum CodingKeys: String, CodingKey {
        // v1
        case title
        case slug
        case organization

        // v2
        case key
        case name
        case displayName = "display_name"
        case publisher
    }

    struct Publisher: Decodable, Hashable {
        let name: String
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.title = try c.decodeIfPresent(String.self, forKey: .title)
            ?? c.decodeIfPresent(String.self, forKey: .displayName)
            ?? c.decode(String.self, forKey: .name)

        self.slug = try c.decodeIfPresent(String.self, forKey: .slug)
            ?? c.decode(String.self, forKey: .key)

        self.organization = try c.decodeIfPresent(String.self, forKey: .organization)
            ?? c.decode(Publisher.self, forKey: .publisher).name
    }
}
