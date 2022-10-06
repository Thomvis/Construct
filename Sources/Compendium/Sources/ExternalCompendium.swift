//
//  ExternalCompendium.swift
//  Construct
//
//  Created by Thomas Visser on 30/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels

public protocol ExternalCompendium {
    func url(for referenceAnnotation: CompendiumItemReferenceTextAnnotation) -> URL?

    func searchPageUrl(for query: String, types: [CompendiumItemType]?) -> URL
}

public struct EmptyExternalCompendium: ExternalCompendium {
    public func searchPageUrl(for query: String, types: [CompendiumItemType]?) -> URL {
        return URL(string: "https://www.construct5e.app")!
    }

    public func url(for referenceAnnotation: CompendiumItemReferenceTextAnnotation) -> URL? {
        return nil
    }
}

extension ExternalCompendium where Self == EmptyExternalCompendium{
    public static var empty: ExternalCompendium { EmptyExternalCompendium() }
}
