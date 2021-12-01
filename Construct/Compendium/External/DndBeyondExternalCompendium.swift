//
//  DndBeyondExternalCompendium.swift
//  Construct
//
//  Created by Thomas Visser on 30/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

class DndBeyondExternalCompendium: ExternalCompendium {

    static let baseComponents = URLComponents(string: "https://www.dndbeyond.com")!

    func url(for referenceAnnotation: CompendiumItemReferenceTextAnnotation) -> URL? {
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

    func searchPageUrl(for query: String) -> URL {
        var components = Self.baseComponents
        components.path = "/search"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
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
