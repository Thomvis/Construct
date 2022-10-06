//
//  DndBeyondExternalCompendium.swift
//  Construct
//
//  Created by Thomas Visser on 30/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels

public class DndBeyondExternalCompendium: ExternalCompendium {

    static let baseComponents = URLComponents(string: "https://www.dndbeyond.com")!

    public init() { }

    public func url(for referenceAnnotation: CompendiumItemReferenceTextAnnotation) -> URL? {
        guard let type = referenceAnnotation.type else { return nil }

        let typeInUrl: String
        switch type {
        case .monster: typeInUrl = "monsters"
        case .spell: typeInUrl = "spells"
        case .group, .character: return nil
        }

        var components = Self.baseComponents
        components.path = "/\(typeInUrl)/\(escapeNameForUrl(name: referenceAnnotation.text))"
        return components.url
    }

    public func searchPageUrl(for query: String, types: [CompendiumItemType]? = nil) -> URL {
        var components = Self.baseComponents
        components.path = "/search"
        components.queryItems = [URLQueryItem(name: "q", value: query)]

        if let types = types {
            let matchedTypes: [String]? = types.compactMap {
                switch $0 {
                case .monster: return "monsters"
                case .character: return nil
                case .spell: return "spells"
                case .group: return nil
                }
            }.nonEmptyArray

            if let matchedTypes = matchedTypes {
                let joinedTypes = matchedTypes.joined(separator: ",")

                components.queryItems?.append(URLQueryItem(name: "c", value: joinedTypes))
                components.queryItems?.append(URLQueryItem(name: "f", value: joinedTypes))
            }
        }

        return components.url!
    }

    private func escapeNameForUrl(name: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert("-")
        return name
            .lowercased()
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.whitespacesAndNewlines).joined(separator: "-")
            .components(separatedBy: allowed.inverted).joined()
    }

}
